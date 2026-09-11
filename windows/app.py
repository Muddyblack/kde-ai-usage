"""AI Usage for Windows — a tray icon with the same popup as the Hyprland panel.

The popup is the shared QML under hyprland/ (PopupContent.qml, SettingsPage.qml
and the components they use); qml/Main.qml wraps it in a frameless window and
implements the `shell` interface they read. The data comes from the same
aiusage package every other frontend runs, called in-process: there is no
shell on Windows to run tools/sh/* through, and nothing here needs one.

It runs on Linux too, which is how it is developed: `nix develop .#windows`
brings PySide6 (or `make run-windows`), else `pip install -r windows/requirements.txt`.

  python windows/app.py                  start (a second start toggles the popup)
  python windows/app.py --selftest       load the QML headless, open every settings
                                         section once, exit 1 on any QML warning
  python windows/app.py --screenshot F [--settings]
                                         render the popup (or the settings page)
                                         into F (PNG) and exit
"""

import json
import os
import re
import signal
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

FROZEN = getattr(sys, "frozen", False)
# Frozen, everything the app reads sits under the bundle root in the same
# layout as the repository, so the QML's relative imports resolve unchanged.
ROOT = Path(getattr(sys, "_MEIPASS", "")) if FROZEN else Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "package" / "contents" / "tools"))

from aiusage import config, history, historyio, paths  # noqa: E402
from aiusage.__main__ import snapshot  # noqa: E402

APP_NAME = "AI Usage"
SERVER_NAME = "ai-usage-widget-tray"
ICON_PATH = ROOT / "package" / "contents" / "icons" / "org.muddyblack.aiUsageWidget.svg"
MAIN_QML = ROOT / "windows" / "qml" / "Main.qml"

# os.environ is process-wide and snapshot() writes the settings' keys into it,
# so one collection runs at a time and puts the environment back afterwards.
_env_lock = threading.Lock()


def collect_snapshot():
    with _env_lock:
        saved = os.environ.copy()
        try:
            return json.dumps(snapshot(), separators=(",", ":"), ensure_ascii=False)
        finally:
            os.environ.clear()
            os.environ.update(saved)


# ── Start with Windows ───────────────────────────────────────────────────────

_RUN_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"


def _launch_command():
    if FROZEN:
        return f'"{sys.executable}"'
    # pythonw has no console, so a login start does not leave a terminal open.
    pythonw = Path(sys.executable).with_name("pythonw.exe")
    interpreter = pythonw if pythonw.exists() else Path(sys.executable)
    return f'"{interpreter}" "{Path(__file__).resolve()}"'


def autostart_enabled():
    if not paths.IS_WINDOWS:
        return False
    import winreg

    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, _RUN_KEY) as key:
            winreg.QueryValueEx(key, APP_NAME)
        return True
    except OSError:
        return False


def set_autostart(enabled):
    if not paths.IS_WINDOWS:
        return
    import winreg

    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, _RUN_KEY, 0, winreg.KEY_SET_VALUE) as key:
        if enabled:
            winreg.SetValueEx(key, APP_NAME, 0, winreg.REG_SZ, _launch_command())
        else:
            try:
                winreg.DeleteValue(key, APP_NAME)
            except FileNotFoundError:
                pass


# ── Tray icons ───────────────────────────────────────────────────────────────

_PERCENT_RE = re.compile(r"^\s*(\d{1,3})(?:\.\d+)?\s*%\s*$")


# (setting value, tray menu label), in menu order. The first is the default.
TRAY_STYLES = [("icons", "Logo and percent"), ("numbers", "Numbers"), ("ring", "Ring")]


def tray_style(state):
    """The style a published state asks for. Settings from before there were
    three styles only had trayNumbers, whose "off" was the ring."""
    style = state.get("style")
    if style in dict(TRAY_STYLES):
        return style
    return "ring" if state.get("numbers") is False else TRAY_STYLES[0][0]


