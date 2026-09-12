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

DOMAIN = "plasma_applet_org.muddyblack.aiUsageWidget"

# contents/tools/aiusage/i18n.py -> contents/locale
_LOCALEDIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "locale"))

_translation = gettext.translation(DOMAIN, localedir=_LOCALEDIR, fallback=True)


def _(message):
    return _translation.gettext(message)
