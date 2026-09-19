# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Phases 1, 2, and 3 are complete (all tasks below), verified live on an Android emulator. Phases 4–5 haven't started; each is now broken into build-ordered tasks below, same as the earlier phases. The intended product is documented below from UI mockups in `screenshots/`.

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

### Phase 3 — My Space (widget dashboard) — done
Tasks, in build order (each depends on the ones above it):

1. ✅ **Tile dashboard shell** — `lib/panels/my_space_panel.dart` + `lib/services/my_space_service.dart` (JSON persistence via shared_preferences); empty state matches the original mockup's faded Weather/Todo preview
2. ✅ **"Add New Tile" sheet** — `lib/my_space/add_tile_sheet.dart` + `built_in_tile_specs.dart`; Built-in tab wired to append tiles, From Apps tab lists other apps' widgets (task 7)
3. ✅ **Notes tile** — freeform text, persisted (`lib/my_space/tiles/notes_tile.dart`)
4. ✅ **Todo tile** — checklist with add-item, persisted (`lib/my_space/tiles/todo_tile.dart`)
5. ✅ **Weather tile** — current temp, hi/lo, location, hourly forecast (`lib/my_space/tiles/weather_tile.dart` + `lib/services/weather_service.dart`); location via `geolocator`, conditions via Open-Meteo, reverse-geocoding via a plain HTTP call to BigDataCloud's free endpoint (not the `geocoding` plugin — its native call ANR'd on-device, see below)
6. ✅ **App Folder tile** — grouped shortcuts built from the Phase 1 installed-apps data source (`lib/my_space/tiles/app_folder_tile.dart`); packages stored as `{"packages": [...]}`, icons/names looked up live via `InstalledAppsService`, tap launches the app, long-press removes the shortcut, "+" opens a picker sheet (reuses the App Drawer's `AppSearchBar`/`AppResultRow`/`filterAndSortApps`)
7. ✅ **From-Apps widgets** — browse/search other apps' native Android AppWidgets and embed them via `AppWidgetHost`/`AppWidgetManager` (`android/.../AppWidgetHostBridge.kt` + `lib/services/app_widget_service.dart` + `lib/my_space/tiles/from_app_tile.dart`); the Add New Tile sheet's From Apps tab lists every installed provider (grouped by app icon/name, searchable), tapping one allocates + binds the widget id, falling back to the system's `ACTION_APPWIDGET_BIND` consent dialog when the fast `bindAppWidgetIdIfAllowed` path is refused (this app isn't the default launcher in dev); the bound widget is then rendered live via an `AndroidView` platform view wrapping `AppWidgetHost.createView`

Tile bodies in `my_space_panel.dart`'s `_TileList` cover every `TileKind` now — no placeholder remains.

**From-Apps widget pitfalls (if touching this code):** a freshly created `AppWidgetHostView` renders blank for many widgets because their RemoteViews pick a layout by declared size, which defaults to 0×0 dp until told otherwise — `AppWidgetPlatformView` works around this with a one-shot `OnGlobalLayoutListener` that calls the (deprecated but still functional) 5-arg `updateAppWidgetSize` once Flutter's `AndroidView` has a real layout size. `AppWidgetHost.startListening()`/`stopListening()` are wired to `MainActivity.onStart`/`onStop`.

**Weather tile pitfalls (if touching this code):** `LocationAccuracy.low` uses the network/fused provider, which doesn't respond to `adb emu geo fix` on an emulator — use `.high` with a time limit. The `geocoding` package's native reverse-geocode call blocked the Android main thread indefinitely on the test emulator (no Play Services geocoder backend) and caused an ANR; it was replaced with a timeout-bounded HTTP call instead.

### Phase 4 — Mind Space (screen-time insights)
Needs `PACKAGE_USAGE_STATS` permission and accumulated usage data, so it follows the other panels. Tasks, in build order (each depends on the ones above it):

