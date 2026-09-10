// The shared usage-history series.
//
// Both frontends append to the same rolling array — and to the same mirror file
// on disk — so the merge rules have to agree exactly. Only persistence differs
// (Plasma writes its widget config, Quickshell writes the file), so that stays
// with the callers.
//
// A point is {t: epochMs, <seriesKey>: value, ...}. Which keys a provider
// contributes is decided by the backend (historyValues in the contract), so
// nothing here knows about individual providers.

// Samples closer together than this patch the previous point instead of adding
// one, which keeps a fast poll interval from flooding the series.
var MERGE_WINDOW_MS = 120000;
// About 34 days of unbroken 5-minute polling, and most of a year at the density a
// machine that sleeps actually produces. 500 was ~13 days, which left the 30-day
// deltas ("last month") permanently without data. The file is ~40 bytes a sample,
// so this is a 480 KB ceiling, and the merge cost is process startup either way —
// 10k points measure the same as 500.
var DEFAULT_LIMIT = 10000;

// A sample only counts when it carries a number. A provider that failed reports
// its keys as null; writing those into the series would erase the last good
// reading instead of leaving a gap.
function isValue(v) {
    return v !== undefined && v !== null;
}

// A timestamp written as a string is only read back when it is a plain decimal.
// Number() would also take "0x10", "1_0" and "Infinity", none of which Python's
// float() accepts — and the two implementations have to agree on every byte of
// the shared file.
var DECIMAL_RE = /^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$/;

// A point's timestamp as a finite number, or null when the point is unusable.
// The mirror file is written by whichever frontend ran last and can be edited by
// hand, so everything read back through it goes past this guard first.
function pointTime(p) {
    if (!p || typeof p !== "object")
        return null;

    var t = p.t;
    if (typeof t === "string") {
        if (!DECIMAL_RE.test(t.trim()))
            return null;

        t = Number(t);
    }
    if (typeof t !== "number" || !isFinite(t))
        return null;

    return t;
}

// Copy every series value of `src` onto `dst`, keeping `t` and dropping the
// blanks. Used everywhere two points have to be combined.
function assignValues(dst, src) {
    for (var key in src) {
        if (key === "t")
            continue;
        if (isValue(src[key]))
            dst[key] = src[key];
    }
    return dst;
}

// Collect every provider's historyValues from one backend response into a
// single patch.
function collect(providers) {
    var patch = {};
    for (var i = 0; i < (providers || []).length; i++) {
        var values = (providers[i] || {}).historyValues || {};
        for (var key in values)
            patch[key] = values[key];
    }
    return patch;
}

// Combine two series that were recorded independently — the mirror file on disk
// against whatever the running frontend already holds. Plasma keeps a second
// copy of the history in its widget config, so on startup the file may carry
// points the config never saw (recorded under Quickshell) and the config may
// carry points the file never saw (a mirror write that failed). Points sharing a
// timestamp are combined key by key, with `overlay` winning, so a point holding
// only `w` and one holding only `cp` end up as one complete point. Points the
// other side never recorded are kept as they are.
//
// Returns a new array, ascending by t and trimmed to the cap.
function union(base, overlay, limit) {
    var byTime = {};
    var t;

    // Both sides fold the same way: a repeated timestamp contributes its keys to
    // the point already there rather than replacing it, so two half-filled points
    // recorded a millisecond apart never cost each other their series.
    function absorb(points) {
        for (var j = 0; j < (points || []).length; j++) {
            var point = points[j];
            var pt = pointTime(point);
            if (pt === null)
                continue;

            if (!byTime[pt])
                byTime[pt] = {
                    t: pt
                };

            assignValues(byTime[pt], point);
        }
    }

    absorb(base);
    absorb(overlay);

    var out = [];
    for (t in byTime)
        out.push(byTime[t]);

    out.sort(function (p1, p2) {
        return p1.t - p2.t;
    });

    var cap = limit || DEFAULT_LIMIT;
    if (out.length > cap)
        out = out.slice(out.length - cap);

    return out;
}

