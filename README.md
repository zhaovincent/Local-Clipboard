# Local Clipboard

**English** · [简体中文](README.zh-CN.md)

A native, lightweight, **fully local** clipboard history manager for macOS. It quietly records the text, links, images and files you copy, and brings them back the moment you press `⌘⇧V` — search, pick, paste.

No account, no cloud, no network calls, no telemetry. Your data never leaves your own disk.

<p align="center">
  <img src="docs/screenshot.png" width="420" alt="Local Clipboard panel">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B%20(Apple%20Silicon)-black">
  <img src="https://img.shields.io/badge/Swift-5.x-orange">
  <img src="https://img.shields.io/badge/dependencies-0-brightgreen">
  <img src="https://img.shields.io/badge/build-Xcode%20not%20required-blue">
  <img src="https://img.shields.io/badge/license-Apache--2.0-blue">
</p>

---

## Why it exists

macOS gives you exactly one clipboard slot: copy something new and the previous item is gone. The item you actually need is usually the one that was just overwritten.

Local Clipboard lives in your menu bar and keeps the recent ones. When you need one, press `⌘⇧V`, the panel fades in where your cursor is, and history plus search is right there.

**Design stance**: no cloud sync, no team sharing, no AI rewriting. Just one thing done properly — local clipboard history that is fast, reliable, good-looking and unobtrusive.

## Features

| Capability | What it does |
| --- | --- |
| Automatic capture | Text, links, images and files. Duplicates are de-duplicated and moved to the top |
| Global shortcut | `⌘⇧V` by default, re-recordable. Falls back to another free combo if taken |
| One-key paste | Picking an item writes it back to the clipboard; optional auto-paste sends it straight into the frontmost app |
| Image support | Original file on disk, generated thumbnail, full-size preview in the panel |
| Search & filter | All / Text / Images / Files / Pinned, filtered locally in real time |
| Pinning | Keep frequently used snippets on top; they survive "clear history" |
| Retention policy | Keep 100 / 300 / 500 / 1000 items, cap image storage, auto-clean by age |
| Privacy guards | Skips content marked `ConcealedType` by password managers; everything stays on disk |
| Launch at login | Writes a `~/Library/LaunchAgents` entry, starts silently after you log in |
| Dark mode | Follows the system, or lock light / dark manually. Native material and web theme transition together |
| Custom storage location | Change the data folder in Settings; history and images migrate automatically, and you can restore the default |
| Backup & migrate | Export everything as a single zip (`history.json` + all images); import merges and de-duplicates by content |
| Interface language | Chinese / English, following your Mac's language on first launch; switchable any time in Settings |
| Look and feel | Real system blur (`NSVisualEffectView`), light and dark themes |

### Keyboard-first

You never need the mouse:

| Key | Action |
| --- | --- |
| `⌘⇧V` | Show / hide the panel (customizable) |
| `↑` `↓` | Move the selection |
| `↵` or click a card | Copy (and paste directly if auto-paste is on) |
| `⌘1` – `⌘9` | Copy the 1st – 9th item immediately |
| `⌘F` | Focus the search field |
| `⌘⌫` | Delete the selected item |
| `⌘,` | Open Settings |
| `esc` | Step back: preview → settings → search query → panel |

## Install

Download `Local Clipboard-1.2.0.dmg` from [Releases](../../releases), mount it, then either:

1. **Drag** `Local Clipboard.app` into the `Applications` folder on the right
2. **One click**: double-click `Install Local Clipboard.command` — it installs to `/Applications` and launches

> If macOS says the developer cannot be verified: right-click the app in Applications → **Open** → **Open**.
> Or run `sudo xattr -dr com.apple.quarantine "/Applications/Local Clipboard.app"`.
> The project uses an ad-hoc local signature and is not notarized, so this is expected.

**Auto-paste** needs the Accessibility permission: System Settings → Privacy & Security → Accessibility → enable Local Clipboard. Without it the app still works, it just degrades to "copy only" — pressing `⌘V` yourself does the same thing.

## How it is built

The interesting part of this project is that it barely uses Apple's standard tooling:

- **Zero dependencies, zero Xcode**: a single `build.sh` compiles the Swift sources with the command-line `swiftc`, then assembles the `.app` bundle, generates the `.icns`, ad-hoc signs it and packs a DMG by hand. A full build takes a few seconds, so you can `git clone` and start hacking immediately.
- **AppKit + WebKit hybrid**: window, blur, global hotkey, clipboard polling and the menu bar item are native Swift. The list, animations, search and keyboard navigation inside the panel are HTML/CSS/JS. UI iterations do not require recompiling Swift.
- **Custom icon pipeline**: `scripts/make_icon_from_image.swift` takes one 2048px design file, removes the background, fits it to Apple's icon grid, applies the squircle corner and shadow, then emits all ten sizes from 16 to 1024 — plus the small logo used in the panel header.
- **A reliable native ↔ web bridge**: the native side keeps a `jsReady` flag and a pending queue, and the web page performs a `post("ready")` handshake so nothing is pushed into a page that has not loaded yet.
- **Self-testing**: `scripts/uitest.swift` renders the real UI off-screen and reports DOM metrics, JS errors and a screenshot; `scripts/verify_live.swift` reproduces the bridge gating logic to verify the data path. Neither needs screen-recording permission, so both fit into CI.

