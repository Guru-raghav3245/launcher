import 'package:flutter/material.dart';

import '../../models/my_space_tile.dart';
import '../tile_card.dart';

/// Bundled quotes (text, author) on time, attention, and simplicity.
const quotes = <(String, String)>[
  ('It is not that we have a short time to live, but that we waste a lot of it.', 'Seneca'),
  ('Life is long if you know how to use it.', 'Seneca'),
  ('We suffer more often in imagination than in reality.', 'Seneca'),
  ('Our life is frittered away by detail. Simplify, simplify.', 'Henry David Thoreau'),
  ('It is not enough to be busy; so are the ants. The question is: what are we busy about?', 'Henry David Thoreau'),
  ('How we spend our days is, of course, how we spend our lives.', 'Annie Dillard'),
  ('The art of being wise is the art of knowing what to overlook.', 'William James'),
  ('Adopt the pace of nature: her secret is patience.', 'Ralph Waldo Emerson'),
  (
    'Very little is needed to make a happy life; it is all within yourself, in your way of thinking.',
    'Marcus Aurelius',
  ),
  ('Waste no more time arguing about what a good man should be. Be one.', 'Marcus Aurelius'),
  ('First say to yourself what you would be; and then do what you have to do.', 'Epictetus'),
  ("All of humanity's problems stem from man's inability to sit quietly in a room alone.", 'Blaise Pascal'),
  ('Attention is the beginning of devotion.', 'Mary Oliver'),
  ('Attention is the rarest and purest form of generosity.', 'Simone Weil'),
  ('A wealth of information creates a poverty of attention.', 'Herbert Simon'),
  ('Clarity about what matters provides clarity about what does not.', 'Cal Newport'),
  (
    'Perfection is achieved, not when there is nothing more to add, but when there is nothing left to take away.',
    'Antoine de Saint-Exupéry',
  ),
  ('Almost everything will work again if you unplug it for a few minutes, including you.', 'Anne Lamott'),
  ('Besides the noble art of getting things done, there is the noble art of leaving things undone.', 'Lin Yutang'),
  ('The present moment is filled with joy and happiness. If you are attentive, you will see it.', 'Thich Nhat Hanh'),
];

String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// Which quote [data] shows on [now]'s day: one per calendar day, moved on
/// by however many refreshes were made today (`shift`, reset each day).
int quoteIndex(Map<String, dynamic> data, DateTime now) {
  final day = DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  final shift = data['date'] == _dayKey(now) ? data['shift'] as int? ?? 0 : 0;
  return (day + shift) % quotes.length;
}

/// The tile data after one refresh on [now]'s day.
Map<String, dynamic> refreshedQuote(Map<String, dynamic> data, DateTime now) {
  final shift = data['date'] == _dayKey(now) ? data['shift'] as int? ?? 0 : 0;
  return {'date': _dayKey(now), 'shift': shift + 1};
}

/// Quote tile: today's quote with its author, and a refresh for another.
class QuoteTile extends StatelessWidget {
  const QuoteTile({super.key, required this.tile, required this.onChanged});

  final MySpaceTile tile;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final (text, author) = quotes[quoteIndex(tile.data, now)];
    return TileCard(
      label: 'QUOTE',
      icon: Icons.format_quote,
      trailing: IconButton(
        tooltip: 'Another quote',
        icon: const Icon(Icons.refresh, size: 20),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: () => onChanged(refreshedQuote(tile.data, now)),
      ),
      child: QuoteBody(text: text, author: author),
    );
  }
}

/// A quote and its author, shared by the tile and its Add New Tile preview.
class QuoteBody extends StatelessWidget {
  const QuoteBody({super.key, required this.text, required this.author});

  final String text;
  final String author;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('“$text”', style: const TextStyle(fontSize: 17, height: 1.35)),
        const SizedBox(height: 8),
        Text('— $author', style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}
