# Yin Yang Launcher

An Android home-screen replacement app (yin/yang branding = light/dark duality) combining a calm home screen, a customizable widget dashboard, and screen-time/wellbeing insights.

Built with Flutter, targeting Android only.

## Status

- **Phase 1 — Launcher core:** done. Registers as a launcher (`ROLE_HOME`), 5-panel swipe navigation (Search / My Space / Home / Mind Space / App Drawer), home screen chrome, Classic/Minimal layout modes, installed-app data source, App Drawer with fast-scroll index and search, Spotlight Search.
- **Phase 2 — Onboarding:** done. First-run flow with a live phone-mockup preview, theme/layout/wallpaper steps, "Set as my launcher" flow, and an interactive tutorial.
- **Phase 3 — My Space (widget dashboard):** in progress. Tile dashboard shell, Add New Tile sheet, Notes tile, Todo tile, and Weather tile are done. App Folder and From-Apps (native AppWidget) tiles remain.
- **Phase 4 — Mind Space (screen-time insights):** not started.
- **Phase 5 — Settings:** not started.

See [`CLAUDE.md`](CLAUDE.md) for the full task breakdown and architecture notes.

## Getting started

```bash
flutter pub get
flutter run -d <device_id>   # flutter devices lists available targets
```

Only tested against an Android emulator/device — the app registers Android's `HOME`/`LAUNCHER` intent filters and won't behave meaningfully on other platforms.

### Common commands

| Task | Command |
|---|---|
| Install deps | `flutter pub get` |
| Run app | `flutter run -d <device_id>` |
| Analyze/lint | `flutter analyze` |
| Run all tests | `flutter test` |
| Run a single test file | `flutter test test/widget_test.dart` |
| Build release APK | `flutter build apk` |

## Project structure

- `lib/main.dart` — entry point; gates between onboarding and the launcher shell on a persisted flag
- `lib/shell/` — the 5-panel swipe navigation shell
- `lib/panels/` — the 5 panel screens (Home, My Space, Mind Space, App Drawer, Spotlight Search)
- `lib/onboarding/` — first-run flow
- `lib/my_space/` — My Space dashboard widgets and per-kind tile bodies
- `lib/search/` — shared app search/filter logic, used by App Drawer and Spotlight Search
- `lib/state/` — app-wide settings (theme/layout/wallpaper)
- `lib/services/` — platform-channel and persistence services (installed apps, onboarding flag, launcher role, My Space tiles, weather)
- `lib/models/` — plain data models
- `android/app/src/main/kotlin/.../MainActivity.kt` — native `RoleManager.ROLE_HOME` bridge
