/// Sizes offered for drawer icons and labels; [none] hides them.
enum DrawerItemSize { none, small, medium, large }

/// List row heights.
enum DrawerRowHeight { compact, normal, roomy }

/// How the App Drawer lays out its apps (Phase 10 task 7). The defaults are
/// the original's drawer (Phase 11): a list, 34px icons, 15pt one-line
/// labels, 49px rows, A-Z section headers.
class DrawerLook {
  const DrawerLook({
    this.grid = false,
    this.columns = 4,
    this.iconSize = DrawerItemSize.medium,
    this.labelSize = DrawerItemSize.medium,
    this.twoLineLabels = false,
    this.rowHeight = DrawerRowHeight.normal,
    this.headers = true,
  });

  final bool grid;

  /// Grid only: 3-5.
  final int columns;
  final DrawerItemSize iconSize;
  final DrawerItemSize labelSize;
  final bool twoLineLabels;

  /// List only.
  final DrawerRowHeight rowHeight;
  final bool headers;

  static const minColumns = 3;
  static const maxColumns = 5;

  /// Icon edge in logical pixels (0 for none).
  double get iconPx => const {
    DrawerItemSize.none: 0.0,
    DrawerItemSize.small: 28.0,
    DrawerItemSize.medium: 34.0,
    DrawerItemSize.large: 44.0,
  }[iconSize]!;

  /// Label font size (0 for none).
  double get labelPx => const {
    DrawerItemSize.none: 0.0,
    DrawerItemSize.small: 13.0,
    DrawerItemSize.medium: 15.0,
    DrawerItemSize.large: 18.0,
  }[labelSize]!;

  int get labelLines => twoLineLabels ? 2 : 1;

  double get listRowPx =>
      const {DrawerRowHeight.compact: 42.0, DrawerRowHeight.normal: 49.0, DrawerRowHeight.roomy: 60.0}[rowHeight]!;

  DrawerLook copyWith({
    bool? grid,
    int? columns,
    DrawerItemSize? iconSize,
    DrawerItemSize? labelSize,
    bool? twoLineLabels,
    DrawerRowHeight? rowHeight,
    bool? headers,
  }) => DrawerLook(
    grid: grid ?? this.grid,
    columns: columns ?? this.columns,
    iconSize: iconSize ?? this.iconSize,
    labelSize: labelSize ?? this.labelSize,
    twoLineLabels: twoLineLabels ?? this.twoLineLabels,
    rowHeight: rowHeight ?? this.rowHeight,
    headers: headers ?? this.headers,
  );

  Map<String, Object> toJson() => {
    'grid': grid,
    'columns': columns,
    'iconSize': iconSize.name,
    'labelSize': labelSize.name,
    'twoLineLabels': twoLineLabels,
    'rowHeight': rowHeight.name,
    'headers': headers,
  };

  factory DrawerLook.fromJson(Map<String, dynamic> json) => DrawerLook(
    grid: json['grid'] as bool? ?? false,
    columns: ((json['columns'] as int?) ?? 4).clamp(minColumns, maxColumns),
    iconSize: DrawerItemSize.values.byName(json['iconSize'] as String? ?? 'medium'),
    labelSize: DrawerItemSize.values.byName(json['labelSize'] as String? ?? 'medium'),
    twoLineLabels: json['twoLineLabels'] as bool? ?? false,
    rowHeight: DrawerRowHeight.values.byName(json['rowHeight'] as String? ?? 'normal'),
    headers: json['headers'] as bool? ?? true,
  );

  @override
  bool operator ==(Object other) => other is DrawerLook && other.toJson().toString() == toJson().toString();

  @override
  int get hashCode => toJson().toString().hashCode;
}
