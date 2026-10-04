# Mullion

*A mullion is the bar that divides a window into panes.*

A keyboard-only window manager for macOS. Shortcuts snap the focused window to cells of a grid, and
everything is set in one JSON file. There is no UI. It started as a replacement for
[Divvy](https://mizage.com/divvy/), which is Intel-only.

- Divvy-style grid placement on any display
- **Cycle between screens:** press the same shortcut again to send the window to the next display
- Config reloads automatically when you save it
- Universal (Apple Silicon and Intel), notarized, no dependencies

## Install

Requires macOS 13 or later.

```sh
brew install --cask marcneuwirth/tap/mullion
```

Or download `Mullion-<version>.zip` from the [latest release](https://github.com/marcneuwirth/mullion/releases/latest),
unzip it, and move **Mullion.app** to Applications.

Homebrew starts Mullion after installing it; if you downloaded the zip, open it yourself. Turn it on
when macOS asks for **Accessibility** access (System Settings → Privacy & Security → Accessibility). It
has no window or menu bar icon. On first launch it writes a default config and adds itself to **Login
Items** so it starts at login. Opening it again while it runs opens your config file.

To see whether it's running, run `mullion --status` (Homebrew links the `mullion` command; with the zip,
use `/Applications/Mullion.app/Contents/MacOS/Mullion`). It also checks your config and shows the end of
the log. `mullion --restart` quits it and starts it again.

**Quit Divvy first.** macOS lets two apps register the same shortcut. Mullion can only tell when the
other app claimed it exclusively; it logs those to `~/Library/Logs/Mullion.log`, but any other overlap
goes unnoticed.

To uninstall, run `brew uninstall --cask mullion`. Add `--zap` to also delete your config and log.

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

To check a config without restarting: `mullion --check [path]`, which checks your config file when no
path is given. `--help` lists the options.

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
what the tests cover; CI runs them on every push. `Sources/Mullion` is the macOS app.

## Building from source

Needs the Xcode command line tools (`xcode-select --install`).

```sh
git clone https://github.com/marcneuwirth/mullion.git
cd mullion
make install
```

| Command | What it does |
|---|---|
| `make install` | Build, install to `/Applications` (or `APP_DIR=…`) and open it |
| `make restart` | Quit and reopen Mullion |
| `make check` | Validate your config file and exit |
| `make logs` | Follow `~/Library/Logs/Mullion.log` |
| `make test` | Run the unit tests |
| `make uninstall` | Remove it from Login Items, quit, and delete the app (keeps your config) |

macOS ties Accessibility permission to the app's code signature. `make install` signs with your
**Developer ID Application** certificate if you have one, then one named **Mullion Code Signing**, and
otherwise ad-hoc. An ad-hoc build works, but you have to re-enable Mullion in Accessibility settings
after every rebuild. To avoid that, create a self-signed certificate: in Keychain Access, choose
**Keychain Access → Certificate Assistant → Create a Certificate…**, name it `Mullion Code Signing`, and
set Identity Type to **Self Signed Root** and Certificate Type to **Code Signing**. Run `make install`
again and re-grant Accessibility one last time. `SIGN_IDENTITY="My Cert" make install` uses a different
certificate.

Releases are built, signed and notarized by CI; see [RELEASING.md](RELEASING.md).

## License

MIT, see [LICENSE](LICENSE).
