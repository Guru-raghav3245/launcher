import 'tile_kind.dart';

/// A single tile on the My Space dashboard. [data] holds per-kind payload
/// (e.g. Notes text, Todo items) as a JSON-compatible map, kept generic so
/// each tile type (Phase 3 tasks 3-7) doesn't need its own storage schema.
class MySpaceTile {
  const MySpaceTile({required this.id, required this.kind, this.data = const {}});

  final String id;
  final TileKind kind;
  final Map<String, dynamic> data;

  MySpaceTile copyWith({Map<String, dynamic>? data}) {
    return MySpaceTile(id: id, kind: kind, data: data ?? this.data);
  }

  Map<String, dynamic> toJson() => {'id': id, 'kind': kind.name, 'data': data};

  factory MySpaceTile.fromJson(Map<String, dynamic> json) {
    return MySpaceTile(
      id: json['id'] as String,
      kind: TileKind.values.byName(json['kind'] as String),
      data: Map<String, dynamic>.from(json['data'] as Map),
    );
  }
}
