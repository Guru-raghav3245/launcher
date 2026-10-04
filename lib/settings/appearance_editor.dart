import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../models/home_layout_mode.dart';
import '../models/tile_kind.dart';
import '../models/wallpaper.dart';
import '../my_space/built_in_tile_specs.dart';
import '../onboarding/phone_mockup.dart';
import '../panels/home_panel.dart';
import '../search/app_result_row.dart';
import '../services/app_customizations_service.dart';
import '../state/app_settings.dart';
import '../state/app_settings_scope.dart';

/// Opens the full-screen Appearance editor (after the original's).
Future<void> showAppearanceEditor(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AppearanceEditor()));

/// Everything the editor can change, so Cancel can put it back and Save
/// knows whether anything changed.
typedef _Look = (
  Wallpaper,
  Wallpaper,
  HomeLayoutMode,
  bool,
  bool,
  ClockStyle,
  ClockPosition?,
  LauncherFont,
  TextSize,
  IconTint,
  CardStyle,
);

_Look _lookOf(AppSettings s) => (
  s.lightWallpaper,
  s.darkWallpaper,
  s.layoutMode,
  s.showStatusBar,
  s.showSearchBar,
  s.clockStyle,
  s.clockPosition,
  s.font,
  s.textSize,
  s.iconTint,
  s.cardStyle,
);

void _restore(AppSettings s, _Look look) {
  final (light, dark, layout, statusBar, searchBar, clock, position, font, size, tint, cards) = look;
  s
    ..setWallpaper(light, forDark: false)
    ..setWallpaper(dark, forDark: true)
    ..setLayoutMode(layout)
    ..setShowStatusBar(statusBar)
    ..setShowSearchBar(searchBar)
    ..setClockStyle(clock)
    ..setClockPosition(position)
    ..setFont(font)
    ..setTextSize(size)
    ..setIconTint(tint)
    ..setCardStyle(cards);
}

/// The bottom tabs; each has sections chosen with the chips above them.
enum _Tab {
  wallpaper('Wallpaper', Icons.image_outlined, 'Collection', ['Classic', 'Gradient']),
  home('Home', Icons.call_to_action_outlined, 'Section', ['Style', 'Status bar', 'Search bar']),
  clock('Clock', Icons.schedule, 'Section', ['Style', 'Position']),
  fonts('Fonts', Icons.text_fields, 'Section', ['Family', 'Size']),
  icons('Icons', Icons.grid_view, 'Source', ['Tints']),
  background('Background', Icons.filter_none, 'Section', ['Card style']);

  const _Tab(this.label, this.icon, this.sectionLabel, this.sections);
  final String label;
  final IconData icon;
  final String sectionLabel;
  final List<String> sections;
}

/// One card in the carousel: a visual and an optional caption.
typedef _Option = ({Widget visual, String? label, bool selected, VoidCallback onTap, Gradient? fill});

/// Cancel / Appearance / Save over a live phone preview, with a panel of
/// option cards for the chosen tab. Changes apply as they're picked (so the
/// preview is the real thing); leaving any way but Save puts them back.
class AppearanceEditor extends StatefulWidget {
  const AppearanceEditor({super.key});

  @override
  State<AppearanceEditor> createState() => _AppearanceEditorState();
}

class _AppearanceEditorState extends State<AppearanceEditor> {
  late final AppSettings _settings;
  late final _Look _initial;
  var _saved = false;
  _Tab? _tab;
  var _section = 0;
  late bool _forDark;
  final _apps = loadCustomizedApps();

  @override
  void initState() {
    super.initState();
    _settings = context.findAncestorWidgetOfExactType<AppSettingsScope>()!.notifier!;
    _initial = _lookOf(_settings);
    _forDark = _settings.isDark;
  }