// Accept both the current {t, <key>: v} points and the legacy weekly-only
// {t, v} shape, and trim to the cap. Used when importing or restoring a file.
function normalize(points, limit) {
    var out = [];
    for (var i = 0; i < (points || []).length; i++) {
        var p = points[i];
        var t = pointTime(p);
        // A point with no usable timestamp (null, a stray string, a torn write)
        // would sort as NaN and drag the whole chart range with it, and both
        // frontends would then persist it back into the shared file.
        if (t === null)
            continue;

        var q = {
            t: t
        };
        assignValues(q, p);
        // Legacy weekly-only points carried the value as `v`.
        if (q.w === undefined && isValue(p.v))
            q.w = p.v;
        delete q.v;
        out.push(q);
    }
    var cap = limit || DEFAULT_LIMIT;
    if (out.length > cap)
        out = out.slice(out.length - cap);

    return out;
}

// A rolling quota window empties at a known instant, whether or not anything
// was recorded then. With the machine asleep — or simply between two polls —
// the samples on either side of a reset would be joined by one straight line,
// which reads as hours of gradual usage that never happened and puts the drop
// at wake-up time instead of at the reset.
//
// So replay the resets we can derive: `resetAt` is the next one and `periodMs`
// how often it repeats, which pins every earlier reset in the visible range.
// For each one falling inside a gap, hold the previous value right up to the
// instant and drop to zero there; the curve then climbs again from the next
// real sample.
//
// `series` is the windowed [{t, v}] view, ascending. Returns a new array.
function withResets(series, resetAtMs, periodMs, minT, maxT) {
    if (!resetAtMs || !periodMs || periodMs <= 0 || !series || series.length === 0)
        return series;

    var instants = [];
    var guard = 0;
    for (var r = resetAtMs; r > minT && guard < 1000; r -= periodMs, guard++) {
        if (r <= maxT && r > series[0].t)
            instants.push(r);
    }
    if (instants.length === 0)
        return series;

    instants.reverse();

    // The held value is whatever the curve is at right now — which after an
    // earlier replayed reset is zero, not the last real sample. A long gap can
    // span several resets, so read it back off the output.
    var out = [];
    var next = 0;
    var i;

    function dropAt(instant) {
        out.push({
            t: instant - 1,
            v: out[out.length - 1].v
        });
        out.push({
            t: instant,
            v: 0
        });
    }

    for (i = 0; i < series.length; i++) {
        while (i > 0 && next < instants.length && instants[next] > series[i - 1].t && instants[next] < series[i].t) {
            dropAt(instants[next]);
            next++;
        }
        out.push(series[i]);
    }

    // A reset newer than the last sample: the window has already emptied even
    // though nothing has been recorded since.
    var lastT = series[series.length - 1].t;
    while (next < instants.length) {
        if (instants[next] > lastT)
            dropAt(instants[next]);

        next++;
    }
    return out;
}

// ── The save protocol ────────────────────────────────────────────────────
//
// Both frontends run this over tools/sh/history-io, so it lives here rather than
// twice in QML, where only a live Plasma session or Quickshell could exercise it.
// The frontend is left with the transport and the timers.
//
// history-io gives the payload precedence, so what a payload holds is the whole
// contract: `fresh` is readings this frontend just took and asserts them, `seed`
// is a series it restored and only offers them. "Shared frontend code" in
// docs/provider-contract.md has the why, and the rest of the rules.

function newStore(limit) {
    return {
        limit: limit || DEFAULT_LIMIT,
        // Replaced, never patched in place: an unchanged reference is all a
        // frontend needs to know there is nothing to repaint.
        history: [],
        json: "[]",
        // The point this frontend last wrote. record() patches that one and no
        // other, which holds a timestamp to one writer — bar the case in record().
        ownT: null,
        // Queued to go out: measured, and restored.
        fresh: [],
        seed: [],
        sending: null,
        ready: false,
        // A save failed. The next poll is what retries it.
        waiting: false
    };
}

function _setHistory(store, points) {
    var json = JSON.stringify(points);
    if (json === store.json)
        return false;

    store.history = points;
    store.json = json;
    return true;
}

// A series this frontend restored rather than measured. It goes under whatever
// is already on screen, and into the seed lane to be offered to the file.
function restore(store, points) {
    var series = normalize(points, store.limit);
    if (series.length === 0)
        return false;

    store.seed = union(store.seed, series, store.limit);
    // An import is as good a trigger as a poll for a save that is waiting.
    store.waiting = false;
    return _setHistory(store, union(series, store.history, store.limit));
}

