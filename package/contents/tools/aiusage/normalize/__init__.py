from ..contract import provider_error
from .antigravity import normalize_antigravity
from .claude import normalize_claude
from .copilot import normalize_copilot
from .deepseek import normalize_deepseek
from .grok import normalize_grok
from .kiro import normalize_kiro
from .mistral import normalize_mistral
from .moonshot import normalize_moonshot
from .openai import normalize_openai
from .openrouter import normalize_openrouter
from .zai import normalize_zai

_DISPATCH = {
    "claude": normalize_claude,
    "openai": normalize_openai,
    "antigravity": normalize_antigravity,
    "kiro": normalize_kiro,
    "mistral": normalize_mistral,
    "openrouter": normalize_openrouter,
    "grok": normalize_grok,
    "zai": normalize_zai,
    "copilot": normalize_copilot,
    "deepseek": normalize_deepseek,
    "kimi": normalize_moonshot,
}


def normalize(raw):
    id_ = raw.get("id")
    fn = _DISPATCH.get(id_)
    if fn is None:
        return provider_error(id_, id_, "#888888", raw.get("now") or 0, f"unknown provider: {id_}", {})
    return fn(raw)