1. ⬜ **Usage-stats permission + data source** — `PACKAGE_USAGE_STATS` is a special permission granted only via `Settings.ACTION_USAGE_ACCESS_SETTINGS` (no runtime dialog), so this needs a Settings-redirect bridge like `launcher_role_service.dart`'s pattern; wrap Android's `UsageStatsManager`/`UsageEvents` behind `lib/services/usage_stats_service.dart`, querying per-app foreground time and launch events for a given window (today, last 24h)
2. ⬜ **Mind Space panel shell** — replace the `lib/panels/mind_space_panel.dart` placeholder with the real scaffold (screen time total, pickups count) fed by task 1's service
3. ⬜ **Hourly usage bar chart** — 12 AM–now bar chart of foreground time per hour, built from task 1's `UsageEvents` stream
4. ⬜ **Per-app breakdown** — opens + time per app with a behavioral insight line, reusing `InstalledAppsService` for icons/names (same cross-reference pattern as the App Folder/From-Apps pickers)
5. ⬜ **Habits & Reflexes** — derived behavioral patterns (e.g. what's opened right after unlock) computed from task 1's raw event sequence; depends on task 4's per-app data being in place first
6. ⬜ **Quick actions: Pause, Timer, Focus Mode** — entry points on the Mind Space panel; the underlying enforcement (a `FocusModeService`) is shared with Phase 5's Settings screen, so build the service here first and just surface it in Settings later

### Phase 5 — Settings
Aggregates toggles/controls introduced in earlier phases into one screen; do last since it has no independent surface of its own. Tasks, in build order (each depends on the ones above it):

1. ⬜ **Settings screen shell** — new screen (e.g. `lib/settings/settings_screen.dart`) reachable via long-press on Home; wire the long-press gesture into `lib/panels/home_panel.dart`
2. ⬜ **Settings search** — search across settings/modes/tools, adapting `lib/search/app_search_bar.dart`'s pattern to a static list of settings entries instead of installed apps
3. ⬜ **Appearance group** — Theme (Light/Dark) toggle surfaced here, reusing `AppSettings.isDark`/`SegmentedToggle` from onboarding rather than rebuilding it; same for layout mode and wallpaper if grouped under Appearance
4. ⬜ **Launcher Settings group** — layout mode (Classic/Minimal), wallpaper picker, and a way to re-run onboarding, reusing `lib/onboarding/wallpaper_picker.dart` and `AppSettings.layoutMode`
5. ⬜ **System Settings group** — permission entries (usage access from Phase 4 task 1, location for the Weather tile) and a "change default launcher" shortcut reusing `launcher_role_service.dart`
6. ⬜ **Mind Space quick actions surfaced here too** — Pause, Timer, Focus Mode, wired to the same `FocusModeService` built in Phase 4 task 6
7. ⬜ **Restart Launcher action** — process-restart utility; last since it's trivial and has no dependents

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
- `lib/my_space/` — My Space-specific widgets (Add New Tile sheet, built-in tile catalog, tile chrome); `lib/my_space/tiles/` holds the per-kind tile bodies (Notes, Todo, Weather, App Folder, From-Apps)
- `lib/search/` — shared app search/filter logic and UI, used by App Drawer, Spotlight Search, and the App Folder/From-Apps picker sheets
- `lib/state/` — `AppSettings` (theme/layout/wallpaper), exposed via `AppSettingsScope` (`InheritedNotifier`)
- `lib/services/` — platform-channel and persistence services (installed apps, onboarding flag, launcher role, My Space tiles, weather, app widgets)
- `lib/models/` — plain data models (`HomeLayoutMode`, `MySpaceTile`, `TileKind`)
- `lib/widgets/` — small shared widgets (`SegmentedToggle`)
- `android/app/src/main/kotlin/.../MainActivity.kt` — native `RoleManager.ROLE_HOME` MethodChannel bridge (`yinyang.launcher/role`); wires up `AppWidgetHostBridge`'s lifecycle and activity-result routing
- `android/app/src/main/kotlin/.../AppWidgetHostBridge.kt` — native `AppWidgetHost`/`AppWidgetManager` bridge (`yinyang.launcher/appwidget` channel + `yinyang.launcher/appwidget_view` platform view) for the From-Apps tile
- `test/` — widget tests; app startup is async (SharedPreferences), so tests use `SharedPreferences.setMockInitialValues` and `pumpAndSettle`
- `android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/` — platform runner projects generated by Flutter tooling; rarely need manual edits
- Dart SDK constraint: `^3.13.3` (see `pubspec.yaml`)
- `graphify-out/` — generated knowledge-graph artifacts from `/graphify`; not app code, gitignored
