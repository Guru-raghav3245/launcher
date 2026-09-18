# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Phases 1 and 2 are complete (all tasks below), verified live on an Android emulator. Phase 3 is in progress: tasks 1–5 done (tile dashboard shell, Add New Tile sheet, Notes tile, Todo tile, Weather tile); tasks 6–7 (App Folder/From-Apps tile bodies) remain. Phases 4–5 haven't started. The intended product is documented below from UI mockups in `screenshots/`.

## Product: Yin Yang Launcher

An Android home-screen replacement app (yin/yang branding = light/dark duality) combining a calm home screen, a customizable widget dashboard, and screen-time/wellbeing insights.

Features below are grouped into execution phases, ordered so each phase only depends on ones before it. Update Structure/Commands as each phase lands.

### Phase 1 — Launcher core (done)
The minimum to be a working, installable launcher. Tasks, in build order (each depends on the ones above it)

1. ✅ **Register as launcher** — add `HOME`/`LAUNCHER` intent filter to the Android manifest; verify the app shows up in Android's default-launcher picker
2. ✅ **Navigation shell** — 5-panel swipe scaffold (Search / My Space / Home / Mind Space / App Drawer) as an edge-to-edge `PageView` or gesture-detected panel switcher; other panels can be empty placeholders for now (`lib/shell/launcher_shell.dart`)
3. ✅ **Home screen chrome** — wallpaper/gradient background, live clock, date, battery % (`lib/panels/home_panel.dart`)
4. ✅ **Home layout modes** — Classic (adds search bar + 4-app dock) vs Minimal (plain text pinned-app list); mode lives in `AppSettings`, not local state
5. ✅ **Installed-app data source** — `lib/services/installed_apps_service.dart`, wraps the `installed_apps` platform-channel plugin; shared by tasks 6–8
6. ✅ **App Drawer list** — alphabetical list of installed apps with fast-scroll A–Z/#/★ index (`lib/panels/app_drawer_panel.dart`)
7. ✅ **App Drawer search** — `lib/search/app_search.dart` + `app_search_bar.dart`, shared with task 8
8. ✅ **Spotlight Search overlay** — `lib/panels/spotlight_search_panel.dart`, reuses task 7's search/filter logic

### Phase 2 — Onboarding (done)
Wraps Phase 1 features into a first-run flow (`lib/onboarding/`). Tasks, in build order:

1. ✅ **First-run flow scaffold** — `lib/onboarding/onboarding_flow.dart` + `steps/welcome_step.dart`; gated by `OnboardingService`'s persisted `onboarding_complete` flag
2. ✅ **Live preview mockup** — `lib/onboarding/phone_mockup.dart`, renders the real `HomePanel` at a fixed design size inside a phone frame
3. ✅ **Theme step** — Light/Dark toggle in `steps/customize_step.dart`, wired to `AppSettings.isDark`
4. ✅ **Layout step** — Classic/Minimal toggle in the same step, wired to `AppSettings.layoutMode`
5. ✅ **Wallpaper step** — `lib/onboarding/wallpaper_picker.dart`; in light theme the selected swatch also tints the whole Customize step, matching the original design
6. ✅ **"Set as my launcher" step** — `lib/services/launcher_role_service.dart` + `MainActivity.kt`'s `RoleManager.ROLE_HOME` MethodChannel bridge
7. ✅ **Interactive tutorial** — `lib/onboarding/steps/tutorial_step.dart`, 5-page cross-layout walkthrough ending in "Let's Go"

### Phase 3 — My Space (widget dashboard) — in progress
Tasks, in build order (each depends on the ones above it):

1. ✅ **Tile dashboard shell** — `lib/panels/my_space_panel.dart` + `lib/services/my_space_service.dart` (JSON persistence via shared_preferences); empty state matches the original mockup's faded Weather/Todo preview
2. ✅ **"Add New Tile" sheet** — `lib/my_space/add_tile_sheet.dart` + `built_in_tile_specs.dart`; Built-in tab wired to append tiles, From Apps tab is an honest placeholder for task 7
3. ✅ **Notes tile** — freeform text, persisted (`lib/my_space/tiles/notes_tile.dart`)
4. ✅ **Todo tile** — checklist with add-item, persisted (`lib/my_space/tiles/todo_tile.dart`)
5. ✅ **Weather tile** — current temp, hi/lo, location, hourly forecast (`lib/my_space/tiles/weather_tile.dart` + `lib/services/weather_service.dart`); location via `geolocator`, conditions via Open-Meteo, reverse-geocoding via a plain HTTP call to BigDataCloud's free endpoint (not the `geocoding` plugin — its native call ANR'd on-device, see below)
6. ⬜ **App Folder tile** — grouped shortcuts built from the Phase 1 installed-apps data source
7. ⬜ **From-Apps widgets** — browse/search installed apps and embed their native Android AppWidgets via `AppWidgetHost`/`AppWidgetManager` — the most complex tile type, done last

Tile bodies in `my_space_panel.dart`'s `_TileList` are still a placeholder (`Card(ListTile(title: Text(kind.name)))`) for kinds not yet built — tasks 6–7 replace that per-kind.

**Weather tile pitfalls (if touching this code):** `LocationAccuracy.low` uses the network/fused provider, which doesn't respond to `adb emu geo fix` on an emulator — use `.high` with a time limit. The `geocoding` package's native reverse-geocode call blocked the Android main thread indefinitely on the test emulator (no Play Services geocoder backend) and caused an ANR; it was replaced with a timeout-bounded HTTP call instead.

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

- `lib/main.dart` — entry point; gates between `OnboardingFlow` and `LauncherShell` on the persisted onboarding flag
- `lib/shell/` — the 5-panel swipe navigation shell
- `lib/panels/` — the 5 panel screens (Home, My Space, Mind Space, App Drawer, Spotlight Search)
- `lib/onboarding/` — first-run flow (steps, phone mockup, wallpaper/segmented-toggle pickers)
- `lib/my_space/` — My Space-specific widgets (Add New Tile sheet, built-in tile catalog, tile chrome); `lib/my_space/tiles/` holds the per-kind tile bodies (Notes, Todo, Weather)
- `lib/search/` — shared app search/filter logic and UI, used by App Drawer and Spotlight Search
- `lib/state/` — `AppSettings` (theme/layout/wallpaper), exposed via `AppSettingsScope` (`InheritedNotifier`)
- `lib/services/` — platform-channel and persistence services (installed apps, onboarding flag, launcher role, My Space tiles, weather)
- `lib/models/` — plain data models (`HomeLayoutMode`, `MySpaceTile`, `TileKind`)
- `lib/widgets/` — small shared widgets (`SegmentedToggle`)
- `android/app/src/main/kotlin/.../MainActivity.kt` — native `RoleManager.ROLE_HOME` MethodChannel bridge (`yinyang.launcher/role`)
- `test/` — widget tests; app startup is async (SharedPreferences), so tests use `SharedPreferences.setMockInitialValues` and `pumpAndSettle`
- `android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/` — platform runner projects generated by Flutter tooling; rarely need manual edits
- Dart SDK constraint: `^3.13.3` (see `pubspec.yaml`)
- `graphify-out/` — generated knowledge-graph artifacts from `/graphify`; not app code, gitignored
