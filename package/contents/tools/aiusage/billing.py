"""Organization billing aggregation and the Claude/OpenAI pricing tables."""

import math

from .contract import num


def price_models(entries, pricing):
    models = {}
    total_in = 0
    total_out = 0
    for entry in entries:
        name = entry.get("model") or "unknown"
        in_ = math.floor(num(entry.get("input_tokens")))
        out_ = math.floor(num(entry.get("output_tokens")))
        price = pricing.get(name)
        m = models.setdefault(name, {"input_tokens": 0, "output_tokens": 0, "cost_usd": 0.0, "priced": False})
        m["input_tokens"] += in_
        m["output_tokens"] += out_
        if price is not None:
            m["cost_usd"] += (in_ / 1000000) * num(price["input"]) + (out_ / 1000000) * num(price["output"])
            m["priced"] = True
        total_in += in_
        total_out += out_
    total_cost = sum(m["cost_usd"] for m in models.values())
    return {
        "models": models,
        "totalInputTokens": total_in,
        "totalOutputTokens": total_out,
        "totalCostUSD": total_cost,
    }


def empty_org_usage():
    return {"models": {}, "totalInputTokens": 0, "totalOutputTokens": 0, "totalCostUSD": 0}


# Keyed by the API model ID exactly as the organization usage endpoints
# report it. A model missing here just comes back unpriced (priced: false in
# price_models' output) rather than erroring — see price_models() above.
#
# Verified against https://platform.claude.com/docs/en/about-claude/pricing
# and .../models/overview on 2026-08-06. These tables inherently go stale as
# providers ship new models or change prices — re-verify against the live
# pages rather than trusting this comment's date.
CLAUDE_PRICING = {
    # Claude 5 generation (current)
    "claude-fable-5": {"input": 10, "output": 50},
    "claude-mythos-5": {"input": 10, "output": 50},
    "claude-mythos-preview": {"input": 10, "output": 50},
    "claude-opus-5": {"input": 5, "output": 25},
    # Sonnet 5 introductory pricing ($2/$10) runs through 2026-08-31, then
    # steps up to $3/$15 — the flat table below can't express a pricing
    # change that hasn't happened yet, so this reflects today's rate.
    "claude-sonnet-5": {"input": 2, "output": 10},
    "claude-haiku-4-5": {"input": 1, "output": 5},
    "claude-haiku-4-5-20251001": {"input": 1, "output": 5},
    # Claude 4.x generation (still billable, superseded by the above)
    "claude-opus-4-8": {"input": 5, "output": 25},
    "claude-opus-4-7": {"input": 5, "output": 25},
    "claude-opus-4-6": {"input": 5, "output": 25},
    "claude-opus-4-5": {"input": 5, "output": 25},
    "claude-opus-4-5-20251101": {"input": 5, "output": 25},
    "claude-sonnet-4-6": {"input": 3, "output": 15},
    "claude-sonnet-4-5": {"input": 3, "output": 15},
    "claude-sonnet-4-5-20250929": {"input": 3, "output": 15},
    "claude-sonnet-4": {"input": 3, "output": 15},
    "claude-opus-4-1": {"input": 15, "output": 75},
    "claude-opus-4": {"input": 15, "output": 75},
    "claude-haiku-4": {"input": 0.8, "output": 4},
    # Claude 3.x generation (retired, kept for old usage-window data)
    "claude-sonnet-3-5": {"input": 3, "output": 15},
    "claude-haiku-3-5": {"input": 0.8, "output": 4},
    "claude-3-5-sonnet-20241022": {"input": 3, "output": 15},
    "claude-3-5-sonnet-20240620": {"input": 3, "output": 15},
    "claude-3-5-haiku-20241022": {"input": 0.8, "output": 4},
    "claude-3-opus-20240229": {"input": 15, "output": 75},
}