def tray_entries(state):
    """What the tray shows for a state Main.qml published: one entry per icon.

    "icons" (the default) reads like the panel pill: for every value, the
    provider's logo tinted in the value's colour, then the value as "NN%":
      {"kind": "tinted", …} {"kind": "percent", "value": 0..100, …}
    "numbers": the logo once — its tooltip lists every provider — then each
    value as plain coloured digits:
      {"kind": "logo", …} {"kind": "number", "value": 0..100, …} …
    "ring", or no data yet: one icon, the logo inside a usage ring.

    Windows gives every tray icon the same square, so a logo and its number
    cannot share one. A value that is not a percentage (a balance, a dash) is a
    ring in the first two styles too. `icon` is the logo's file URL, "" for the
    app icon."""
    slots = [s for s in state.get("slots") or [] if isinstance(s, dict)]
    summary = state.get("tooltip") or APP_NAME
    logo = state.get("icon") or ""
    style = tray_style(state)
    if style == "ring" or not slots:
        first = slots[0] if slots else {}
        return [{"kind": "ring", "value": _number(first.get("pct"), -1), "color": first.get("color") or "", "icon": logo, "tooltip": summary}]

    entries = [] if style == "icons" else [{"kind": "logo", "icon": logo, "tooltip": summary}]
    for slot in slots:
        text = slot.get("text") or ""
        match = _PERCENT_RE.match(text) if text else None
        base = {"color": slot.get("color") or "", "icon": logo, "tooltip": slot.get("tooltip") or summary}
        if text and not match:
            entries.append(dict(base, kind="ring", value=_number(slot.get("pct"), 0)))
            continue
        value = int(match.group(1)) if match else round(_number(slot.get("pct"), 0))
        value = max(0, min(value, 100))
        if style == "icons":
            entries.append(dict(base, kind="tinted"))
            entries.append(dict(base, kind="percent", value=value, textColor=_text_colour(value)))
        else:
            entries.append(dict(base, kind="number", value=value, textColor=_text_colour(value)))
    return entries


_DANGER, _WARNING = "#ff4d4d", "#ffa64d"


def _text_colour(value):
    """The panel pill's rule (hyprland/PanelSlot.qml): the logo carries the
    provider's colour, the number stays neutral until it is worth a look —
    amber from 70 %, red from 90 %. "" is the neutral colour, which depends on
    the taskbar and is decided when drawing."""
    return _DANGER if value >= 90 else _WARNING if value >= 70 else ""


def _number(value, default):
    return value if isinstance(value, (int, float)) and not isinstance(value, bool) else default


# Qt is the one dependency beyond the backend's standard library; say how to
# get it rather than failing with a bare traceback.
try:
    import PySide6  # noqa: E402, F401
except ImportError:
    sys.exit(
        "AI Usage needs PySide6, which is not installed for this Python.\n"
        "  pip install -r windows/requirements.txt\n"
        "or, from a Nix checkout: nix develop .#windows   (or: make run-windows)"
    )

from PySide6.QtCore import (  # noqa: E402
    Property,
    QObject,
    QRect,
    QRectF,
    Qt,
    QTimer,
    QUrl,
    Signal,
    Slot,
    qInstallMessageHandler,
)
from PySide6.QtGui import (  # noqa: E402
    QAction,
    QActionGroup,
    QColor,
    QFont,
    QFontMetricsF,
    QGuiApplication,
    QIcon,
    QImage,
    QPainter,
    QPainterPath,
    QPen,
    QPixmap,
)
from PySide6.QtNetwork import QLocalServer, QLocalSocket  # noqa: E402
from PySide6.QtQml import QQmlApplicationEngine  # noqa: E402

# Imported for its side effect as much as its name: with QtQuick loaded, the
# engine's root comes back as a QQuickWindow (grabWindow() and all) instead of
# the plain QWindow PySide falls back to for a type it does not know.
from PySide6.QtQuick import QQuickWindow  # noqa: E402
from PySide6.QtWidgets import QApplication, QMenu, QSystemTrayIcon  # noqa: E402


