# Student Launcher — Design Language

Derived from the onboarding, My Space, Mind Space, App Drawer, and Settings mockups in `screenshots/`. This is a description of the *intended* visual system, not an audit of current code.

## 1. Core Philosophy

The brand is the yin/yang duality itself: **light and dark are two complete, equally-designed states**, not a default theme with a dark mode bolted on. Every screen exists in both, and switching between them is presented as a first-class choice ("Start with light or dark") rather than a settings toggle buried later. The visual language beyond that duality is deliberately quiet — the app gets out of the way of the wallpaper, the clock, and the user's own content (notes, todos, apps). Nothing competes with legibility. There is no brand color; contrast and typography do all the work.

Secondary theme: **calm / mindful minimalism**. Mind Space's tagline ("Awareness, pause, and presence") and the wireframe-like, low-chroma aesthetic used everywhere reinforce a wellbeing product rather than a flashy launcher.

## 2. Color System

### 2.1 Two poles, not a palette
- **Dark mode**: near-black background (`#0D0E12`–ish charcoal, not pure `#000`), pure white text, white-stroked outlines.
- **Light mode**: near-white / very pale lavender-gray background, near-black text, black-stroked outlines.
- There is no accent/brand hue used for interactive state. Selection, emphasis, and CTAs are communicated by **inverting** the foreground/background relationship (a black pill on a white screen, a white pill on a black screen), not by introducing a new color.

### 2.2 Wallpaper swatches as the only color injection
The wallpaper picker is the one place saturated color appears: soft pastel tints — powder blue-gray, lilac/lavender, blush lavender-white, warm gray. All are low-saturation, high-lightness "dusk" tones consistent with the yin/yang calm mood. None are primary/saturated colors (no bright blue, red, green). The selected wallpaper's tint then propagates into the whole Customize screen background in light theme, confirming wallpaper is treated as a global mood-setter, not decoration confined to one preview.

### 2.3 Grayscale hierarchy
Within a single theme, hierarchy is built from a tight grayscale ramp only:
- Primary text: near-full contrast (white on dark, near-black on light)
- Secondary/label text (e.g. "WEATHER", "MY SPACE", "A SAMPLE DAY"): mid-gray, small, letter-spaced
- Tertiary/disabled/placeholder (e.g. faded Music tile preview, faded status bar time before permission): low-opacity gray, achieved via opacity reduction rather than a distinct lighter color token

### 2.4 Status/semantic color is nearly absent
Even the usage-stats bar chart, todo checkboxes, and habit callouts use grayscale/outline only — no red-for-warning, no green-for-done. The one checked todo item is shown via a filled gray checkbox + strikethrough text, not a color change. This is a strong, consistent constraint: **the app does not use color to encode meaning**, only shape/weight/opacity.

## 3. Typography

- Single sans-serif family throughout (system default, rounded/geometric — reads like SF Pro / Inter-class), no serif or display font anywhere.
- **Scale is the primary hierarchy tool**, more than weight:
  - Hero numerals (home clock "07:21", Mind Space "2h 14m") are the largest text on any screen — oversized, tabular, center-anchored.
  - Section headers ("WELCOME TO", "MY SPACE", "WEATHER", "TODO", "HOME SCREEN", "WALLPAPER") are set in **uppercase with wide letter-spacing**, small size, gray — this is the recurring "eyebrow label" pattern used identically across onboarding, My Space, and Mind Space.
  - Page titles ("Your Home", "A space for what matters.", "Where your screen time goes.") are large, bold/semi-bold, sentence case, often wrapping two lines with generous line-height.
  - Body/support copy ("Keep the information you care about within a glance.") is regular weight, medium-gray, comfortably sized — never small enough to strain.
- Numerals are treated specially: the clock and screen-time stats use a larger, sometimes lighter-weight numeral distinct from surrounding labels, giving a "watch face" feel.
- No italics observed. Bold is reserved for headlines, CTA button labels, and app names in the drawer — not overused.

## 4. Shape Language