Size: roughly 1600 lines of Swift and 1900 lines of web code (no framework, no bundler).

### Layout

```
local-clipboard/
├── Sources/                      # Native layer (AppKit + WebKit bridge)
│   ├── main.swift                # Entry point
│   ├── AppDelegate.swift         # Menu bar, status item, context menu, lifecycle
│   ├── PanelController.swift     # Panel window, JS bridge, hotkey recording, paste scheduling
│   ├── ClipboardMonitor.swift    # Clipboard polling and type detection
│   ├── HistoryStore.swift        # Persistence, de-duplication, retention, image assets
│   ├── DataTransfer.swift        # Zip export / import and migration helpers
│   ├── L10n.swift                # Chinese / English strings, system language resolution
│   ├── PasteService.swift        # Write back to clipboard + simulated ⌘V
│   ├── HotKeyManager.swift       # Carbon global hotkey with conflict fallback
│   ├── SettingsStore.swift       # Settings, launch at login, key-name mapping
│   ├── ImageUtils.swift          # Thumbnail / preview generation
│   ├── SelfTest.swift            # Offline self-test (LC_SELFTEST=1)
│   └── Models.swift              # Data models
├── Web/                          # Interface layer (HTML + CSS + JS, no framework)
├── Resources/
│   ├── Info.plist
│   └── AppLogo.png               # Icon source (rebuild after replacing it)
├── scripts/
│   ├── make_icon_from_image.swift  # Design file → full-size icns
│   ├── make_icon.swift             # Pure-code icon fallback
│   ├── uitest.swift                # Off-screen render + DOM assertions + screenshot
│   ├── verify_live.swift           # Bridge data-path verification
│   ├── Install.command             # One-click installer inside the DMG
│   └── 安装说明.txt
├── docs/screenshot.png
└── build.sh
```

### Build from source

```bash
git clone <repo-url> && cd local-clipboard
bash build.sh            # compile → assemble .app → icns → sign → pack DMG
open "build/Local Clipboard.app"
```

Only **Command Line Tools** are required (`xcode-select --install`); full Xcode is not. Output lands in `build/` and `dist/`.

### Where the data lives

```
~/Library/Application Support/Local Clipboard/
├── history.json      # Index: pinned state, source app, timestamps
└── images/           # Original, thumbnail and preview images
```

Deleting that folder is a complete wipe — nothing is left anywhere else. If you pick a custom location in Settings, the same structure is created under a `Local Clipboard` folder inside it.

## Known limitations

- **Apple Silicon only** (build target `arm64-apple-macos13.0`). For Intel, change `TARGET` in `build.sh` to `x86_64-apple-macos13.0`
- No iCloud or multi-device sync — a deliberate trade-off
- Ad-hoc signed and not notarized, so the first launch needs a manual approval
- The panel hides itself when it loses focus; this is intended

## Roadmap

- [x] Dark mode (system-following + manual)
- [x] Custom storage location (automatic data migration)
- [x] Export / import raw data (zip backup and merge restore)
- [x] Chinese / English interface (follows the system language on launch)
- [x] One-click clear (keeps pinned items, with confirmation)
- [ ] Inline editing of an entry and "paste as plain text"
- [ ] Per-app shortcut behavior (different actions in different apps)
- [ ] Image OCR text search (local framework only)
- [ ] Homebrew Cask distribution

## Contributing

Issues and PRs are welcome. UI changes only touch `Web/`; after changing them, run the self-check:

```bash
swift -sdk "$(xcrun --show-sdk-path)" scripts/uitest.swift Web build/ui-shot.png
LC_UI_LANG=en swift -sdk "$(xcrun --show-sdk-path)" scripts/uitest.swift Web build/ui-shot-en.png
LC_UI_DARK=1 swift -sdk "$(xcrun --show-sdk-path)" scripts/uitest.swift Web build/ui-shot-dark.png
```

It reports card count, section grouping, panel size, title metrics, i18n strings and any JS error — faster than clicking through by hand.

## License

Released under the [Apache License 2.0](LICENSE).

```
Copyright 2026 junyue

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

In short: free to use, modify, sell and redistribute, as long as you keep the copyright and license notices, state what you changed in modified files, and accept the explicit patent grant and warranty disclaimer.
