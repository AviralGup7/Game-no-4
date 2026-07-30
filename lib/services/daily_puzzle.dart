/// Daily puzzle derived purely from the calendar date. No backend: the seed is
/// a hash of the date, so every player worldwide gets the same board. Keeps
/// the app fully offline and cannot break when a server does.
library;

import '../engine/futoshiki_engine.dart';
import '../engine/generator.dart';

class DailyPuzzle {
  static int dateKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  static int seedFor(DateTime d) {
    int k = dateKey(d);
    k = (k * 2654435761) & 0x7FFFFFFF;
    return k ^ (k >>> 13);
  }

  /// Difficulty ramps across the week, matching newspaper convention.
  static Difficulty difficultyFor(DateTime d) => switch (d.weekday) {
        DateTime.monday => Difficulty.gentle,
        DateTime.tuesday || DateTime.wednesday => Difficulty.easy,
        DateTime.thursday || DateTime.friday => Difficulty.medium,
        _ => Difficulty.hard,
      };

  static FutoshikiPuzzle forDate(DateTime date, {Difficulty? override}) {
    final day = DateTime(date.year, date.month, date.day);
    return FutoshikiGenerator.generate(
      difficulty: override ?? difficultyFor(day),
      seed: seedFor(day),
    );
  }

  static FutoshikiPuzzle practice({
    required Difficulty difficulty,
    required int seed,
  }) =>
      FutoshikiGenerator.generate(difficulty: difficulty, seed: seed);
}