  @override
  void dispose() {
    // Cancel, back, and the Home key all land here. After the frame, since
    // restoring notifies the whole app.
    if (!_saved) Future.microtask(() => _restore(_settings, _initial));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final changed = _lookOf(settings) != _initial;
    final tab = _tab;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 58,
              child: Row(
                children: [
                  _TopButton(label: 'Cancel', onTap: () => Navigator.of(context).pop()),
                  const Expanded(
                    child: Text(
                      'Appearance',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  _TopButton(
                    label: 'Save',
                    onTap: changed
                        ? () {
                            _saved = true;
                            Navigator.of(context).pop();
                          }
                        : null,
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Padding(
                  padding: const EdgeInsets.only(bottom: 23),
                  child: PhoneMockup(
                    width: (constraints.maxHeight - 23) * 390 / 844,
                    frameColor: colors.onSurfaceVariant,
                    child: _Preview(tab: tab, settings: settings, apps: _apps),
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.surfaceContainerHighest)),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  if (tab != null) ...[
                    _header(tab, settings, colors),
                    SizedBox(height: 118, child: _carousel(_options(tab, settings), _cardWidth(tab))),
                    const SizedBox(height: 8),
                    Divider(height: 1, color: colors.outlineVariant),
                    _sectionRow(tab, colors),
                    Divider(height: 1, color: colors.outlineVariant),
                  ],
                  _tabBar(colors),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(_Tab tab, AppSettings settings, ColorScheme colors) {
    final path = [tab.label, if (tab == _Tab.wallpaper) _forDark ? 'Dark' : 'Light', tab.sections[_section]];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 16, 0),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: Text(path.join(' › '), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            // Which theme's wallpaper is being picked.
            if (tab == _Tab.wallpaper)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.outline),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (dark, label) in [(false, 'Light'), (true, 'Dark')])
                      _Pill(label: label, selected: _forDark == dark, onTap: () => setState(() => _forDark = dark)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionRow(_Tab tab, ColorScheme colors) {
    return SizedBox(
      height: 45,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 19),
        children: [
          Center(
            child: Text(tab.sectionLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          for (final (i, section) in tab.sections.indexed)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Center(
                child: _Pill(
                  label: section,
                  selected: i == _section,
                  outlined: true,
                  onTap: () => setState(() => _section = i),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabBar(ColorScheme colors) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 84,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final tab in _Tab.values)
              InkWell(
                onTap: () => setState(() {
                  _tab = tab;
                  _section = 0;
                }),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 72),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      const SizedBox(height: 9),
                      SizedBox(
                        height: 20,
                        child: tab == _Tab.fonts
                            ? Text(
                                'A',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: tab == _tab ? colors.onSurface : colors.onSurfaceVariant,
                                ),
                              )
                            : Icon(tab.icon, size: 17, color: tab == _tab ? colors.onSurface : colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: tab == _tab ? FontWeight.w600 : FontWeight.w400,
                          color: tab == _tab ? colors.onSurface : colors.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Container(width: 18, height: 2, color: tab == _tab ? colors.onSurface : Colors.transparent),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Fixed widths scroll sideways; null shares the row evenly.
  double? _cardWidth(_Tab tab) => switch ((tab, _section)) {
    (_Tab.wallpaper, _) => 60,
    (_Tab.clock, 0) => 126,
    (_Tab.fonts, 0) => 99,
    (_Tab.icons, _) => 81,
    _ => null,
  };

  Widget _carousel(List<_Option> options, double? width) {
    final colors = Theme.of(context).colorScheme;
    Widget card(_Option o, {required double height}) => GestureDetector(
      onTap: o.onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: o.selected ? colors.surface : colors.surfaceContainerHigh,
          gradient: o.fill,
          // Swatches keep a hairline so white shows on a white ground.
          border: o.selected
              ? Border.all(color: colors.onSurface, width: 1.5)
              : o.fill != null
              ? Border.all(color: colors.outlineVariant)
              : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            o.visual,
            if (o.label != null) ...[
              const SizedBox(height: 8),
              Text(o.label!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      ),
    );
    final height = switch ((_tab, _section)) {
      (_Tab.wallpaper, _) => 111.0,
      (_Tab.fonts, 0) => 78.0,
      _ => 97.0,
    };
    if (width == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 19),
        child: Row(
          children: [
            for (final (i, o) in options.indexed) ...[
              if (i > 0) const SizedBox(width: 17),
              Expanded(child: card(o, height: height)),
            ],
          ],
        ),
      );
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 19),
      itemCount: options.length,
      separatorBuilder: (_, _) => SizedBox(width: _tab == _Tab.wallpaper ? 10 : 17),
      itemBuilder: (context, i) => Center(
        child: SizedBox(
          width: width,
          child: card(options[i], height: height),
        ),
      ),
    );
  }

  List<_Option> _options(_Tab tab, AppSettings s) {
    final colors = Theme.of(context).colorScheme;
    _Option iconOption(IconData icon, String label, bool selected, VoidCallback onTap) => (
      visual: Icon(icon, size: 24, color: colors.onSurface),
      label: label,
      selected: selected,
      onTap: onTap,
      fill: null,
    );
    switch ((tab, _section)) {
      case (_Tab.wallpaper, _):
        final current = _forDark ? s.darkWallpaper : s.lightWallpaper;
        final list = _section == 0 ? (_forDark ? classicDark : classicLight) : gradients;
        return [
          for (final w in list)
            (
              visual: w == current
                  ? Icon(Icons.check_circle, size: 20, color: w.isDark ? Colors.white : Colors.black)
                  : const SizedBox.shrink(),
              label: null,
              selected: w == current,
              onTap: () => s.setWallpaper(w, forDark: _forDark),
              fill: w.gradient,
            ),
        ];
      case (_Tab.home, 0):
        return [
          iconOption(
            Icons.dashboard_outlined,
            'Classic',
            s.layoutMode == HomeLayoutMode.classic,
            () => s.setLayoutMode(HomeLayoutMode.classic),
          ),
          iconOption(
            Icons.short_text,
            'Minimal',
            s.layoutMode == HomeLayoutMode.minimal,
            () => s.setLayoutMode(HomeLayoutMode.minimal),
          ),
        ];
      case (_Tab.home, 1):
        return [
          iconOption(Icons.smartphone, 'Shown', s.showStatusBar, () => s.setShowStatusBar(true)),
          iconOption(Icons.stay_current_portrait, 'Hidden', !s.showStatusBar, () => s.setShowStatusBar(false)),
        ];
      case (_Tab.home, _):
        return [
          iconOption(Icons.search, 'Shown', s.showSearchBar, () => s.setShowSearchBar(true)),
          iconOption(Icons.search_off, 'Hidden', !s.showSearchBar, () => s.setShowSearchBar(false)),
        ];
      case (_Tab.clock, 0):
        final now = DateTime.now();
        final time = formatClockTime(now, use24: MediaQuery.alwaysUse24HourFormatOf(context));
        final date = formatClockDate(now);
        const roboto = TextStyle(fontFamily: 'Roboto');
        return [
          for (final (style, visual) in [
            (
              ClockStyle.standard,
              Column(
                children: [
                  Text(date, style: roboto.copyWith(fontSize: 8)),
                  Text(time, style: roboto.copyWith(fontSize: 22, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            (
              ClockStyle.large,
              Text(
                time.replaceFirst(':', '\n'),
                textAlign: TextAlign.center,
                style: roboto.copyWith(fontSize: 19, height: 1, fontWeight: FontWeight.w300),
              ),
            ),
            (ClockStyle.compact, Text('$time  ${date.substring(0, 3)}', style: roboto.copyWith(fontSize: 14))),
          ])
            (
              visual: visual,
              label: null,
              selected: s.clockStyle == style,
              onTap: () => s.setClockStyle(style),
              fill: null,
            ),
        ];
      case (_Tab.clock, _):
        final position = s.clockPositionFor(s.layoutMode);
        return [
          for (final (p, icon, label) in [
            (ClockPosition.top, Icons.vertical_align_top, 'Top'),
            (ClockPosition.center, Icons.vertical_align_center, 'Center'),
            (ClockPosition.bottom, Icons.vertical_align_bottom, 'Bottom'),
          ])
            iconOption(icon, label, position == p, () => s.setClockPosition(p)),
        ];
      case (_Tab.fonts, 0):
        return [
          for (final font in LauncherFont.values)
            (
              // Each option in its own face.
              visual: Text('Ab12', style: TextStyle(fontFamily: font.family ?? 'Roboto', fontSize: 26)),
              label: font.label,
              selected: s.font == font,
              onTap: () => s.setFont(font),
              fill: null,
            ),
        ];
      case (_Tab.fonts, _):
        return [
          for (final (size, label) in [(TextSize.small, 'S'), (TextSize.normal, 'M'), (TextSize.large, 'L')])
            (
              visual: Text(
                'Aa',
                textScaler: TextScaler.noScaling,
                style: TextStyle(fontSize: 22 * size.factor),
              ),
              label: label,
              selected: s.textSize == size,
              onTap: () => s.setTextSize(size),
              fill: null,
            ),
        ];
      case (_Tab.icons, _):
        return [
          for (final tint in IconTint.values)
            (
              visual: tint.matrix == null
                  ? const _Flower()
                  : ColorFiltered(colorFilter: ColorFilter.matrix(tint.matrix!), child: const _Flower()),
              label: tint.label,
              selected: s.iconTint == tint,
              onTap: () => s.setIconTint(tint),
              fill: null,
            ),
        ];
      case _: // background
        return [
          iconOption(
            Icons.crop_square,
            'Bordered',
            s.cardStyle == CardStyle.bordered,
            () => s.setCardStyle(CardStyle.bordered),
          ),
          iconOption(
            Icons.crop_free,
            'Borderless',
            s.cardStyle == CardStyle.borderless,
            () => s.setCardStyle(CardStyle.borderless),
          ),
        ];
    }
  }
}

/// Cancel and Save: plain text, faded while disabled.
class _TopButton extends StatelessWidget {
  const _TopButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        child: Text(
          label,
          style: TextStyle(fontSize: 15, color: onTap == null ? colors.onSurfaceVariant : colors.onSurface),
        ),
      ),
    );
  }
}

/// A rounded chip: filled in ink when [selected], else plain (or outlined).
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap, this.outlined = false});

  final String label;
  final bool selected;
  final bool outlined;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: outlined ? 25 : 26,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.onSurface : null,
          border: outlined && !selected ? Border.all(color: colors.outline) : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: outlined ? 13 : 12.5, color: selected ? colors.surface : colors.onSurface),
        ),
      ),
    );
  }
}

/// A many-coloured sample icon for the tint cards (the original's flower).
class _Flower extends StatelessWidget {
  const _Flower();

  static const _petals = [Colors.red, Colors.orange, Colors.green, Colors.teal, Colors.blue, Colors.purple];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        children: [
          for (final (i, color) in _petals.indexed)
            Align(
              alignment: Alignment(0.65 * _cos(i), 0.65 * _sin(i)),
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }

  // Six petals, 60° apart.
  static double _cos(int i) => const [1.0, 0.5, -0.5, -1.0, -0.5, 0.5][i];
  static double _sin(int i) => const [0.0, 0.866, 0.866, 0.0, -0.866, -0.866][i];
}

/// What the phone shows: Home for the Home-ish tabs, sample My Space tiles
/// for fonts and card style, the drawer for icons; plus a status bar while
/// it's shown.
class _Preview extends StatelessWidget {
  const _Preview({required this.tab, required this.settings, required this.apps});

  final _Tab? tab;
  final AppSettings settings;
  final Future<List<AppInfo>> apps;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final Widget body;
    final Color ink;
    switch (tab) {
      case _Tab.fonts || _Tab.background:
        ink = colors.onSurface;
        body = ColoredBox(
          color: colors.surface,
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final kind in [TileKind.weather, TileKind.todo]) ...[
                  builtInTileSpecs.firstWhere((s) => s.kind == kind).previewCard,
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        );
      case _Tab.icons:
        ink = colors.onSurface;
        body = ColoredBox(
          color: colors.surface,
          child: FutureBuilder(
            future: apps,
            builder: (context, snapshot) => SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(5, 16, 5, 0),
                children: [
                  for (final app in (snapshot.data ?? const <AppInfo>[]).take(12))
                    AppResultRow(app: app, onTap: () {}, inset: 11, height: 49, iconSize: 34, labelSize: 15),
                ],
              ),
            ),
          ),
        );
      default:
        ink = settings.wallpaper.isDark ? Colors.white : Colors.black;
        body = const HomePanel(preview: true);
    }
    if (!settings.showStatusBar) return body;
    final time = TimeOfDay.now().format(context);
    return Stack(
      children: [
        MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: const EdgeInsets.only(top: 28)),
          child: body,
        ),
        Positioned(
          top: 6,
          left: 22,
          right: 20,
          child: Row(
            children: [
              Text(
                time,
                style: TextStyle(fontSize: 12, color: ink, fontFamily: 'Roboto'),
              ),
              const Spacer(),
              Icon(Icons.signal_cellular_alt, size: 13, color: ink),
              const SizedBox(width: 4),
              Icon(Icons.battery_full, size: 13, color: ink),
            ],
          ),
        ),
      ],
    );
  }
}
