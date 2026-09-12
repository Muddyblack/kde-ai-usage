"""gettext setup for the backend.

The widget ships its own catalogs next to the QML (package/contents/locale).
The backend shares the applet's translation domain, so a single .po/.mo covers
both the QML strings and the messages normalise/* and providers/* hand back to
the frontend.

Standard library only, like the rest of the backend. When no catalog matches the
locale, gettext falls back to the English msgid — the previous behaviour.
"""

import gettext
import os

# The QML passes its own translation domain (plasma_applet_<pluginId>) so the
# backend follows the applet even when it is installed under a different id
# (the test copy). Falls back to the release id for a bare CLI run.
DEFAULT_DOMAIN = "plasma_applet_org.muddyblack.aiUsageWidget"
DOMAIN = os.environ.get("AI_USAGE_I18N_DOMAIN") or DEFAULT_DOMAIN

# contents/tools/aiusage/i18n.py -> contents/locale
_LOCALEDIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "locale"))

_translation = gettext.translation(DOMAIN, localedir=_LOCALEDIR, fallback=True)


def _(message):
    return _translation.gettext(message)
