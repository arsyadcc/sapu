# Sapu agent guide

Sapu is a SwiftUI Mac app (`app/`) on top of an upstream cleanup engine (`engine/`).

## Rules

- `engine/` is a git subtree of https://github.com/tw93/Mole. Do not edit it in place; update it only with `scripts/update-engine.sh`. If the app needs an engine change, propose it upstream first.
- `engine/AGENTS.md` and `engine/.claude/` belong to the upstream project. Their release, sync and GitHub workflows do not apply here, but their safety rules still describe how the engine behaves.
- Never use the name "Mole" or its logo for Sapu's branding, UI copy or marketing. Credit it as the upstream engine only (README, About window).
- The whole repo is GPL-3.0. Keep `LICENSE` and the upstream credit intact.
- Destructive actions in the UI must show a preview and require explicit confirmation. Prefer the Trash over permanent deletion.
- Run the engine through `Engine` (`app/Sapu/Engine/Engine.swift`). It runs non-interactively with `NO_COLOR=1`, so the engine never prompts; anything needing sudo is skipped.

## Build

```bash
cd app && xcodegen generate
xcodebuild -project Sapu.xcodeproj -scheme Sapu -configuration Debug -derivedDataPath ../build build
```

Swift 6 language mode with main-actor default isolation. Tooling: Xcode, XcodeGen, Go.
