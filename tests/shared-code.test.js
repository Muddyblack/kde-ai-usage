const test = require("node:test");
const assert = require("node:assert/strict");
const Format = require("../package/contents/code/Format.js");
const UsageHistory = require("../package/contents/code/UsageHistory.js");
const Shell = require("../package/contents/code/Shell.js");
const { execFileSync } = require("node:child_process");

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

// ── Shell.js ────────────────────────────────────────────────────────────────
// The Plasma widget hands the backend its configured API keys as environment
// assignments in a /bin/sh command line, base64-encoded so metacharacters in a
// key cannot break out of it. Encoding this wrong does not fail loudly — the
// backend receives a well-formed but wrong credential and the provider answers
// with an auth error, which is issue #16: keys pasted into the widget's own
// settings fields were encoded as the *stringified* byte array ("119,105,...")
// and every provider rejected them, while the same key worked from $ENV.

test("encodes ASCII bytes the way `base64 -d` reads them back", () => {
    assert.equal(Shell.base64(""), "");
    assert.equal(Shell.base64("a"), "YQ==");
    assert.equal(Shell.base64("ab"), "YWI=");
    assert.equal(Shell.base64("abc"), "YWJj");
    const key = "5c8f2e1b4d3a4b7e9c2f1a2b3c4d5e6f.AbCdEfGhIjKlMnOp";
    assert.equal(Shell.base64(key), Buffer.from(key, "utf8").toString("base64"));
});

test("encodes UTF-8, including characters outside the BMP", () => {
    for (const text of ["clé-ünïcode-ñ", "密钥", "key 🔑 end", "\u{1F600}\u{1F680}"])
        assert.equal(Shell.base64(text), Buffer.from(text, "utf8").toString("base64"));
});

test("never emits invalid UTF-8 for an unpaired surrogate", () => {
    for (const text of ["\uD800", "x\uDC00y"])
        assert.equal(Shell.base64(text), Buffer.from(text, "utf8").toString("base64"));
});

test("builds no assignment for an empty value", () => {
    assert.equal(Shell.envAssign("WIDGET_ZAI_TOKEN", ""), "");
    assert.equal(Shell.envAssign("WIDGET_ZAI_TOKEN", null), "");
    assert.equal(Shell.envAssign("WIDGET_ZAI_TOKEN", undefined), "");
});

test("delivers the value byte-for-byte through a real shell", () => {
    // The end-to-end claim of the round-trip: whatever the user pasted is what
    // the backend's environment holds. Run through /bin/sh, the interpreter
    // Plasma's executable DataEngine uses, rather than trusting the encoder.
    const values = [
        "5c8f2e1b4d3a4b7e9c2f1a2b3c4d5e6f.AbCdEfGhIjKlMnOp",
        "sk-proj_a-b_c.d~e",
        "spaces and $HOME and `backticks` and \"quotes\" and 'single'",
        "semi;colon | pipe && amp > redirect",
        "clé-🔑-密钥"
    ];
    for (const value of values) {
        // Read it back from a *child* process: an assignment prefix lands in
        // the launched command's environment, which is exactly where the
        // Python backend reads it from — os.environ, not the parent shell.
        const cmd = Shell.envAssign("WIDGET_TEST_KEY", value) + '/bin/sh -c \'printf %s "$WIDGET_TEST_KEY"\'';
        assert.equal(execFileSync("/bin/sh", ["-c", cmd], { encoding: "utf8" }), value);
    }
});

test("quotes a path for the shell without losing a quote", () => {
    const cmd = "printf %s " + Shell.quote("/home/u/it's a dir/get-ai-usage");
    assert.equal(execFileSync("/bin/sh", ["-c", cmd], { encoding: "utf8" }), "/home/u/it's a dir/get-ai-usage");
});
