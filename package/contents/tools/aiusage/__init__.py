"""AI usage backend.

The backend emits a language-neutral English JSON contract and never localizes
at runtime. ``N_`` is a gettext extraction marker only (identity at runtime):
translate/Messages.sh picks the strings up with xgettext, and the frontends
translate them where they are displayed.
"""


def N_(message):
    return message
