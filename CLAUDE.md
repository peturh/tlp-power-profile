# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project goal

A Dank Material Shell (DMS) plugin that replaces the built-in battery / power-profile widget with one backed by **TLP** instead of `power-profiles-daemon`. The widget shows battery state and exposes TLP's power modes (`tlp ac` / `tlp bat`) and charge thresholds (`tlp setcharge`) — features `power-profiles-daemon` does not provide.

This is a single-plugin repo, not a fork of DMS.

## DMS plugin shape (the "big picture")

A DMS plugin is a directory of QML files plus a JSON manifest. There is no build step — QML is loaded at runtime by Quickshell.

Required structure for a bar-widget plugin:

```
plugin.json                # manifest: id, type, component, permissions, requires
<Widget>.qml               # main entry; root is a PluginComponent
<Widget>Settings.qml       # optional, root is PluginSettings
```

Key plugin.json fields for this project:
- `"type": "widget"` with `"component": "./<file>.qml"`
- `"permissions": ["process", "settings_read", "settings_write"]` — `process` is required to shell out to TLP
- `"requires": ["tlp"]` — DMS checks for the binary before loading

The Widget.qml root must be `PluginComponent` and must define two `Component` properties — `horizontalBarPill` and `verticalBarPill` — one for each bar orientation. Both receive auto-injected properties: `pluginData`, `pluginService`, `pluginId`, `iconSize`.

Settings persist via `PluginSettings { pluginId: "..." }` containing typed setting nodes (`ToggleSetting`, `SliderSetting`, `StringSetting`, `SelectionSetting`, `ColorSetting`). Reading saved values back into the widget happens through `pluginData.<key>`.

Imports used by widget QML:
```qml
import QtQuick
import qs.Common          // Theme.* tokens (spacingS, surfaceText, etc.)
import qs.Widgets         // StyledText, DankIcon
import qs.Modules.Plugins // PluginComponent, PluginSettings, *Setting nodes
```

## TLP integration notes

TLP is invoked via its CLI; there's no DBus interface (this is the main reason the plugin exists — `power-profiles-daemon` is DBus, TLP is not).

- **Reading state** (no sudo): `tlp-stat -b` (battery + thresholds), `tlp-stat -s` (mode AC/BAT), `tlp-stat -c` (active config). Output is plain text — parsing is required.
- **Switching mode** (needs sudo): `tlp ac` / `tlp bat` / `tlp start`.
- **Charge thresholds** (needs sudo): `tlp setcharge <start> <stop> [BATn]`. Constraint: `stop > start + 3`, both 1–100. If hardware only supports stop, pass start as 0.
- **Battery name** comes from `tlp-stat -b` (e.g. `BAT0`, `BAT1`); don't hardcode.

Because every state-changing TLP call needs root, the widget will need a polkit rule or a sudoers entry for `tlp` — design action handlers to surface failures cleanly via `ToastService.showError(...)` when the privileged call is rejected.

For long-running or output-capturing calls use Quickshell's `Process` component; for fire-and-forget use `Quickshell.execDetached(["sh","-c","..."])`.

## Development workflow

There is no build / lint / test toolchain. The dev loop is symlink → reload:

```bash
# One-time: install into DMS's plugin dir
ln -s "$PWD" ~/.config/DankMaterialShell/plugins/tlp-power-profile

# After edits: hot-reload (no shell restart needed)
dms ipc call plugins reload tlp-power-profile

# If structure changed (new files, manifest edits) and reload doesn't pick it up:
dms restart
```

First-time activation: open DMS Settings → Plugins → "Scan for Plugins", enable, then add to the DankBar widget list.

Useful introspection:
- `dms ipc call plugins list` — confirm DMS sees the plugin
- `dms ipc call plugins status tlp-power-profile` — error messages from a failed load
- DMS logs surface QML errors; check them when a reload silently does nothing

## Conventions worth following

- Use `Theme.*` tokens for spacing/colors — don't hardcode pixel values or hex codes; the bar adapts to user theme.
- Mirror the layout idiom from existing DMS widgets: `Row` inside `horizontalBarPill`, `Column` inside `verticalBarPill`, with the same children.
- Keep TLP parsing isolated (one QML/JS module) so the widget code stays declarative.
- `pluginData.*` is the read path for settings, `pluginService.savePluginData(...)` / `savePluginState(...)` are the write paths — state (transient UI) is separate from data (user settings).
