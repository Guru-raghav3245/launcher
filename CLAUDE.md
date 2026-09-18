# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

This is a freshly-scaffolded Flutter app (`flutter create`) with no custom architecture yet — `lib/main.dart` is still the default counter demo. There is no code beyond the stock structure; update the Structure/Commands sections once real architecture exists. The intended product is documented below from UI mockups in `screenshots/`.

## Product: Yin Yang Launcher

An Android home-screen replacement app (yin/yang branding = light/dark duality) combining a calm home screen, a customizable widget dashboard, and screen-time/wellbeing insights.

Features below are grouped into execution phases, ordered so each phase only depends on ones before it. Update Structure/Commands as each phase lands.

### Phase 1 — Launcher core
The minimum to be a working, installable launcher. Tasks, in build order (each depends on the ones above it):

1. **Register as launcher** — add `HOME`/`LAUNCHER` intent filter to the Android manifest; verify the app shows up in Android's default-launcher picker
2. **Navigation shell** — 5-panel swipe scaffold (Search / My Space / Home / Mind Space / App Drawer) as an edge-to-edge `PageView` or gesture-detected panel switcher; other panels can be empty placeholders for now
3. **Home screen chrome** — wallpaper/gradient background, live clock, date, battery %
4. **Home layout modes** — Classic (adds search bar + 4-app dock) vs Minimal (plain text pinned-app list), switchable via local state
5. **Installed-app data source** — platform-channel/plugin layer to query installed apps (label, icon, package name, launch intent); shared by tasks 6–8
6. **App Drawer list** — alphabetical list of installed apps with fast-scroll A–Z/#/★ index
7. **App Drawer search** — search field + filter/sort control over the same app list
8. **Spotlight Search overlay** — swipe-down panel reusing the search/filter logic from task 7

### Phase 2 — Onboarding
Wraps Phase 1 features into a first-run flow. Tasks, in build order:

1. **First-run flow scaffold** — welcome screen ("Welcome to Yin Yang Launcher") + step container with a `Continue`/`Next` progression bar; gate it to show only before a launcher is set as default
2. **Live preview mockup** — a phone-frame widget that renders the actual Home screen (chrome from Phase 1 task 3) at small scale, reused as the picker step's live preview
3. **Theme step** — Light/Dark toggle wired to app theme state and reflected in the mockup
4. **Layout step** — Classic/Minimal toggle wired to Phase 1's home-layout state and reflected in the mockup
5. **Wallpaper step** — preset swatch gallery wired to background state and reflected in the mockup
6. **"Set as my launcher" step** — trigger the Android default-launcher role/picker dialog and handle the result (confirmed vs cancelled)
7. **Interactive tutorial** — 4-step swipe/long-press walkthrough of the Phase 1 nav shell (Home → My Space → Mind Space → Spotlight → App Drawer) with progress dots, ending in a "Let's Go" CTA into the real Home screen

### Phase 3 — My Space (widget dashboard)
- Tile dashboard shell on the My Space panel, with "Add New Tile" flow
- Built-in widgets (no external deps): Notes (freeform text), Todo (checklist with add-item)
- Built-in widget: Weather (current temp, hi/lo, location, hourly forecast) — needs a weather API + location permission
- App Folder widget: grouped shortcuts to chosen apps
- Widgets sourced from installed apps: browse/search installed apps and embed their native Android AppWidgets — needs `AppWidgetHost`/`AppWidgetManager` integration, the most complex tile type, do last in this phase

### Phase 4 — Mind Space (screen-time insights)
Needs `PACKAGE_USAGE_STATS` permission and accumulated usage data, so it follows the other panels.
- Usage tracking: screen time, pickups, app opens
- Hourly usage bar chart (12 AM–Now)
- Per-app breakdown (opens + time) with a behavioral insight line
- Habits & Reflexes: derived behavioral patterns (e.g. what's opened right after unlock)
- Quick actions: Pause, Timer, Focus Mode

### Phase 5 — Settings
Aggregates toggles/controls introduced in earlier phases into one screen; do last since it has no independent surface of its own.
- Settings screen (via long-press on Home): search across settings/modes/tools
- Toggles: Theme (Light/Dark), Focus Mode
- Settings groups: Appearance, Launcher Settings, System Settings
- Mind Space quick actions surfaced here too: Pause, Timer, Focus Mode
- Restart Launcher action

## Commands

- Run app: `flutter run` (pick a device with `-d <device_id>`; `flutter devices` lists available targets)
- Install deps: `flutter pub get`
- Analyze/lint: `flutter analyze` (rules from `analysis_options.yaml`, which includes `package:flutter_lints/flutter.yaml`)
- Run all tests: `flutter test`
- Run a single test file: `flutter test test/widget_test.dart`
- Build release: `flutter build <apk|ios|macos|web|linux|windows>`

## Structure

- `lib/` — app source (currently just `main.dart`)
- `test/` — widget/unit tests
- `android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/` — platform runner projects generated by Flutter tooling; rarely need manual edits
- Dart SDK constraint: `^3.13.3` (see `pubspec.yaml`)
