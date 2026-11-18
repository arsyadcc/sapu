# Sapu

A free, open-source Mac cleaner with a native SwiftUI interface.

Sapu shows system health, previews and removes safe-to-delete caches and logs, and helps you find what is filling up your disk. Nothing is deleted until you review a preview and confirm.

## Features

- **Status**: health score, CPU, memory, disks, battery and top processes.
- **Clean**: scans caches, logs and app leftovers, shows a full preview, then cleans on confirmation.
- **Disk Usage**: browse folders by size, reveal items in Finder, or move them to the Trash.

## Requirements

- macOS 14 or later
- To build: Xcode 26 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen) and Go (`brew install xcodegen go`)

## Build

```bash
cd app
xcodegen generate
xcodebuild -project Sapu.xcodeproj -scheme Sapu -configuration Release -derivedDataPath ../build build
open ../build/Build/Products/Release/Sapu.app
```

Or open `app/Sapu.xcodeproj` in Xcode after running `xcodegen generate`. A build phase compiles the engine's Go helpers and copies the engine into the app bundle.

## Project layout

| Path | Contents |
|---|---|
| `app/` | The SwiftUI app (XcodeGen spec in `app/project.yml`) |
| `engine/` | The cleanup engine, a git subtree of [Mole](https://github.com/tw93/Mole) |
| `scripts/bundle-engine.sh` | Builds and copies the engine into the app bundle |
| `scripts/update-engine.sh` | Pulls the latest upstream engine |

The app drives the engine as a child process: `status --json` and `analyze --json` for structured data, and the text output of `clean --dry-run` / `clean` for cleaning.

## Credits and license

Sapu's cleanup engine is [Mole](https://github.com/tw93/Mole) by tw93 and its contributors, used under the GNU General Public License v3.0. Sapu is an independent project and is not affiliated with or endorsed by the Mole project. "Mole" is a trademark of the Mole project.

Sapu is free software, licensed under the [GNU General Public License v3.0](LICENSE).
