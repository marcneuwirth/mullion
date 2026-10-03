# Mullion

*A mullion is the bar that divides a window into panes.*

A tiny keyboard-only window manager for macOS, built as a replacement for [Divvy](https://mizage.com/divvy/)
now that Intel-only apps are on their way out. There is no UI: shortcuts snap the focused window to
cells of a grid, and everything is set in one JSON file.

- Native Apple Silicon, no dependencies, ~750 lines of Swift
- Divvy-style grid placement on any display
- **Cycle between screens:** press the same shortcut again to send the window to the next display
- Config reloads automatically when you save it

## Install

Needs macOS 13+ and the Xcode command line tools (`xcode-select --install`).

```sh
git clone git@github.com:marcneuwirth/mullion.git
cd mullion
make install
```

This builds `Mullion.app`, copies it to `/Applications`, and registers a LaunchAgent so it starts at login.

On first launch macOS asks for **Accessibility** access (System Settings → Privacy & Security →
Accessibility). Turn Mullion on, then run `make restart`.

**Quit Divvy first.** macOS lets two apps register the same shortcut. Mullion can only tell when the
other app claimed it exclusively; it logs those, but any other overlap goes unnoticed.

| Command | What it does |
|---|---|
| `make install` | Build, install to `/Applications` (or `APP_DIR=…`), start at login |
| `make restart` | Restart the background agent |
| `make check` | Validate your config file and exit |
| `make logs` | Follow `~/Library/Logs/Mullion.log` |
| `make test` | Run the unit tests |
| `make uninstall` | Stop it and remove the app and LaunchAgent (keeps your config) |

## Config

`~/.config/mullion/config.json`. A default is written on first launch. Changes apply as soon as you
save; if the file can't be read or has an error, Mullion beeps, logs it, and keeps the previous
shortcuts. Keys it doesn't recognise count as errors, so a typo like `"cycleScreen"` can't quietly fall
back to the default.

```json
{
  "grid": { "columns": 6, "rows": 6 },
  "gap": 0,
  "cycleScreens": true,
  "shortcuts": [
    { "keys": "ctrl+cmd+left",     "cells": { "x": 0, "y": 0, "w": 3, "h": 6 } },
    { "keys": "ctrl+cmd+right",    "cells": { "x": 3, "y": 0, "w": 3, "h": 6 } },
    { "keys": "ctrl+cmd+up",       "cells": { "x": 0, "y": 0, "w": 6, "h": 6 } },
    { "keys": "ctrl+cmd+down",     "cells": { "x": 0, "y": 3, "w": 6, "h": 3 } },
    { "keys": "ctrl+cmd+home",     "cells": { "x": 0, "y": 0, "w": 3, "h": 3 } },
    { "keys": "ctrl+cmd+pageup",   "cells": { "x": 3, "y": 0, "w": 3, "h": 3 } },
    { "keys": "ctrl+cmd+end",      "cells": { "x": 0, "y": 3, "w": 3, "h": 3 } },
    { "keys": "ctrl+cmd+pagedown", "cells": { "x": 3, "y": 3, "w": 3, "h": 3 } }
  ]
}
```

| Field | Default | Meaning |
|---|---|---|
| `grid.columns`, `grid.rows` | 6, 6 | How finely the screen is divided |
| `gap` | 0 | Points of space at screen edges and between windows (Divvy's "margins") |
| `cycleScreens` | true | Pressing a shortcut again moves the window to the next display, left to right |
| `shortcuts[].keys` | | Modifiers and a key joined by `+` |
| `shortcuts[].cells` | | `x`, `y`: top-left cell, counted from 0 at the top-left. `w`, `h`: size in cells |

**Modifiers:** `ctrl` (or `control`, `⌃`), `cmd` (or `command`, `⌘`), `alt` (or `opt`, `option`, `⌥`),
`shift` (or `⇧`). At least one is required. Case and spaces around `+` don't matter.

**Keys:** `a`–`z`, `0`–`9`, `left` `right` `up` `down`, `home` `end` `pageup` `pagedown`, `f1`–`f15`,
`space` `return` `tab` `escape` `delete` `forwarddelete`, and punctuation (`,` `.` `/` `;` `'` `[` `]`
`-` `=` `` ` `` `\`). On a laptop keyboard, `home`/`end`/`pageup`/`pagedown` are fn + ←/→/↑/↓.
Some keys have a second name: `enter` for `return`, `esc` for `escape`, `backspace` for `delete`, and
`comma` `period` `slash` `semicolon` `quote` `leftbracket` `rightbracket` `minus` `equal` `grave`
`backslash` for the punctuation.

To check a config without restarting: `make check`, or
`/Applications/Mullion.app/Contents/MacOS/Mullion --check [path]`, which checks your config file when no
path is given. `--help` lists the options.

## Signing

macOS ties Accessibility permission to the app's code signature. `make install` signs with a
certificate named **Mullion Code Signing** if you have one; otherwise it signs ad-hoc, which works but
means re-enabling Mullion in Accessibility settings after every rebuild. To create the certificate once:

1. Open **Keychain Access** → menu **Keychain Access → Certificate Assistant → Create a Certificate…**
2. Name: `Mullion Code Signing`, Identity Type: **Self Signed Root**, Certificate Type: **Code Signing**
3. Create, then `make install` again and re-grant Accessibility one last time.

Use a different certificate with `SIGN_IDENTITY="My Cert" make install`.

## How it works

- **Hotkeys:** Carbon `RegisterEventHotKey`, so it only needs Accessibility permission (no Input
  Monitoring) and never sees any other keystrokes.
- **Moving windows:** the Accessibility API on the frontmost app's focused window. It sets size,
  position, then size again, because some apps only accept a size after moving. Chromium/Electron apps'
  `AXEnhancedUserInterface` is switched off during the move so they don't animate slowly.
- **Screens:** each display's visible frame (menu bar and Dock excluded). The window belongs to the
  display it overlaps most.
- **Repeat detection:** a press counts as a repeat if the window already sits at the target, or exactly
  where the same shortcut last left it. The second check handles apps that round their size, such as
  terminals snapping to character cells.

`Sources/MullionCore` holds the config parsing, key names and grid math with no AppKit dependency, and is
what the tests cover; CI runs them on every push. `Sources/Mullion` is the macOS agent.