# Verified against https://developers.openai.com/api/docs/pricing on
# 2026-08-06 (same staleness caveat as CLAUDE_PRICING above).
OPENAI_PRICING = {
    # GPT-5.x generation (current)
    "gpt-5.6-sol": {"input": 5, "output": 30},
    "gpt-5.6-terra": {"input": 2, "output": 12},
    "gpt-5.6-luna": {"input": 0.2, "output": 1.2},
    "gpt-5.5": {"input": 5, "output": 30},
    "gpt-5.5-pro": {"input": 30, "output": 180},
    "gpt-5.5-cyber": {"input": 12.5, "output": 75},
    "gpt-5.4": {"input": 2.5, "output": 15},
    "gpt-5.4-mini": {"input": 0.75, "output": 4.5},
    "gpt-5.4-nano": {"input": 0.2, "output": 1.25},
    "gpt-5.4-pro": {"input": 30, "output": 180},
    "gpt-5.3-chat-latest": {"input": 1.75, "output": 14},
    "gpt-5.3-codex": {"input": 1.75, "output": 14},
    "gpt-5.2": {"input": 1.75, "output": 14},
    "gpt-5.2-pro": {"input": 21, "output": 168},
    "gpt-5.2-chat-latest": {"input": 1.75, "output": 14},
    "gpt-5.1": {"input": 1.25, "output": 10},
    "gpt-5": {"input": 1.25, "output": 10},
    "gpt-5-mini": {"input": 0.25, "output": 2},
    "gpt-5-nano": {"input": 0.05, "output": 0.4},
    "gpt-5-pro": {"input": 15, "output": 120},
    "gpt-5-search-api": {"input": 1.25, "output": 10},
    "chat-latest": {"input": 5, "output": 30},
    # GPT-4.1 / GPT-4o generation
    "gpt-4.1": {"input": 2, "output": 8},
    "gpt-4.1-mini": {"input": 0.4, "output": 1.6},
    "gpt-4.1-nano": {"input": 0.1, "output": 0.4},
    "gpt-4o": {"input": 2.5, "output": 10},
    "gpt-4o-2024-11-20": {"input": 2.5, "output": 10},
    "gpt-4o-2024-08-06": {"input": 2.5, "output": 10},
    "gpt-4o-2024-05-13": {"input": 5, "output": 15},
    "gpt-4o-mini": {"input": 0.15, "output": 0.6},
    "gpt-4o-mini-2024-07-18": {"input": 0.15, "output": 0.6},
    # o-series reasoning models
    "o1": {"input": 15, "output": 60},
    "o1-2024-12-17": {"input": 15, "output": 60},
    "o1-pro": {"input": 150, "output": 600},
    "o1-mini": {"input": 1.1, "output": 4.4},
    "o1-mini-2024-09-12": {"input": 1.1, "output": 4.4},
    "o3": {"input": 2, "output": 8},  # was $10/$40 when this table was first written — repriced since
    "o3-pro": {"input": 20, "output": 80},
    "o3-mini": {"input": 1.1, "output": 4.4},
    "o4-mini": {"input": 1.1, "output": 4.4},
    # Legacy GPT-4 / GPT-3.5 (retired, kept for old usage-window data)
    "gpt-4-turbo": {"input": 10, "output": 30},
    "gpt-4-turbo-2024-04-09": {"input": 10, "output": 30},
    "gpt-4": {"input": 30, "output": 60},
    "gpt-4-0613": {"input": 30, "output": 60},
    "gpt-4-32k": {"input": 60, "output": 120},
    "gpt-3.5-turbo": {"input": 0.5, "output": 1.5},
    "gpt-3.5-turbo-0125": {"input": 0.5, "output": 1.5},
    "gpt-3.5-turbo-1106": {"input": 1, "output": 2},
    "gpt-3.5-turbo-instruct": {"input": 1.5, "output": 2},
    "davinci-002": {"input": 2, "output": 2},
    "babbage-002": {"input": 0.4, "output": 0.4},
    # Embeddings (output is always 0 — no generated tokens)
    "text-embedding-3-small": {"input": 0.02, "output": 0},
    "text-embedding-3-large": {"input": 0.13, "output": 0},
}
