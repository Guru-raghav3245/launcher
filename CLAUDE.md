# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Phases 1-5 are complete (all tasks below), verified live on an Android emulator. Phase 6 (Focus Mode essential-apps allowlist) is in progress. The intended product is documented below from UI mockups in `screenshots/`.

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

### Phase 4 — Mind Space (screen-time insights) — done
Needs `PACKAGE_USAGE_STATS` permission and accumulated usage data, so it follows the other panels. Tasks, in build order (each depends on the ones above it):

1. ✅ **Usage-stats permission + data source** — `PACKAGE_USAGE_STATS` is a special permission with no runtime dialog, granted only via `Settings.ACTION_USAGE_ACCESS_SETTINGS`; `android/.../UsageStatsBridge.kt` exposes `hasAccess` (checked via `AppOpsManager`, not `checkSelfPermission`), `requestAccess` (opens the Settings redirect, fire-and-forget like `requestHomeRole`'s fallback branch), and `queryEvents(start, end)` (raw `foreground`/`background`/`unlocked` events from `UsageEvents`, filtered natively) via the `yinyang.launcher/usage` channel; `lib/services/usage_stats_service.dart` wraps it with a `UsageEvent`/`UsageEventType` model. Verified live: granted access via the emulator's Usage access settings screen and confirmed real event counts came back.
2. ✅ **Mind Space panel shell** — `lib/panels/mind_space_panel.dart` now shows today's total screen time and pickup count, computed from task 1's raw `UsageEvent` stream by pairing each package's foreground/background events (`computeMindSpaceTotals`, tested in `test/mind_space_totals_test.dart`)
3. ✅ **Hourly usage bar chart** — `lib/panels/mind_space_panel.dart`'s `_HourlyChart` renders a 12am-through-now bar per hour of foreground time, from `computeHourlyUsage` (splits any foreground/background interval that crosses an hour boundary so each hour only gets its portion; tested in `test/mind_space_totals_test.dart`); plain `Container`/`FractionallySizedBox` bars, no charting dependency
4. ✅ **Per-app breakdown** — `_PerAppBreakdown` in `lib/panels/mind_space_panel.dart`, sorted by time spent, each row showing opens count and an "avg per open" insight line; `computePerAppUsage` (tested) tallies per-package opens/foreground time from the same event stream, icons/names cross-referenced live via `InstalledAppsService` (same pattern as the App Folder/From-Apps pickers); panel body is now a `ListView` so this list can scroll past the fold
5. ✅ **Habits & Reflexes** — `computeHabits` in `lib/panels/mind_space_panel.dart` finds the app most often opened first after unlocking (each `unlocked` event opens a window closed by the next `foreground` event, tallied by package; tested), surfaced via `_HabitsSection` as "After unlocking, you open X first N% of the time". Verified live end-to-end: set a PIN lock on the emulator (`adb shell locksettings set-pin`), locked/unlocked it to fire a real `KEYGUARD_HIDDEN` event, and confirmed the panel showed "1 pickups" and "After unlocking, you open launcher first 100% of the time (1 of 1 unlocks)."
6. ✅ **Quick actions: Pause, Timer, Focus Mode** — `lib/services/focus_mode_service.dart` persists a single Focus Mode session (active + optional end time, auto-expiring; tested); `InstalledAppsService.launch` now consults it and refuses to launch while active (its one choke point — App Drawer, Spotlight Search, and the App Folder tile all route through it). `_QuickActions` in `mind_space_panel.dart` surfaces Pause/Timer/Focus Mode as three tiles (matching `screenshots/Screenshot 2026-09-18 at 7.26.41 PM.png`'s icons/labels) that collapse into a single "Focus Mode is on … Stop" row while a session is active; Timer opens a 15/30/60-minute picker sheet. Every launch was blocked while active until Phase 6 added the essential-apps allowlist. Verified live end-to-end on the emulator: tapped Pause, confirmed tapping Camera in the App Drawer did nothing (`topResumedActivity` stayed on the launcher, Camera's per-app time stayed 0m), then tapped Stop and confirmed the tile row returned.

### Phase 5 — Settings — done
Aggregates toggles/controls introduced in earlier phases into one screen; do last since it has no independent surface of its own. Tasks, in build order (each depends on the ones above it):

1. ✅ **Settings screen shell** — `lib/settings/settings_screen.dart`, a near-full-height modal bottom sheet (`showSettingsScreen`) opened by long-press on `HomePanel`; matches `screenshots/Screenshot 2026-09-18 at 7.26.41 PM.png`'s grouped outlined rows with hairline dividers. Only the "Settings" group (Appearance / Launcher Settings / System Settings rows, not yet tappable) exists so far — later tasks add search, Toggles, Mind Space quick actions, and Restart Launcher
2. ✅ **Settings search** — `SettingsScreen` is driven by a static `_entries` list (group/icon/title records); the query filters entries by title substring and the groups re-form from what's left, with a "No settings match" empty state. Reuses `AppSearchBar` with `showSortControl: false` (passes a no-op sort callback, since that widget still requires one). Later tasks add their rows to `_entries` so search covers them automatically. Verified live: typing "sys" left only System Settings, and the sheet stayed above the keyboard
3. ✅ **Appearance group** — the Appearance row opens a sub-sheet (`_showAppearance` in `settings_screen.dart`) with the onboarding Light/Dark `SegmentedToggle`, bound to `AppSettings.isDark`/`setDark`; `_entries` records now carry an optional `onTap` (null = destination not built yet). Layout mode and wallpaper live under Launcher Settings (task 4), not here. `SegmentedToggle` and `AppSearchBar` used hardcoded black ink, which was unreadable on dark sheets; both now pick ink from `Theme.of(context).brightness` (unchanged in light mode, inverted white-on-dark in dark mode). Verified live: Dark switched the whole app and persisted across a reinstall
4. ✅ **Launcher Settings group** — the Launcher Settings row opens a sub-sheet with the Classic/Minimal `SegmentedToggle` (`AppSettings.layoutMode`), the onboarding `WallpaperPicker` (labelled "shown in light theme" while dark, since Home ignores wallpaper in dark), and a "Re-run onboarding" row that closes the sheets and pushes `OnboardingFlow` as a full-screen route which pops itself on finish (the `onboarding_complete` flag is left set). Both sub-sheets share `_showSubSheet`, which is scroll-controlled + scrollable because the default 9/16-height cap overflowed on small screens. `WallpaperPicker`'s outline is now theme-aware too. Verified live: a wallpaper picked in Settings showed up in re-run onboarding, and "Let's Go" returned to Home
5. ✅ **System Settings group** — the System Settings row opens a sub-sheet (`_SystemSettingsRows`) with three status rows: Default launcher, Usage access (`UsageStatsService.hasAccess`/`requestAccess`), and Location (`Geolocator.checkPermission`; tapping requests the runtime dialog only while plain `denied`, otherwise opens the app's system settings page). Statuses re-read on `AppLifecycleListener.onResume`, since every one of these is changed on a system screen. `requestHomeRole` can't serve as a "change default launcher" button because it returns `true` silently once the role is held, so `MainActivity.kt`'s `yinyang.launcher/role` channel gained `isDefaultLauncher` (resolves the HOME intent, works on every API level) and `openHomeSettings` (`Settings.ACTION_HOME_SETTINGS`, the system picker that switches either way), exposed on `LauncherRoleService`. Verified live: statuses matched `cmd role get-role-holders` and the real permissions; the Default launcher row opened the system "Default home app" picker; granting location from the row's dialog updated it in place; revoking usage access via `appops` while backgrounded showed "Not allowed" on return. Testing pitfall: `pm revoke` of a runtime permission kills the app process, so use `appops` to test the resume path
6. ✅ **Mind Space quick actions surfaced here too** — Mind Space's private `_QuickActions` was lifted into a self-contained public `FocusQuickActions` widget (still in `mind_space_panel.dart`) that owns its `FocusModeService` status, timer picker, and resume refresh; the panel and the Settings sheet's new "Mind Space" section both just render it. `FocusModeService.changes` (a static `ValueNotifier<int>` bumped on every `start`/`stop`) keeps every on-screen copy in sync. The section isn't a row list, so Settings search keeps it visible via `_mindSpaceTerms` (mind space / pause / timer / focus mode). Verified live: Pause in Settings showed "Focus Mode is on" in the Mind Space panel, and Stop there restored the tiles in Settings
7. ✅ **Restart Launcher action** — muted footer button at the bottom of the Settings sheet (matched by search as "restart launcher"), calling a one-method `yinyang.launcher/app` channel in `MainActivity.kt`: `restart` starts `Intent.makeRestartActivityTask(componentName)` then `Runtime.getRuntime().exit(0)`, so all Dart and native state starts over. Verified live: the launcher's PID changed (30037 → 30163) and it came straight back to Home

### Phase 6 — Focus Mode essential-apps allowlist — in progress
Focus Mode used to block every launch. This lets the user pick apps that stay launchable during a session. Tasks, in build order (each depends on the ones above it):

1. ✅ **Persisted allowlist in `FocusModeService`** — store essential package names as a `shared_preferences` string list next to the existing session keys; add `essentials()` and `setEssential(packageName, bool)`; `isBlocked` becomes `active && !essentials.contains(packageName)`, so all three launch call sites get it for free through `InstalledAppsService.launch`. Starts empty. Remove the `ponytail:` comment. Extend `test/focus_mode_service_test.dart`: an essential app isn't blocked during a session, a non-essential one is, and removing an essential blocks it again
2. ⬜ **"Essential apps" picker in Settings** — a new `_entries` row (so Settings search finds it) opening a tall sheet modeled on the App Folder tile's `_AppPickerSheet`: `AppSearchBar` + `filterAndSortApps` over `InstalledAppsService.loadApps()`, each `AppResultRow` with a checkbox showing whether it's essential, toggling via `setEssential`. Needs a small optional `trailing` parameter on `AppResultRow`, which doesn't support one yet. Essentials sorted to the top so the current picks are visible without scrolling
3. ⬜ **Blocked-launch feedback** — `launch` already returns `false` when blocked, but every caller ignores it, so a blocked tap does nothing. Add one helper that wraps `launch` and shows a short message ("Focus Mode is on · {app} isn't an essential app") when it returns `false`, and route the App Drawer, Spotlight Search, and App Folder tile through it. Check how each panel can show the message first: the panels aren't `Scaffold`s, so a `SnackBar` needs a `ScaffoldMessenger` ancestor (MaterialApp provides one) and must stay visible over the `PageView`
4. ⬜ **Verify live** — on the emulator, mark Clock essential, start Pause, confirm Clock opens from the App Drawer, Spotlight Search, and an App Folder tile, while Camera is refused with the message (check `topResumedActivity` via `dumpsys activity activities`), then Stop

**Known limit, not in scope:** Focus Mode can only gate launches this launcher makes. Native From-Apps widget taps (their PendingIntents fire inside `AppWidgetHostView`), notifications, and the recents screen all bypass it. Blocking those would need an `AccessibilityService` or similar app-wide enforcement, which is a much bigger permission ask.

## Commands

- Run app: `flutter run` (pick a device with `-d <device_id>`; `flutter devices` lists available targets)
- Install deps: `flutter pub get`
- Analyze/lint: `flutter analyze` (rules from `analysis_options.yaml`, which includes `package:flutter_lints/flutter.yaml`)
- Run all tests: `flutter test`
- Run a single test file: `flutter test test/widget_test.dart`
- Build release: `flutter build <apk|ios|macos|web|linux|windows>`

## Git commits

Do not add a `Co-Authored-By: Claude ...` (or similar AI-attribution) trailer to commit messages in this repo. The user does not want Claude showing as a co-author on GitHub.

## Structure

- `lib/main.dart` — entry point; gates between `OnboardingFlow` and `LauncherShell` on the persisted onboarding flag
- `lib/shell/` — the 5-panel swipe navigation shell
- `lib/panels/` — the 5 panel screens (Home, My Space, Mind Space, App Drawer, Spotlight Search)
- `lib/onboarding/` — first-run flow (steps, phone mockup, wallpaper/segmented-toggle pickers)
- `lib/my_space/` — My Space-specific widgets (Add New Tile sheet, built-in tile catalog, tile chrome); `lib/my_space/tiles/` holds the per-kind tile bodies (Notes, Todo, Weather, App Folder, From-Apps)
- `lib/settings/` — Settings sheet opened by long-press on Home (Phase 5)
- `lib/search/` — shared app search/filter logic and UI, used by App Drawer, Spotlight Search, and the App Folder/From-Apps picker sheets
- `lib/state/` — `AppSettings` (theme/layout/wallpaper), exposed via `AppSettingsScope` (`InheritedNotifier`)
- `lib/services/` — platform-channel and persistence services (installed apps, onboarding flag, launcher role, My Space tiles, weather, app widgets, usage stats, Focus Mode); `installed_apps_service.dart`'s `launch` consults `focus_mode_service.dart` before opening an app — the one choke point all launch call sites (App Drawer, Spotlight Search, App Folder tile) route through
- `lib/models/` — plain data models (`HomeLayoutMode`, `MySpaceTile`, `TileKind`)
- `lib/widgets/` — small shared widgets (`SegmentedToggle`)
- `android/app/src/main/kotlin/.../MainActivity.kt` — native `RoleManager.ROLE_HOME` MethodChannel bridge (`yinyang.launcher/role`: `requestHomeRole`, `isDefaultLauncher`, `openHomeSettings`) plus the `yinyang.launcher/app` channel's `restart`; wires up `AppWidgetHostBridge`'s lifecycle/activity-result routing and attaches `UsageStatsBridge`
- `android/app/src/main/kotlin/.../AppWidgetHostBridge.kt` — native `AppWidgetHost`/`AppWidgetManager` bridge (`yinyang.launcher/appwidget` channel + `yinyang.launcher/appwidget_view` platform view) for the From-Apps tile
- `android/app/src/main/kotlin/.../UsageStatsBridge.kt` — native `UsageStatsManager`/`AppOpsManager` bridge (`yinyang.launcher/usage` channel) for Mind Space
- `test/` — widget tests; app startup is async (SharedPreferences), so tests use `SharedPreferences.setMockInitialValues` and `pumpAndSettle`
- `android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/` — platform runner projects generated by Flutter tooling; rarely need manual edits
- Dart SDK constraint: `^3.13.3` (see `pubspec.yaml`)
- `graphify-out/` — generated knowledge-graph artifacts from `/graphify`; not app code, gitignored
