import 'package:flutter_test/flutter_test.dart';
import 'package:launcher/my_space/tiles/hydration_tile.dart';

void main() {
  final today = DateTime(2026, 10, 3, 9);

  test('the count is per day, and the goal defaults to 8', () {
    final data = withGlasses({}, 3, today);
    expect(glassesToday(data, today.add(const Duration(hours: 10))), 3);
    expect(glassesToday(data, DateTime(2026, 10, 4, 9)), 0);
    expect(glassGoal({}), 8);
    expect(glassGoal(withGlasses({'goal': 10}, 1, today)), 10); // logging keeps the goal
  });
}
