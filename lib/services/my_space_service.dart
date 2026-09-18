import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/my_space_tile.dart';

/// Persists the My Space dashboard's tile list (order, kind, per-tile
/// data) as JSON in shared_preferences.
class MySpaceService {
  const MySpaceService();

  static const _key = 'my_space_tiles';

  Future<List<MySpaceTile>> loadTiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => MySpaceTile.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveTiles(List<MySpaceTile> tiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(tiles.map((t) => t.toJson()).toList()));
  }
}
