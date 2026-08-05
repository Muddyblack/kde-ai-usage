const test = require("node:test");
const assert = require("node:assert/strict");
const UsageWindows = require("../package/contents/code/UsageWindows.js");

test("normalizes Claude semantic session and weekly limits", () => {
    const result = UsageWindows.normalizeClaude({
        limits: [
            { group: "session", kind: "session", is_active: true, percent: 23, resets_at: "2026-07-19T15:00:00Z" },
            { group: "weekly", kind: "weekly_scoped", is_active: true, percent: 61, resets_at: "2026-07-25T15:00:00Z" }
        ]
    });

    assert.deepEqual(result.session, { available: true, pct: 23, resetAt: "2026-07-19T15:00:00Z" });
    assert.deepEqual(result.weekly, { available: true, pct: 61, resetAt: "2026-07-25T15:00:00Z" });
});

test("falls back to legacy Claude windows", () => {
    const result = UsageWindows.normalizeClaude({
        five_hour: { utilization: 12, resets_at: "session-reset" },
        seven_day: { utilization: 45, resets_at: "weekly-reset" }
    });

    assert.equal(result.session.available, true);
    assert.equal(result.session.pct, 12);
    assert.equal(result.weekly.available, true);
    assert.equal(result.weekly.pct, 45);
});

test("rejects inactive and nonnumeric Claude placeholders", () => {
    const result = UsageWindows.normalizeClaude({
        limits: [
            { group: "session", kind: "session", is_active: false, percent: 0 },
            { group: "weekly", kind: "weekly_scoped", is_active: true, percent: null }
        ]
    });

    assert.equal(result.session.available, false);
    assert.equal(result.weekly.available, false);
});

test("prefers active Claude semantic entries over legacy values", () => {
    const result = UsageWindows.normalizeClaude({
        limits: [
            { group: "session", kind: "session", is_active: true, percent: 31, resets_at: "new-reset" }
        ],
        five_hour: { utilization: 99, resets_at: "old-reset" }
    });

    assert.deepEqual(result.session, { available: true, pct: 31, resetAt: "new-reset" });
});

test("normalizes a weekly-only Codex app-server snapshot", () => {
    const result = UsageWindows.normalizeCodex({
        rateLimits: {
            limitId: "codex",
            primary: { usedPercent: 58, windowDurationMins: 10080, resetsAt: 1784956965 },
            secondary: null
        }
    });

    assert.equal(result.session.available, false);
    assert.deepEqual(result.weekly, { available: true, pct: 58, resetAt: 1784956965000 });
});

test("classifies legacy Codex windows by duration even when reversed", () => {
    const result = UsageWindows.normalizeCodex({
        rate_limit: {
            primary_window: { used_percent: 70, limit_window_seconds: 604800, reset_at: 200 },
            secondary_window: { used_percent: 20, limit_window_seconds: 18000, reset_at: 100 }
        }
    });

    assert.equal(result.session.pct, 20);
    assert.equal(result.session.resetAt, 100000);
    assert.equal(result.weekly.pct, 70);
    assert.equal(result.weekly.resetAt, 200000);
});

test("normalizes app-server named limits and ignores unknown durations", () => {
    const result = UsageWindows.normalizeCodex({
        rateLimits: { primary: { usedPercent: 1, windowDurationMins: 60, resetsAt: 10 } },
        rateLimitsByLimitId: {
            codex: { limitId: "codex", primary: { usedPercent: 1, windowDurationMins: 60, resetsAt: 10 } },
            spark: { limitId: "spark", limitName: "Spark", primary: { usedPercent: 9, windowDurationMins: 10080, resetsAt: 20 } }
        }
    });

    assert.equal(result.session.available, false);
    assert.equal(result.weekly.available, false);
    assert.equal(result.additional.length, 1);
    assert.equal(result.additional[0].weekly.pct, 9);
});

test("offers only weekly charts for weekly-only Codex", () => {
    assert.deepEqual(UsageWindows.chartChoices("openai", false, true), [
        { id: "codex_weekly", label: "7D" }
    ]);
});

test("offers session day and weekly charts when both windows exist", () => {
    assert.deepEqual(UsageWindows.chartChoices("claude", true, true), [
        { id: "session", label: "5H" },
        { id: "day", label: "24H" },
        { id: "weekly", label: "7D" }
    ]);
});
