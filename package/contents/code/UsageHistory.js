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
var DEFAULT_LIMIT = 500;

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

// Returns a new array — callers assign it, because QML only emits a change
// signal on assignment, never on in-place mutation.
function merge(history, values, nowMs, limit) {
    var keys = Object.keys(values || {});
    if (keys.length === 0)
        return history;

    var out = (history || []).slice();
    var i;
    if (out.length > 0 && nowMs - out[out.length - 1].t < MERGE_WINDOW_MS) {
        var last = out[out.length - 1];
        for (i = 0; i < keys.length; i++)
            last[keys[i]] = values[keys[i]];
        out[out.length - 1] = last;
    } else {
        var point = {
            t: nowMs
        };
        for (i = 0; i < keys.length; i++)
            point[keys[i]] = values[keys[i]];
        out.push(point);
    }

    var cap = limit || DEFAULT_LIMIT;
    if (out.length > cap)
        out = out.slice(out.length - cap);

    return out;
}

// Combine two series that were recorded independently — the mirror file on disk
// against whatever the running frontend already holds. Plasma keeps a second
// copy of the history in its widget config, so on startup the file may carry
// points the config never saw (recorded under Quickshell) and the config may
// carry points the file never saw (a mirror write that failed). Points sharing a
// timestamp are combined key by key, with `overlay` winning, so a point holding
// only `w` and one holding only `cp` end up as one complete point.
//
// Returns a new array, ascending by t and trimmed to the cap.
function union(base, overlay, limit) {
    var byTime = {};
    var i, key;

    for (i = 0; i < (base || []).length; i++) {
        var basePoint = base[i];
        if (!basePoint || basePoint.t === undefined)
            continue;

        byTime[basePoint.t] = Object.assign({}, basePoint);
    }

    for (i = 0; i < (overlay || []).length; i++) {
        var point = overlay[i];
        if (!point || point.t === undefined)
            continue;

        if (!byTime[point.t]) {
            byTime[point.t] = Object.assign({}, point);
            continue;
        }
        for (key in point) {
            if (point[key] !== undefined && point[key] !== null)
                byTime[point.t][key] = point[key];
        }
    }

    var out = [];
    for (var t in byTime)
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
        if (!p || p.t === undefined)
            continue;

        if (p.w === undefined && p.v !== undefined)
            out.push({
                t: p.t,
                w: p.v
            });
        else
            out.push(p);
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

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        MERGE_WINDOW_MS: MERGE_WINDOW_MS,
        collect: collect,
        merge: merge,
        union: union,
        normalize: normalize,
        withResets: withResets
    };
}
