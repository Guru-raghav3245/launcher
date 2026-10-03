import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../models/drawer_look.dart';
import 'app_result_row.dart';

// The original's section header: a bold letter over a short rule, with
// generous space above (sizes measured from it, Phase 11).
const _headerHeight = 113.0;

/// The index always lists every letter, like the original; ◷ only appears
/// when the Recent section does.
const _indexLetters = [
  '★',
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
  '#',
];

/// The key of the drawer's recent-apps section (shown as ◷ in the index).
const recentSectionKey = 'Recent';

/// A titled group of apps: '★', [recentSectionKey], or a letter.
typedef AppSection = ({String key, List<AppInfo> apps});

/// The App Drawer's app list in a given [DrawerLook]: list rows or a grid,
/// with or without section headers, and the A-Z/★ fast-scroll index (rows
/// have fixed heights, so each section's offset is exact). Also used for
/// search results (one unnamed section, no index) and the Drawer look
/// editor's live preview.
class DrawerAppsView extends StatelessWidget {
  const DrawerAppsView({
    super.key,
    required this.sections,
    required this.look,
    required this.onLaunch,
    this.onMenu,
    this.scrollController,
    this.showIndex = true,
    this.physics,
  });

  final List<AppSection> sections;
  final DrawerLook look;
  final ValueChanged<AppInfo> onLaunch;
  final ValueChanged<AppInfo>? onMenu;
  final ScrollController? scrollController;
  final bool showIndex;
  final ScrollPhysics? physics;

  /// Height of one row of apps: a list row, or a grid row of icon + label.
  static double rowHeight(DrawerLook look) {
    if (!look.grid) return look.listRowPx;
    final label = look.labelPx == 0 ? 0.0 : look.labelPx * 1.3 * look.labelLines;
    final gap = look.iconPx > 0 && label > 0 ? 6.0 : 0.0;
    return 24 + look.iconPx + gap + label;
  }

  @override
  Widget build(BuildContext context) {
    final filled = [
      for (final s in sections)
        if (s.apps.isNotEmpty) s,
    ];
    if (filled.isEmpty) {
      return Center(
        child: Text('No apps found', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }
    final perRow = look.grid ? look.columns : 1;
    final rowPx = rowHeight(look);
    final headers = look.headers && filled.any((s) => s.key.isNotEmpty);

    // Flatten into header labels (String) and rows of apps, tracking each
    // section's offset for the index. With headers, every section starts a
    // new row; without, apps flow on continuously.
    final items = <Object>[];
    final offsets = <String, double>{};
    var height = 0.0;
    if (headers) {
      for (final s in filled) {
        offsets.putIfAbsent(s.key, () => height);
        items.add(s.key);
        height += _headerHeight;
        for (var i = 0; i < s.apps.length; i += perRow) {
          items.add(s.apps.sublist(i, (i + perRow).clamp(0, s.apps.length)));
          height += rowPx;
        }
      }
    } else {
      final all = <AppInfo>[];
      for (final s in filled) {
        offsets.putIfAbsent(s.key, () => (all.length ~/ perRow) * rowPx);
        all.addAll(s.apps);
      }
      for (var i = 0; i < all.length; i += perRow) {
        items.add(all.sublist(i, (i + perRow).clamp(0, all.length)));
      }
    }

    final list = ListView.builder(
      controller: scrollController,
      physics: physics,
      padding: EdgeInsets.only(right: showIndex ? 28 : 0),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is String) return _SectionHeader(label: item);
        final row = item as List<AppInfo>;
        if (!look.grid) {
          final app = row.single;
          return AppResultRow(
            app: app,
            inset: 11,
            height: rowPx,
            iconSize: look.iconPx,
            labelSize: look.labelPx,
            labelLines: look.labelLines,
            onTap: () => onLaunch(app),
            onLongPress: onMenu == null ? null : () => onMenu!(app),
          );
        }
        return SizedBox(
          height: rowPx,
          child: Row(
            children: [
              for (var i = 0; i < perRow; i++)
                Expanded(
                  child: i < row.length
                      ? _GridCell(
                          app: row[i],
                          look: look,
                          onTap: () => onLaunch(row[i]),
                          onLongPress: onMenu == null ? null : () => onMenu!(row[i]),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        );
      },
    );
    if (!showIndex || offsets.isEmpty) return list;
    final letters = [
      ..._indexLetters.take(1),
      if (offsets.containsKey(recentSectionKey)) recentSectionKey,
      ..._indexLetters.skip(1),
    ];
    return Stack(
      // The index sits in the panel's margin, as near the edge as the original's.
      clipBehavior: Clip.none,
      children: [
        list,
        Positioned(
          right: -11,
          top: 0,
          bottom: 0,
          child: _FastScrollIndex(
            letters: letters,
            onLetterSelected: (letter) {
              final controller = scrollController;
              if (controller == null || !controller.hasClients) return;
              // A letter with no apps jumps to the next one that has some
              // (or the last section, past the end).
              final i = letters.indexOf(letter);
              final target = letters.skip(i).where(offsets.containsKey).firstOrNull ?? offsets.keys.last;
              controller.jumpTo(offsets[target]!.clamp(0, controller.position.maxScrollExtent));
            },
          ),
        ),
      ],
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({required this.app, required this.look, required this.onTap, this.onLongPress});

  final AppInfo app;
  final DrawerLook look;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (look.iconPx > 0) AppIcon(icon: app.icon, size: look.iconPx),
            if (look.iconPx > 0 && look.labelPx > 0) const SizedBox(height: 6),
            if (look.labelPx > 0)
              Text(
                app.name,
                maxLines: look.labelLines,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: look.labelPx, height: 1.2),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: _headerHeight,
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.only(left: 16, bottom: 20),
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label == recentSectionKey ? '◷' : label,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: colors.onSurface),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, thickness: 1, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// A-Z/#/★-style side strip: tap or drag to jump the list to a section.
class _FastScrollIndex extends StatelessWidget {
  const _FastScrollIndex({required this.letters, required this.onLetterSelected});

  final List<String> letters;
  final ValueChanged<String> onLetterSelected;

  @override
  Widget build(BuildContext context) {
    // A centred column at the original's pitch, squeezed if it can't fit.
    return SizedBox(
      width: 24,
      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: SizedBox(
            height: (letters.length * 18.0).clamp(0, constraints.maxHeight),
            child: Builder(
              builder: (indexContext) {
                void handlePointer(Offset globalPosition) {
                  final box = indexContext.findRenderObject() as RenderBox;
                  final local = box.globalToLocal(globalPosition);
                  final index = (local.dy / box.size.height * letters.length).floor().clamp(0, letters.length - 1);
                  onLetterSelected(letters[index]);
                }

                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: (d) => handlePointer(d.globalPosition),
                  onVerticalDragUpdate: (d) => handlePointer(d.globalPosition),
                  child: Column(
                    children: [
                      for (final letter in letters)
                        Expanded(
                          child: Center(
                            child: Text(
                              letter == recentSectionKey ? '◷' : letter,
                              style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurface),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