- **Superellipse / squircle-leaning rounded rectangles everywhere** — tiles, buttons, toggle pills, the phone-mockup frame, app-drawer avatars (circular), tutorial panel cards. Corner radius is large and consistent (~16–24px equivalent), never sharp corners, never fully pill-shaped except for true toggles/search bars.
- **Outline-first, fill-second**: most containers (tiles, tutorial panels, wallpaper swatches, settings rows) are 1–1.5px hairline-stroked with a transparent/matching-background interior, not drop-shadowed cards. Depth comes from stroke + rounding, not elevation/shadow. This keeps the UI feeling flat, calm, and "wireframe honest" rather than skeuomorphic.
- **Selected state = solid fill + color inversion**, not a colored border or checkmark badge. E.g. the Light/Dark segmented toggle fills the active half solid black (or white); the tutorial's active nav icon is a solid black tile; the selected wallpaper swatch gets a heavier black outline. Consistent rule: *outline = available/inactive, solid fill = selected/active/primary action*.
- Primary CTA buttons ("Continue", "Set as my launcher", "Let's Go", "Next", "Add Your First Tile") are always full-width, solid black (dark-filled) pill/rounded-rect buttons with white bold label — identical treatment in both themes (they stay dark-on-light *and* dark mode uses the same black-fill/white-text button, i.e. the primary CTA does not invert with theme the way other elements do — it's a fixed "ink" affordance).

## 5. Layout & Spacing

- **Generous vertical whitespace and single-column stacking.** Screens read top-to-bottom: eyebrow label → headline → supporting copy → primary content card(s) → CTA pinned at the bottom edge.
- **Bottom-anchored primary action.** Every onboarding step, and My Space's empty state, place the one primary button at the very bottom of the screen, full width, as the natural thumb-reach terminus.
- **Center-anchored preview object.** The phone mockup, the tutorial's cross-shaped 5-panel diagram — key illustrative content is horizontally centered with equal margins, never left-aligned like the text above it.
- **Card padding is roomy** — text inside tiles/settings rows has generous internal padding, avoiding a cramped, data-dense look even on data-heavy screens (Mind Space stats, App Drawer list).
- **Grouped settings rows** use a single outlined container with internal hairline dividers between rows (Settings screen "Toggles"/"Settings" groups) rather than separate cards per row — an iOS-Settings-like grouping convention.

## 6. Navigation Model & Its Visual Expression

- Five-panel cross layout (Search / My Space / Home / Mind Space / App Drawer) is *taught visually* in onboarding as a literal 3x3-ish cross grid of five rounded rectangles with the active one solid-filled — this same cross diagram doubles as both the tutorial illustration and (conceptually) the mental map for swipe gestures (swipe right → My Space, left → Mind Space, up → App Drawer, down → Search, matching physical direction to the diagram's spatial position). This is a strong, reused motif: **the nav icon literally is the onboarding illustration**, not a separate abstraction.
- Gesture affordance is taught via small outlined pill labels in all-caps ("LONG PRESS", "SWIPE RIGHT", "SWIPE LEFT", "SWIPE UP", "SWIPE DOWN") — same eyebrow-label typographic treatment as section headers, reused as an interaction-hint component.
- Progress through onboarding is shown with a minimal dot/dash stepper (small gray dots, active step as an elongated dark dash) — understated, not a numbered stepper or progress bar.

## 7. Iconography

- Line icons only (sun, moon, search magnifier, phone/message/browser/camera glyphs, brain, grid, dots, weather glyphs, gear, palette, yin-yang glyph, meditation figure, timer, crosshair/focus). Consistent stroke weight, no filled/glyph-style icons mixed in, no duotone or multi-color icons.
- Icons are small and paired with a text label almost everywhere — rarely stand alone as the only affordance.
- The yin-yang symbol itself is reserved for brand moments only (app icon, the native "set as default launcher" system dialog, Launcher Settings row icon) — not used decoratively elsewhere, keeping it special rather than diluted.

## 8. Component Patterns (reusable across screens)

| Component | Visual rule |
|---|---|
| Segmented toggle (Light/Dark, Classic/Minimal) | Single outlined pill container, two equal halves, active half solid-filled + inverted text/icon color |
| Tile card (Weather/Todo/Notes/App Folder) | Rounded-rect outline container, uppercase gray eyebrow header row with a leading small icon, content below with roomy padding |
| Empty/disabled state | Same component rendered at reduced opacity in place (faded "Music" tile preview) rather than hidden — shows users what's coming |
| Primary CTA | Full-width, bottom-pinned, solid black/dark fill, bold white label, rounded corners, theme-invariant |
| List row w/ chevron (Settings) | Icon + title + optional subtitle left-aligned, trailing `>` chevron, grouped in a bordered container with dividers |
| Search bar | Full-width rounded-pill outline, leading magnifier icon, placeholder text in gray, trailing icon(s) for filter/clear when active |
| Fast-scroll index (App Drawer) | Vertical single-letter rail pinned to the right edge, gray, minimal width, floating circular keyboard-toggle FAB above it |
| Stat trio (Mind Space) | Three large numerals side-by-side with small uppercase labels beneath, thin vertical hairline dividers between them — no icons, numbers do the talking |

## 9. Tone of Voice (supports the visual system)

Copy is short, declarative, lowercase-sentence style, almost aphoristic: "Everything begins here.", "Your tools and daily essentials.", "A space for what matters.", "Open apps with intention.", "Awareness, pause, and presence." This restrained, calm copywriting mirrors the restrained visual palette — both avoid exclamation, urgency, or marketing gloss.

## 10. What to Preserve When Building New Screens (Phase 4/5)

1. No new colors — stay within the grayscale + wallpaper-pastel system.
2. Every stat/number gets to be the visual hero of its card; labels stay small, gray, uppercase, letter-spaced.
3. Selected/active state = solid fill + inversion, never a colored highlight.
4. Primary action stays a bottom-pinned, full-width, solid-black CTA regardless of theme.
5. Settings rows group into single outlined containers with dividers (already mocked in the Phase 5 screenshot) — icon + label + chevron, no toggles/switches shown inline (Theme/Focus Mode use the chevron-to-detail pattern, not inline switches).
6. Keep hairline outlines + large radius as the only "elevation" — no drop shadows, no gradients except the extremely subtle wallpaper gradient already used behind Home/My Space content.
