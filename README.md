# Calma

Local-only step counter + screen time tracker built with Flutter. Android version is complete; **this branch (`current`) is the one to port to iOS.** A separate `main` branch holds a pre-timezone snapshot (`beta1.0`) for historical reference — don't port from that.

---

## For the iOS porting contributor — start here

**You're using Claude Code to do this port.** The repo is set up to be self-onboarding: clone it, then let Claude Code read `CLAUDE.md` which has the full architecture, channel contracts, and known caveats.

### Your first action (literally the first prompt to Claude Code)

In an empty folder, run `claude`. When it starts, give it exactly this prompt:

```
Clone https://github.com/Benositos/aplikacjaCzechy.git branch `current` into
folder `calma`, then cd into it and read CLAUDE.md fully before doing
anything else. CLAUDE.md is the canonical onboarding doc and tells you what
to do next.
```

Claude Code will clone, `cd`, read `CLAUDE.md`, and then walk you through the rest: installing dependencies, generating Drift code, installing CocoaPods, and starting with `HealthChannel.swift`.

### What you need installed before that first prompt

| Tool | Version | Install |
|---|---|---|
| macOS | Sonoma (14) or newer | — |
| Xcode | 16.x | App Store |
| Xcode Command Line Tools | latest | `xcode-select --install` |
| CocoaPods | latest | `sudo gem install cocoapods` |
| Flutter SDK | **3.44** (pinned, not latest) | https://docs.flutter.dev/get-started/install/macos |
| Node.js + npm | 18+ | https://nodejs.org/ |
| Claude Code | latest | `npm install -g @anthropic-ai/claude-code` |
| Apple Developer Account | Free tier | Sign in via Xcode → Settings → Accounts |

Run `flutter doctor` after install — everything green except possibly Android (you don't need it). A real iPhone with a cable is needed for HealthKit testing (simulator has no health data).

---

## What's in this repo

- `lib/` — Flutter app (Riverpod + Drift + go_router). Android-complete.
- `android/app/src/main/kotlin/com/calma/calma/` — Kotlin platform channels for Health Connect (steps) and UsageStatsManager (screen time). Reference behavior for the iOS port.
- `ios/Runner/` — default Flutter scaffold. **Your work goes here.**
- `CLAUDE.md` — onboarding doc for Claude Code. **Read this fully before doing anything.**

## Privacy / scope

Local-only. No accounts, no backend, no analytics, no network calls of any kind. The project's privacy story is its main differentiator — don't introduce network code.

---

For the design / build / contribution story not covered by the above, see `CLAUDE.md`.