// One poll's provider values, whether or not it carried any. Calling this every
// poll is also what releases a save that failed, so a retry waits for the next
// one instead of going straight back out at a tool that just refused it.
function record(store, values, nowMs) {
    store.waiting = false;

    var keys = [];
    for (var key in (values || {}))
        if (isValue(values[key]))
            keys.push(key);
    if (keys.length === 0)
        return false;

    var out = store.history.slice();
    var i;
    var last = out.length > 0 ? out[out.length - 1] : null;
    // Samples inside the merge window patch this frontend's own previous point
    // rather than adding one, so a fast poll interval cannot flood the series.
    // Someone else's point is left alone however recent: two writers patching one
    // point leaves no way to tell which value is the newer reading. `nowMs` is the
    // whole of that ownership, so two frontends polling in the same millisecond do
    // both claim the point, and its value flips between their readings until the
    // window passes. Closing it needs a writer id in every point — ~30% more file
    // for a one-point wobble at ~0.1% a day on the default poll.
    var patching = !!last && last.t === store.ownT && nowMs - last.t < MERGE_WINDOW_MS;
    var point = {
        t: patching ? last.t : nowMs
    };
    for (i = 0; i < keys.length; i++)
        point[keys[i]] = values[keys[i]];

    if (patching) {
        // A *copy*: slice() is shallow, and writing through `last` would rewrite
        // the point inside the array the frontend still holds — a mutation QML
        // never signals, and one the file has not seen.
        var patched = {
            t: point.t
        };
        assignValues(patched, last);
        out[out.length - 1] = assignValues(patched, point);
    } else {
        // A copy again, so the series cannot alias the queued point.
        out.push(assignValues({
            t: point.t
        }, point));
    }

    var cap = store.limit;
    if (out.length > cap)
        out = out.slice(out.length - cap);

    store.ownT = point.t;
    // Only the keys this sample carried. The rest of the series is this
    // frontend's copies of the other one's points.
    store.fresh = union(store.fresh, [point], cap);
    return _setHistory(store, out);
}

// The file is the truth for everything it knows; what only exists here — not
// mirrored yet — is kept, and the fresh lane wins over both.
function adopt(store, series) {
    return _setHistory(store, union(union(store.history, normalize(series, store.limit), store.limit), store.fresh, store.limit));
}

// The startup read has answered (or given up): the file is ours to write.
function opened(store) {
    store.ready = true;
}

// The next batch as {op, points}, or null when there is nothing to send yet.
// Seeds go first: a fresh install has to get its restored series on disk.
function take(store) {
    if (!store.ready || store.waiting || store.sending)
        return null;

    if (store.seed.length > 0) {
        store.sending = {
            op: "seed",
            points: store.seed
        };
        store.seed = [];
    } else if (store.fresh.length > 0) {
        store.sending = {
            op: "autosave",
            points: store.fresh
        };
        store.fresh = [];
    } else {
        return null;
    }

    return store.sending;
}

// `merged` is the file with that batch already in it, so the batch is done.
// Whatever queued up while it was out has not been saved, and stays queued.
function done(store, merged) {
    store.sending = null;
    return adopt(store, merged);
}

// history-io leaves the file untouched when it cannot merge, so nothing was
// written. Put the batch back in its lane, under anything queued since, and wait
// for the next poll. Idempotent: the watchdog and a late answer may both call it.
function failed(store) {
    var batch = store.sending;
    store.sending = null;
    store.waiting = true;
    if (!batch)
        return;

    if (batch.op === "seed")
        store.seed = union(batch.points, store.seed, store.limit);
    else
        store.fresh = union(batch.points, store.fresh, store.limit);
}


if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        MERGE_WINDOW_MS: MERGE_WINDOW_MS,
        pointTime: pointTime,
        collect: collect,
        union: union,
        normalize: normalize,
        withResets: withResets,
        newStore: newStore,
        restore: restore,
        record: record,
        adopt: adopt,
        opened: opened,
        take: take,
        done: done,
        failed: failed
    };
}