class Backend(QObject):
    """What Main.qml calls into: the data, the settings file and the history.

    Anything that can block — a provider over the network, a history save
    waiting on the other frontend's lock — runs on a worker thread and answers
    with a signal, which Qt delivers on the GUI thread."""

    snapshotReady = Signal(str)
    refreshFailed = Signal(str)
    historyFinished = Signal(str, str)
    busyChanged = Signal()
    autostartChanged = Signal()
    trayStateChanged = Signal(str)
    # A setting changed from the tray menu: key, JSON-encoded value.
    settingRequested = Signal(str, str)
    popupToggleRequested = Signal()

    def __init__(self):
        super().__init__()
        self._pool = ThreadPoolExecutor(max_workers=3, thread_name_prefix="aiusage")
        self._busy = False
        self._autostart = autostart_enabled()

    # ── Data ──
    def _get_busy(self):
        return self._busy

    busy = Property(bool, _get_busy, notify=busyChanged)

    @Slot()
    def refresh(self):
        if self._busy:
            return
        self._busy = True
        self.busyChanged.emit()
        self._pool.submit(self._refresh)

    def _refresh(self):
        try:
            self.snapshotReady.emit(collect_snapshot())
        except Exception as exc:  # the popup shows it; nothing else would
            self.refreshFailed.emit(f"usage backend failed: {exc}")
        finally:
            self._busy = False
            self.busyChanged.emit()

    # ── History ──
    @Slot(str, str)
    def history(self, op, payload):
        """Run one history-io command; the answer arrives as historyFinished."""
        self._pool.submit(lambda: self.historyFinished.emit(op, historyio.run(op, payload)))

    # ── Settings ──
    @Property(str, constant=True)
    def configPath(self):
        return config.config_path()

    @Slot(result=str)
    def loadSettings(self):
        try:
            with open(config.config_path(), encoding="utf-8") as fh:
                return fh.read()
        except OSError:
            return "{}"

    @Slot(str)
    def saveSettings(self, text):
        path = config.config_path()
        os.makedirs(os.path.dirname(path), exist_ok=True)
        tmp = f"{path}.tmp.{os.getpid()}"
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.write(text)
        history.replace(tmp, path)

    # ── Assets ──
    @Property(str, constant=True)
    def iconDir(self):
        return QUrl.fromLocalFile(str(ICON_PATH.parent) + os.sep).toString()

    @Property(str, constant=True)
    def appIcon(self):
        return QUrl.fromLocalFile(str(ICON_PATH)).toString()

    @Property(str, constant=True)
    def historyDir(self):
        return paths.history_dir()

    # ── Start with Windows ──
    @Property(bool, constant=True)
    def autostartAvailable(self):
        return paths.IS_WINDOWS

    def _get_autostart(self):
        return self._autostart

    autostart = Property(bool, _get_autostart, notify=autostartChanged)

    @Slot(bool)
    def setAutostart(self, enabled):
        try:
            set_autostart(enabled)
        except OSError:
            pass
        self._autostart = autostart_enabled()
        self.autostartChanged.emit()

    # ── Tray ──
    @Slot(str)
    def publishTrayState(self, state):
        """The QML side knows which tab is active; it tells the tray what to show,
        as JSON: {"style": TRAY_STYLES key, "floatingPill": bool, "icon": logo
        URL, "tooltip": str, "slots": [{pct, color, text, tooltip}]}."""
        self.trayStateChanged.emit(state)

    @Slot()
    def togglePopupFromPill(self):
        """The floating pill was clicked; the popup opens next to it."""
        self.popupToggleRequested.emit()


_ICON_SIZE = 64


def _canvas():
    pixmap = QPixmap(_ICON_SIZE, _ICON_SIZE)
    pixmap.fill(Qt.transparent)
    painter = QPainter(pixmap)
    painter.setRenderHint(QPainter.Antialiasing)
    return pixmap, painter


def logo_icon(icon):
    """The provider's own logo — the SVG the popup's tabs show — or the app
    icon for a provider that ships none. Handed to Qt as is, so the tray
    renders the SVG at whatever size it needs."""
    path = QUrl(icon).toLocalFile() if icon.startswith("file:") else icon
    return QIcon(path if path and os.path.isfile(path) else str(ICON_PATH))


def ring_icon(pct, color, icon=""):
    """The provider's logo inside a thin usage ring in the slot's colour.

    A negative pct means no data yet: the bare logo."""
    pixmap, painter = _canvas()
    size, logo = _ICON_SIZE, logo_icon(icon)
    if pct < 0:
        logo.paint(painter, 4, 4, size - 8, size - 8)
    else:
        logo.paint(painter, 17, 17, size - 34, size - 34)
        ring = QRectF(5, 5, size - 10, size - 10)
        # Neutral grey, so the empty part of the ring shows on a light taskbar too.
        painter.setPen(QPen(QColor(128, 128, 128, 90), 5, Qt.SolidLine, Qt.FlatCap))
        painter.drawEllipse(ring)
        painter.setPen(QPen(QColor(color or "#cc785c"), 5, Qt.SolidLine, Qt.RoundCap))
        # Clockwise from twelve o'clock; Qt counts in 1/16 degree, anticlockwise.
        painter.drawArc(ring, 90 * 16, -int(max(0.0, min(pct, 100.0)) / 100.0 * 360 * 16))
    painter.end()
    return QIcon(pixmap)


def number_icon(value, color):
    """The percentage as plain digits in the desktop's own UI font, in the
    colour it is given — no badge, no outline, so it sits among the other tray
    icons like text on the panel."""
    pixmap, painter = _canvas()
    size, text = _ICON_SIZE, str(int(value))
    font = QFont(QGuiApplication.font())
    font.setWeight(QFont.Weight.DemiBold)
    # Digits about two thirds of the icon tall, narrowed to fit: "100" comes out
    # smaller than "93", which is the one case three digits have to squeeze.
    font.setPixelSize(100)
    cap_ratio = QFontMetricsF(font).capHeight() / 100 or 0.7
    font.setPixelSize(max(8, int(size * 0.68 / cap_ratio)))
    width = QFontMetricsF(font).horizontalAdvance(text)
    if width > size - 2:
        font.setPixelSize(max(8, int(font.pixelSize() * (size - 2) / width)))
    metrics = QFontMetricsF(font)
    path = QPainterPath()
    path.addText((size - metrics.horizontalAdvance(text)) / 2, (size + metrics.capHeight()) / 2, font, text)
    painter.setPen(Qt.NoPen)
    painter.setBrush(QColor(color or "#cc785c"))
    painter.drawPath(path)
    painter.end()
    return QIcon(pixmap)


