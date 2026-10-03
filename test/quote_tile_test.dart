import 'package:flutter_test/flutter_test.dart';
import 'package:launcher/my_space/tiles/quote_tile.dart';

void main() {
  final morning = DateTime(2026, 10, 3, 8);
  final evening = DateTime(2026, 10, 3, 22);
  final tomorrow = DateTime(2026, 10, 4, 8);

  test('one quote per day', () {
    expect(quoteIndex({}, morning), quoteIndex({}, evening));
    expect(quoteIndex({}, tomorrow), (quoteIndex({}, morning) + 1) % quotes.length);
  });

  test('refresh moves to the next quote for the rest of the day only', () {
    final once = refreshedQuote({}, morning);
    final twice = refreshedQuote(once, evening);
    expect(quoteIndex(once, evening), (quoteIndex({}, morning) + 1) % quotes.length);
    expect(quoteIndex(twice, evening), (quoteIndex({}, morning) + 2) % quotes.length);
    expect(quoteIndex(twice, tomorrow), quoteIndex({}, tomorrow)); // a new day starts fresh
  });
}
