// Quickshell entry point.
//
// The shell itself lives in hyprland/AiUsageShell.qml; this file exists only to
// put the config root at the repository root. Quickshell sandboxes the QML
// engine to the directory holding the file it was pointed at, and anything
// outside resolves to qrc:/qs-blackhole. With the root here, hyprland/*.qml can
// import the provider JS under package/contents/code/ that it shares with the
// Plasma widget; rooted at hyprland/ those imports escape the sandbox and the
// whole configuration fails to load.
//
// Run with `qs -p <repo>` (or `-p <repo>/shell.qml`) — never the file in
// hyprland/, which would reinstate the broken root.
import "hyprland"

AiUsageShell {}
