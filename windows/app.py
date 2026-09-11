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
    QRectF,
    Qt,
    QTimer,
    QUrl,
    Signal,
    Slot,
    qInstallMessageHandler,
)
from PySide6.QtGui import QColor, QGuiApplication, QIcon, QPainter, QPen, QPixmap  # noqa: E402
from PySide6.QtNetwork import QLocalServer, QLocalSocket  # noqa: E402
from PySide6.QtQml import QQmlApplicationEngine  # noqa: E402

# Imported for its side effect as much as its name: with QtQuick loaded, the
# engine's root comes back as a QQuickWindow (grabWindow() and all) instead of
# the plain QWindow PySide falls back to for a type it does not know.
from PySide6.QtQuick import QQuickWindow  # noqa: E402, F401
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
    trayStateChanged = Signal(float, str, str)

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
    @Slot(float, str, str)
    def publishTrayState(self, pct, color, tooltip):
        """The QML side knows which tab is active; it tells the tray what to show."""
        self.trayStateChanged.emit(pct, color, tooltip)


def tray_icon(pct, color):
    """The app icon with a usage ring around it, drawn in the slot's colour.

    A negative pct means no data yet: the bare icon."""
    size = 64
    pixmap = QPixmap(size, size)
    pixmap.fill(Qt.transparent)
    painter = QPainter(pixmap)
    painter.setRenderHint(QPainter.Antialiasing)
    base = QIcon(str(ICON_PATH))
    if pct < 0:
        base.paint(painter, 4, 4, size - 8, size - 8)
    else:
        base.paint(painter, 14, 14, size - 28, size - 28)
        ring = QRectF(5, 5, size - 10, size - 10)
        painter.setPen(QPen(QColor(255, 255, 255, 70), 7, Qt.SolidLine, Qt.FlatCap))
        painter.drawEllipse(ring)
        painter.setPen(QPen(QColor(color or "#cc785c"), 7, Qt.SolidLine, Qt.RoundCap))
        # Clockwise from twelve o'clock; Qt counts in 1/16 degree, anticlockwise.
        painter.drawArc(ring, 90 * 16, -int(max(0.0, min(pct, 100.0)) / 100.0 * 360 * 16))
    painter.end()
    return QIcon(pixmap)


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

        self.tray = QSystemTrayIcon(tray_icon(-1, ""))
        self.tray.setToolTip(APP_NAME)
        self.tray.activated.connect(self._on_activated)
        backend.trayStateChanged.connect(self._on_tray_state)

        menu = QMenu()
        menu.addAction("Open AI Usage", self.toggle)
        menu.addAction("Refresh", backend.refresh)
        menu.addAction("Settings", self.open_settings)
        if backend.autostartAvailable:
            action = menu.addAction("Start with Windows")
            action.setCheckable(True)
            action.setChecked(backend.autostart)
            action.toggled.connect(backend.setAutostart)
            backend.autostartChanged.connect(lambda: action.setChecked(backend.autostart))
        menu.addSeparator()
        menu.addAction("Quit", app.quit)
        self.menu = menu
        self.tray.setContextMenu(menu)

        self.window.activeChanged.connect(self._on_active_changed)
        # The popup grows and shrinks with its content; keep it on the taskbar.
        self.window.heightChanged.connect(self._reposition)
        self.tray.show()

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

    def _on_activated(self, reason):
        if reason in (QSystemTrayIcon.Trigger, QSystemTrayIcon.DoubleClick):
            self.toggle()

    def _reposition(self):
        if self.window.isVisible():
            self._place()

    def _place(self):
        """Put the popup against the taskbar, next to the tray icon.

        The taskbar edge is wherever the screen's available area stops short of
        the screen itself; with no taskbar found, bottom-right."""
        icon = self.tray.geometry()
        screen = QGuiApplication.screenAt(icon.center()) if icon.isValid() else None
        screen = screen or QGuiApplication.primaryScreen()
        area, full = screen.availableGeometry(), screen.geometry()
        w, h, gap = self.window.width(), self.window.height(), 8

        def clamp(value, low, high):
            return max(low, min(value, high))

        if area.left() > full.left() or area.right() < full.right():
            # Vertical taskbar: beside it, level with the icon.
            x = area.left() + gap if area.left() > full.left() else area.right() - w - gap
            y = icon.center().y() - h // 2 if icon.isValid() else area.bottom() - h - gap
        else:
            y = area.top() + gap if area.top() > full.top() else area.bottom() - h - gap
            x = icon.center().x() - w // 2 if icon.isValid() else area.right() - w - gap
        self.window.setX(clamp(x, area.left() + gap, area.right() - w - gap))
        self.window.setY(clamp(y, area.top() + gap, area.bottom() - h - gap))

    def _on_tray_state(self, pct, color, tooltip):
        self.tray.setIcon(tray_icon(pct, color))
        self.tray.setToolTip(tooltip or APP_NAME)


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
    return app.exec()


if __name__ == "__main__":
    sys.exit(main(sys.argv))
