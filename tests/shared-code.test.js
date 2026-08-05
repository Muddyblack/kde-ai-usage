const test = require("node:test");
const assert = require("node:assert/strict");
const Format = require("../package/contents/code/Format.js");
const UsageHistory = require("../package/contents/code/UsageHistory.js");

// Both frontends import these modules, so a change here shows up in the Plasma
// popup and the Quickshell panel at once. Provider parsing and the chart-range
// table live in the backend; see tests/get-ai-usage.test.sh.

test("formats a countdown down to the minute", () => {
    const now = 1785000000000;
    assert.equal(Format.countdown(now + 90 * 60000, now), "1h 30m");
    assert.equal(Format.countdown(now + (2 * 1440 + 65) * 60000, now), "2d 1h 5m");
    assert.equal(Format.countdown(now + 45 * 1000, now), "0m");
});

test("reports a passed deadline and a missing one", () => {
    const now = 1785000000000;
    assert.equal(Format.countdown(now - 1000, now), "resetting...");
    assert.equal(Format.countdown(0, now), "");
    assert.equal(Format.countdown(null, now), "");
});

test("converts the contract's epoch seconds", () => {
    const now = 1785000000000;
    assert.equal(Format.countdownFromEpoch(1785003600, now), "1h 0m");
    assert.equal(Format.countdownFromEpoch(0, now), "");
});

test("collects every provider's history values into one patch", () => {
    assert.deepEqual(UsageHistory.collect([
        { id: "claude", historyValues: { s: 12, w: 34 } },
        { id: "kiro", historyValues: { kr: 56 } },
        { id: "grok", historyValues: {} },
        { id: "broken" }
    ]), { s: 12, w: 34, kr: 56 });
});

test("patches a recent point instead of appending", () => {
    const now = 1785000000000;
    const history = [{ t: now - 30000, s: 10 }];
    const merged = UsageHistory.merge(history, { s: 20, w: 5 }, now, 500);
    assert.equal(merged.length, 1);
    assert.deepEqual(merged[0], { t: now - 30000, s: 20, w: 5 });
});

test("appends once the merge window has passed", () => {
    const now = 1785000000000;
    const history = [{ t: now - UsageHistory.MERGE_WINDOW_MS - 1, s: 10 }];
    const merged = UsageHistory.merge(history, { s: 20 }, now, 500);
    assert.equal(merged.length, 2);
    assert.deepEqual(merged[1], { t: now, s: 20 });
});

test("returns the input untouched when a provider reports nothing", () => {
    const history = [{ t: 1, s: 10 }];
    assert.equal(UsageHistory.merge(history, {}, 2, 500), history);
});

test("trims to the history limit", () => {
    const points = [];
    for (let i = 0; i < 12; i++)
        points.push({ t: i * 1000000, s: i });
    const merged = UsageHistory.merge(points, { s: 99 }, 99000000, 5);
    assert.equal(merged.length, 5);
    assert.equal(merged[merged.length - 1].s, 99);
});

test("migrates legacy weekly-only points and drops junk", () => {
    assert.deepEqual(UsageHistory.normalize([
        { t: 1, v: 40 },
        { t: 2, w: 50 },
        { v: 60 },
        null
    ], 500), [{ t: 1, w: 40 }, { t: 2, w: 50 }]);
});

test("replays a reset that happened while nothing was recorded", () => {
    const H = 3600000;
    const resetAt = 100 * H;          // next reset
    const period = 5 * H;             // five-hour window
    // Asleep from 88h to 97h — the 90h and 95h resets fall inside that gap.
    const series = [{ t: 88 * H, v: 80 }, { t: 97 * H, v: 12 }];
    const out = UsageHistory.withResets(series, resetAt, period, 80 * H, 99 * H);

    assert.deepEqual(out.map(p => [p.t / H, p.v]), [
        [88, 80],
        [90 - 1 / H, 80], [90, 0],
        [95 - 1 / H, 0], [95, 0],
        [97, 12]
    ]);
});

test("drops the curve for a reset newer than the last sample", () => {
    const H = 3600000;
    const series = [{ t: 10 * H, v: 40 }];
    const out = UsageHistory.withResets(series, 12 * H, 5 * H, 5 * H, 14 * H);
    assert.deepEqual(out.map(p => p.v), [40, 40, 0]);
    assert.equal(out[out.length - 1].t, 12 * H);
});

test("leaves a series alone when the window never resets", () => {
    const series = [{ t: 1, v: 1 }, { t: 2, v: 2 }];
    assert.equal(UsageHistory.withResets(series, 0, 0, 0, 10), series);
    assert.equal(UsageHistory.withResets(series, 5, 0, 0, 10), series);
});