def tinted_logo_icon(icon, color):
    """The provider's logo in the value's colour — the panel pill's slot icon,
    which reads severity from its colour.

    A logo that is one tone — a shape, like Claude's or OpenAI's — is filled
    with the colour outright. One with a picture in it, like Kiro's ghost on a
    tile, keeps the picture: its darkest part takes the colour and its lightest
    goes towards white. A flat fill would turn that tile into a solid block, and
    keeping the logo's own lightness would leave OpenAI's black logo black."""
    size = _ICON_SIZE
    image = QImage(size, size, QImage.Format_ARGB32)
    image.fill(Qt.transparent)
    painter = QPainter(image)
    painter.setRenderHint(QPainter.Antialiasing)
    logo_icon(icon).paint(painter, 6, 6, size - 12, size - 12)
    painter.end()

    pixels = [(x, y, image.pixelColor(x, y)) for y in range(size) for x in range(size)]
    pixels = [(x, y, c) for x, y, c in pixels if c.alpha()]
    # The logo's own range of lightness, from its darkest fifth — so that a few
    # small dark details (the ghost's eyes) do not count as its base tone — to
    # its lightest pixel. Edges are left out: antialiasing greys them.
    solid = sorted(c.lightnessF() for _x, _y, c in pixels if c.alpha() > 96)
    lo, hi = (solid[len(solid) // 5], solid[-1]) if solid else (0.0, 0.0)
    hue, saturation, lightness, _alpha = QColor(color or "#cc785c").getHslF()
    hue = max(hue, 0.0)  # -1 for a grey, which has no hue
    pictured = hi - lo >= 0.25
    for x, y, pixel in pixels:
        shade, own = lightness, pixel.lightnessF()
        if pictured and own >= lo:
            shade += (own - lo) / (hi - lo) * (0.97 - lightness)
        elif pictured:
            # Darker than the base tone: the details, kept dark.
            shade *= own / lo
        image.setPixelColor(x, y, QColor.fromHslF(hue, saturation, shade, pixel.alphaF()))
    return QIcon(QPixmap.fromImage(image))


def percent_icon(value, color):
    """The value the way the pill prints it — "83%", the % a size smaller.

    One text size for every value, the largest at which "88%" fits, so "5%"
    and "83%" match side by side; only "100%" has to come out narrower."""
    pixmap, painter = _canvas()
    size, digits = _ICON_SIZE, str(int(value))
    big = QFont(QGuiApplication.font())
    big.setWeight(QFont.Weight.DemiBold)
    small = QFont(big)
    sample = digits if len(digits) > 2 else "88"
    for px in range(60, 8, -1):
        big.setPixelSize(px)
        small.setPixelSize(max(6, int(px * 0.62)))
        width = QFontMetricsF(big).horizontalAdvance(sample) + QFontMetricsF(small).horizontalAdvance("%")
        if width <= size - 2 and QFontMetricsF(big).capHeight() <= size * 0.6:
            break
    big_metrics = QFontMetricsF(big)
    width = big_metrics.horizontalAdvance(digits) + QFontMetricsF(small).horizontalAdvance("%")
    x, baseline = (size - width) / 2, (size + big_metrics.capHeight()) / 2
    path = QPainterPath()
    path.addText(x, baseline, big, digits)
    path.addText(x + big_metrics.horizontalAdvance(digits), baseline, small, "%")
    painter.setPen(Qt.NoPen)
    painter.setBrush(QColor(color or "#cc785c"))
    painter.drawPath(path)
    painter.end()
    return QIcon(pixmap)


def neutral_text_colour():
    """The colour of a number below 70 %: the pill's white on a dark taskbar,
    near-black on a light one. Windows says which its taskbar is (the
    "system" half of the light/dark setting); elsewhere this is the pill's own
    white, which is what a Plasma or Hyprland panel shows."""
    if paths.IS_WINDOWS:
        import winreg

        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize") as key:
                if winreg.QueryValueEx(key, "SystemUsesLightTheme")[0] == 1:
                    return "#1f1f1f"
        except OSError:
            pass
    return "#f8fafc"


def render_entry(entry):
    kind, icon, color = entry["kind"], entry.get("icon") or "", entry.get("color") or ""
    if kind == "logo":
        return logo_icon(icon)
    if kind == "tinted":
        return tinted_logo_icon(icon, color)
    if kind == "ring":
        return ring_icon(entry["value"], color, icon)
    text_colour = entry.get("textColor") or neutral_text_colour()
    if kind == "percent":
        return percent_icon(entry["value"], text_colour)
    return number_icon(entry["value"], text_colour)


class TrayApp:
    """The tray icon, its menu, the popup window, and single-instance handling."""

    # A click on the tray icon first takes focus from the open popup, which then
    # hides itself; the click itself must not reopen it straight away.
    REOPEN_GRACE = 0.3

    def __init__(self, app, engine, backend):
        self.app = app
        self.backend = backend
        self.window = engine.rootObjects()[0]
        self._hidden_at = 0.0

        # The logo and one icon per value in numbers mode, one ring icon
        # otherwise; every one of them opens the popup and has the menu.
        self.icons = []
        self.menus = []
        self._anchor = None
        backend.trayStateChanged.connect(self._on_tray_state)

        # The actions are made once and shared. Each icon gets a menu of its own
        # around them: one QMenu under several icons leaves KDE's DBus menu
        # exporter without ids for its entries.
        def action(text, slot):
            item = QAction(text)
            item.triggered.connect(lambda _checked=False: slot())
            return item

        def request(key, value):
            backend.settingRequested.emit(key, json.dumps(value))

        self.actions = [
            action("Open AI Usage", self.toggle),
            action("Refresh", backend.refresh),
            action("Settings", self.open_settings),
        ]
        # Tray style: exclusive choices, in a "Tray style" submenu of each menu.
        self.style_group = QActionGroup(app)
        self.style_actions = {}
        for key, label in TRAY_STYLES:
            item = QAction(label)
            item.setCheckable(True)
            item.setActionGroup(self.style_group)
            item.triggered.connect(lambda _checked=False, key=key: request("trayStyle", key))
            self.style_actions[key] = item
        self.style_actions[TRAY_STYLES[0][0]].setChecked(True)
        self.pill_action = QAction("Floating pill")
        self.pill_action.setCheckable(True)
        self.pill_action.toggled.connect(lambda on: request("floatingPill", on))
        self.tail_actions = [self.pill_action]
        if backend.autostartAvailable:
            autostart = QAction("Start with Windows")
            autostart.setCheckable(True)
            autostart.setChecked(backend.autostart)
            autostart.toggled.connect(backend.setAutostart)
            backend.autostartChanged.connect(lambda: autostart.setChecked(backend.autostart))
            self.tail_actions.append(autostart)
        separator = QAction()
        separator.setSeparator(True)
        self.tail_actions += [separator, action("Quit", app.quit)]

        # The floating pill is a window of Main.qml's; placing it is done here,
        # where the screens' taskbar-free areas are known.
        self.pill = self.window.findChild(QQuickWindow, "floatingPill")
        self._pill_placed = False
        if self.pill is not None:
            self.pill.visibleChanged.connect(self._on_pill_visible)
            self.pill.widthChanged.connect(self._keep_pill_on_screen)
            # An open popup travels with the pill while it is dragged.
            self.pill.xChanged.connect(self._follow_pill)
            self.pill.yChanged.connect(self._follow_pill)
            backend.popupToggleRequested.connect(self.toggle_from_pill)
            self._on_pill_visible()

        self.window.activeChanged.connect(self._on_active_changed)
        # The popup grows and shrinks with its content; keep it on the taskbar.
        self.window.heightChanged.connect(self._reposition)
        self._show_entries(tray_entries({}))

    # ── Icons ──
    def _add_icon(self, picture):
        icon = QSystemTrayIcon()
        # The picture goes on before show(): a tray icon shown bare is refused.
        icon.setIcon(picture)
        menu = QMenu()
        menu.addActions(self.actions)
        menu.addMenu("Tray style").addActions(list(self.style_actions.values()))
        menu.addActions(self.tail_actions)
        icon.setContextMenu(menu)
        icon.activated.connect(lambda reason, icon=icon: self._on_activated(icon, reason))
        icon.show()
        self.icons.append(icon)
        self.menus.append(menu)

    def _show_entries(self, entries):
        """Match the icons to `entries`, reusing the ones already shown so their
        place in the tray — and the user's choice to keep them visible — stays.

        The tray lays icons out newest first (Plasma does, and Windows adds new
        ones on the left too), so they are made in reverse: that is what puts
        each logo to the left of its number."""
        entries = list(reversed(entries))
        while len(self.icons) > len(entries):
            icon, menu = self.icons.pop(), self.menus.pop()
            if self._anchor is icon:
                self._anchor = None
            icon.hide()
            icon.deleteLater()
            menu.deleteLater()
        for i, entry in enumerate(entries):
            picture = render_entry(entry)
            if i < len(self.icons):
                self.icons[i].setIcon(picture)
            else:
                self._add_icon(picture)
            self.icons[i].setToolTip(entry["tooltip"])

    def _on_tray_state(self, text):
        try:
            state = json.loads(text)
        except ValueError:
            return
        self._show_entries(tray_entries(state))
        # setChecked() does not emit triggered, so the style items need no
        # blocking; the pill switch reports through toggled, which it does.
        style = tray_style(state)
        for key, item in self.style_actions.items():
            item.setChecked(key == style)
        self.pill_action.blockSignals(True)
        self.pill_action.setChecked(state.get("floatingPill") is True)
        self.pill_action.blockSignals(False)

    # ── Floating pill ──
    def _saved_pill_position(self):
        try:
            saved = json.loads(self.backend.loadSettings()).get("pillPosition")
            return int(saved["x"]), int(saved["y"])
        except (ValueError, TypeError, KeyError, AttributeError):
            return None

    def _on_pill_visible(self):
        """Put the pill back where it was left, the first time it shows — or,
        when that spot is on no screen any more, just above the taskbar at the
        bottom right of the main screen."""
        if self._pill_placed or not self.pill.isVisible():
            return
        self._pill_placed = True
        w, h = self.pill.width(), self.pill.height()
        saved = self._saved_pill_position()
        if saved and any(s.availableGeometry().intersects(QRect(saved[0], saved[1], w, h)) for s in QGuiApplication.screens()):
            self.pill.setPosition(*saved)
            return
        area = QGuiApplication.primaryScreen().availableGeometry()
        self.pill.setPosition(area.right() - w - 16, area.bottom() - h - 12)

    def _keep_pill_on_screen(self):
        """The pill widens with the number of values; it must not grow off the
        edge it was dragged against."""
        if not self.pill.isVisible():
            return
        screen = QGuiApplication.screenAt(self.pill.geometry().center()) or QGuiApplication.primaryScreen()
        right = screen.availableGeometry().right()
        if self.pill.x() + self.pill.width() > right:
            self.pill.setX(right - self.pill.width())

    def toggle_from_pill(self):
        self._anchor = self.pill
        self.toggle()

    def _follow_pill(self):
        if self.window.isVisible() and self._anchor is self.pill:
            self._place()

    # ── Popup ──
    def toggle(self):
        if self.window.isVisible():
            self.hide()
        elif time.monotonic() - self._hidden_at > self.REOPEN_GRACE:
            self.show()

    def show(self):
        self._place()
        self.window.show()
        self.window.raise_()
        self.window.requestActivate()

    def hide(self):
        self._hidden_at = time.monotonic()
        self.window.hide()

    def open_settings(self):
        self.window.setProperty("showSettings", True)
        if not self.window.isVisible():
            self.show()

    def _on_active_changed(self):
        if not self.window.isActive() and self.window.isVisible():
            self.hide()

    def _on_activated(self, icon, reason):
        if reason in (QSystemTrayIcon.Trigger, QSystemTrayIcon.DoubleClick):
            # The popup opens next to whichever of the icons was clicked.
            self._anchor = icon
            self.toggle()

    def _reposition(self):
        if self.window.isVisible():
            self._place()

    def _place(self):
        """Put the popup against the taskbar, next to the tray icon.

        The taskbar edge is wherever the screen's available area stops short of
        the screen itself; with no taskbar found, bottom-right."""
        anchor = self._anchor or (self.icons[0] if self.icons else None)
        icon = anchor.geometry() if anchor is not None else QRect()
        screen = QGuiApplication.screenAt(icon.center()) if icon.isValid() else None
        screen = screen or QGuiApplication.primaryScreen()
        area, full = screen.availableGeometry(), screen.geometry()
        w, h, gap = self.window.width(), self.window.height(), 8

        def clamp(value, low, high):
            return max(low, min(value, high))

        if anchor is not None and anchor is self.pill:
            # Opened from the floating pill: under it when there is room, over
            # it otherwise (a pill left just above the taskbar), centred on it.
            x = icon.center().x() - w // 2
            y = icon.bottom() + gap if icon.bottom() + gap + h <= area.bottom() else icon.top() - h - gap
            self.window.setX(clamp(x, area.left() + gap, area.right() - w - gap))
            self.window.setY(clamp(y, area.top() + gap, area.bottom() - h - gap))
            return

        if area.left() > full.left() or area.right() < full.right():
            # Vertical taskbar: beside it, level with the icon.
            x = area.left() + gap if area.left() > full.left() else area.right() - w - gap
            y = icon.center().y() - h // 2 if icon.isValid() else area.bottom() - h - gap
        else:
            y = area.top() + gap if area.top() > full.top() else area.bottom() - h - gap
            x = icon.center().x() - w // 2 if icon.isValid() else area.right() - w - gap
        self.window.setX(clamp(x, area.left() + gap, area.right() - w - gap))
        self.window.setY(clamp(y, area.top() + gap, area.bottom() - h - gap))


# ── KDE Plasma under Wayland ────────────────────────────────────────────────
# Wayland lets no ordinary window keep itself above others, stay out of the
# taskbar or choose where it goes: on a Linux desktop the floating pill sank
# behind every window clicked and showed up in the taskbar, and the popup
# opened in the middle of the screen. KWin, Plasma's compositor, runs scripts
# it is handed over DBus, and this one does all three. Windows needs none of it:
# there the pill is a topmost tool window and TrayApp._place positions the popup.

KWIN_PLUGIN = "ai-usage-widget-pill"
PILL_TITLE = "AI Usage pill"  # windows/qml/Main.qml, pillWindow.title
POPUP_TITLE = APP_NAME  # windows/qml/Main.qml, the root Window's title
_KWIN_SCRIPT = """\
// Loaded by windows/app.py for as long as it runs; see _kwin_keep_pill_above().
// The pill and the popup keep above other windows and out of the taskbar, and
// the popup sits under the pill — over it where there is no room below — and
// follows it while it is dragged, as TrayApp._place does on Windows.
var PILL = "__PILL__", POPUP = "__POPUP__", GAP = 8;

function find(caption) {
    var all = workspace.windowList();
    for (var i = 0; i < all.length; i++)
        if (all[i].caption === caption)
            return all[i];
    return null;
}

function placePopup() {
    var pill = find(PILL), popup = find(POPUP);
    if (!pill || !popup)
        return;
    var p = pill.frameGeometry, g = popup.frameGeometry;
    var area = workspace.clientArea(KWin.MaximizeArea, pill);
    var x = p.x + (p.width - g.width) / 2;
    var y = p.y + p.height + GAP;
    if (y + g.height > area.y + area.height)
        y = p.y - g.height - GAP;
    x = Math.round(Math.max(area.x + GAP, Math.min(x, area.x + area.width - g.width - GAP)));
    y = Math.round(Math.max(area.y + GAP, Math.min(y, area.y + area.height - g.height - GAP)));
    // Only on a real move: setting it fires frameGeometryChanged again.
    if (x !== Math.round(g.x) || y !== Math.round(g.y))
        popup.frameGeometry = {x: x, y: y, width: g.width, height: g.height};
}

function apply(w) {
    if (w.caption !== PILL && w.caption !== POPUP)
        return;
    w.keepAbove = true;
    w.skipTaskbar = true;
    w.skipPager = true;
    w.skipSwitcher = true;
    // The pill moving (a drag) and the popup resizing (its content) both
    // move the popup.
    w.frameGeometryChanged.connect(placePopup);
    placePopup();
}
workspace.windowList().forEach(apply);
workspace.windowAdded.connect(apply);
""".replace("__PILL__", PILL_TITLE).replace("__POPUP__", POPUP_TITLE)


def _kwin_keep_pill_above():
    """Load the KWin script on a Plasma Wayland session. Returns the function
    that unloads it again, or None where it does not apply or KWin said no."""
    if not (sys.platform.startswith("linux") and os.environ.get("WAYLAND_DISPLAY") and "KDE" in os.environ.get("XDG_CURRENT_DESKTOP", "")):
        return None
    from PySide6.QtDBus import QDBusConnection, QDBusInterface

    bus = QDBusConnection.sessionBus()
    scripting = QDBusInterface("org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", bus)
    if not scripting.isValid():
        return None
    path = os.path.join(paths.cache_home(), paths.APP_DIR, "kwin-pill.js")
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(_KWIN_SCRIPT)
    except OSError:
        return None
    # A copy left loaded by a crashed run would refuse the new one.
    scripting.call("unloadScript", KWIN_PLUGIN)
    reply = scripting.call("loadScript", path, KWIN_PLUGIN)
    script_id = reply.arguments()[0] if reply.arguments() else -1
    if not isinstance(script_id, int) or script_id < 0:
        return None
    QDBusInterface("org.kde.KWin", f"/Scripting/Script{script_id}", "org.kde.kwin.Script", bus).call("run")
    return lambda: scripting.call("unloadScript", KWIN_PLUGIN)


def _install_log():
    """Frozen, the app has no console, so Qt's warnings go to a file instead."""
    log_dir = paths.history_dir()
    try:
        os.makedirs(log_dir, exist_ok=True)
        log = open(os.path.join(log_dir, "tray.log"), "a", encoding="utf-8")
    except OSError:
        return

    def handler(_mode, _context, message):
        log.write(time.strftime("%Y-%m-%d %H:%M:%S ") + message + "\n")
        log.flush()

    qInstallMessageHandler(handler)


def _run_headless(app, engine, backend, warnings, screenshot, settings):
    """--selftest and --screenshot. Exits the process itself: a provider may
    still be waiting on the network in a worker thread, and a normal shutdown
    would sit out its timeout."""
    window = engine.rootObjects()[0]
    window.show()
    page = window.findChild(QObject, "settingsPage")
    if page is None:
        warnings.append("settingsPage not found in the popup")
    if window.findChild(QQuickWindow, "floatingPill") is None:
        warnings.append("floatingPill window not found")

    if screenshot:
        # The usage page is only worth a picture once the first snapshot is in;
        # the settings page needs nothing from the network.
        if settings:
            window.setProperty("showSettings", True)

        def grab():
            window.grabWindow().save(screenshot)
            app.quit()

        backend.snapshotReady.connect(lambda _text: QTimer.singleShot(800, grab))
        QTimer.singleShot(1500 if settings else 30000, grab)
        app.exec()
        for warning in warnings:
            print(warning, file=sys.stderr)
        sys.stdout.flush()
        sys.stderr.flush()
        os._exit(0)

    steps = []
    if page is not None:
        # Every section once, so a binding that only breaks on a hidden page
        # still shows up as a warning.
        steps.append(lambda: window.setProperty("showSettings", True))
        for section in ("providers", "panel", "data", "advanced"):
            steps.append(lambda s=section: page.setProperty("section", s))
        steps.append(lambda: window.setProperty("showSettings", False))
    # The first step waits for the first refresh and history load to answer.
    for i, step in enumerate(steps):
        QTimer.singleShot(2500 + 400 * i, step)
    QTimer.singleShot(2500 + 400 * len(steps) + 500, app.quit)
    app.exec()

    for warning in warnings:
        print(warning, file=sys.stderr)
    sys.stdout.flush()
    sys.stderr.flush()
    os._exit(1 if warnings and not screenshot else 0)


def _hand_off_to_running_instance():
    """True when another instance is already up; it is asked to toggle its popup."""
    socket = QLocalSocket()
    socket.connectToServer(SERVER_NAME)
    if not socket.waitForConnected(300):
        return False
    socket.write(b"toggle\n")
    socket.waitForBytesWritten(300)
    socket.disconnectFromServer()
    return True


def main(argv):
    selftest = "--selftest" in argv
    screenshot = argv[argv.index("--screenshot") + 1] if "--screenshot" in argv else ""
    if (selftest or screenshot) and not os.environ.get("QT_QPA_PLATFORM"):
        os.environ["QT_QPA_PLATFORM"] = "offscreen"
    # The shared QML styles every control itself on top of Basic; the native
    # Windows style would fight it.
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

    app = QApplication(argv)
    app.setApplicationName(APP_NAME)
    # Every window's icon, wherever the desktop shows one — on Linux, the pill
    # can get a taskbar entry (see docs/windows.md), which otherwise shows a
    # generic one.
    app.setWindowIcon(QIcon(str(ICON_PATH)))
    app.setQuitOnLastWindowClosed(False)

    headless = selftest or screenshot
    if not headless:
        if _hand_off_to_running_instance():
            return 0
        if FROZEN:
            _install_log()

    backend = Backend()
    engine = QQmlApplicationEngine()
    warnings = []
    engine.warnings.connect(lambda errors: warnings.extend(e.toString() for e in errors))
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(QUrl.fromLocalFile(str(MAIN_QML)))
    if not engine.rootObjects():
        print("\n".join(warnings) or "Main.qml did not load", file=sys.stderr)
        return 1

    if headless:
        return _run_headless(app, engine, backend, warnings, screenshot, "--settings" in argv)

    tray = TrayApp(app, engine, backend)
    server = QLocalServer()
    QLocalServer.removeServer(SERVER_NAME)
    server.listen(SERVER_NAME)
    server.newConnection.connect(lambda: (server.nextPendingConnection(), tray.toggle()))

    # Ctrl+C in the terminal quits. Python only runs a signal handler between
    # bytecodes, and Qt's event loop gives it none while idle — so a timer wakes
    # the interpreter a few times a second.
    signal.signal(signal.SIGINT, lambda *_: app.quit())
    wake = QTimer()
    wake.timeout.connect(lambda: None)
    wake.start(250)

    unload_kwin_script = _kwin_keep_pill_above()
    code = app.exec()
    if unload_kwin_script is not None:
        unload_kwin_script()
    # Leave without waiting for the worker threads: a provider may be waiting on
    # the network, and a normal exit would sit out its timeout. Nothing there
    # needs finishing — a history save lands by atomic rename or not at all.
    sys.stdout.flush()
    sys.stderr.flush()
    os._exit(code)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
