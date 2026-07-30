/// Widget + state tests. These assert the ACCESSIBILITY and CORRECTNESS
/// guarantees, not just that widgets render.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:large_print_futoshiki/engine/futoshiki_engine.dart';
import 'package:large_print_futoshiki/engine/generator.dart';
import 'package:large_print_futoshiki/models/game_state.dart';
import 'package:large_print_futoshiki/services/settings.dart';
import 'package:large_print_futoshiki/services/progress.dart';
import 'package:large_print_futoshiki/services/daily_puzzle.dart';
import 'package:large_print_futoshiki/widgets/app_theme.dart';
import 'package:large_print_futoshiki/widgets/futoshiki_board.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Settings defaults', () {
    test('opens large with helpers on', () async {
      final s = Settings();
      await s.load();
      expect(s.fontScale, greaterThanOrEqualTo(1.15));
      expect(s.showMistakes, isTrue);
      expect(s.highlightPeers, isTrue);
      expect(s.seenTutorial, isFalse);
    });

    test('font scale clamps to a legible range', () async {
      final s = Settings();
      await s.load();
      await s.setFontScale(99);
      expect(s.fontScale, lessThanOrEqualTo(1.6));
      await s.setFontScale(0);
      expect(s.fontScale, greaterThanOrEqualTo(0.85));
    });

    test('preferences survive a reload', () async {
      final a = Settings();
      await a.load();
      await a.setHighContrast(true);
      await a.setFontScale(1.45);
      final b = Settings();
      await b.load();
      expect(b.highContrast, isTrue);
      expect(b.fontScale, closeTo(1.45, 0.001));
    });
  });

  group('Progress + streaks', () {
    test('counts consecutive days and persists', () async {
      final p = Progress();
      await p.load();
      final t = DateTime.now();
      await p.markComplete(t.subtract(const Duration(days: 2)));
      await p.markComplete(t.subtract(const Duration(days: 1)));
      await p.markComplete(t);
      expect(p.currentStreak, 3);
      final q = Progress();
      await q.load();
      expect(q.currentStreak, 3);
    });

    test('a gap breaks the streak', () async {
      final p = Progress();
      await p.load();
      final t = DateTime.now();
      await p.markComplete(t.subtract(const Duration(days: 5)));
      await p.markComplete(t);
      expect(p.currentStreak, 1);
    });

    test('best times only improve', () async {
      final p = Progress();
      await p.load();
      await p.recordPractice(300, 'Easy');
      await p.recordPractice(200, 'Easy');
      await p.recordPractice(400, 'Easy');
      expect(p.bestTimes['Easy'], 200);
    });
  });

  group('GameState', () {
    late FutoshikiPuzzle puzzle;
    setUp(() => puzzle =
        FutoshikiGenerator.generate(difficulty: Difficulty.easy, seed: 4242));

    test('givens are pre-filled and not editable', () {
      final g = GameState(puzzle);
      for (int i = 0; i < puzzle.cellCount; i++) {
        if (puzzle.isGiven(i)) {
          expect(g.entries[i], puzzle.solution[i]);
          expect(g.isEditable(i), isFalse);
        }
      }
    });

    test('a wrong value is reported and counted', () {
      final g = GameState(puzzle);
      final e = List.generate(puzzle.cellCount, (i) => i)
          .firstWhere((i) => g.isEditable(i));
      final wrong = puzzle.solution[e] == puzzle.size ? 1 : puzzle.size;
      expect(g.place(e, wrong), isTrue);
      expect(g.mistakes, 1);
      expect(g.wrongCells, contains(e));
    });

    test('undo restores values and pencil notes', () {
      final g = GameState(puzzle);
      final e = List.generate(puzzle.cellCount, (i) => i)
          .firstWhere((i) => g.isEditable(i));
      g.toggleNote(e, 2);
      g.toggleNote(e, 3);
      expect(g.notes[e], {2, 3});
      g.place(e, puzzle.solution[e]);
      expect(g.notes[e], isEmpty);
      g.undo();
      expect(g.entries[e], 0);
      expect(g.notes[e], {2, 3}, reason: 'undo must restore pencil marks');
    });

    test('filling the solution solves the puzzle', () {
      final g = GameState(puzzle);
      for (int i = 0; i < puzzle.cellCount; i++) {
        if (g.isEditable(i)) g.place(i, puzzle.solution[i]);
      }
      expect(g.isSolved, isTrue);
      expect(g.mistakes, 0);
      expect(FutoshikiEngine.isComplete(puzzle, g.entries), isTrue);
    });

    test('exhausted numbers are detected', () {
      final g = GameState(puzzle);
      for (int i = 0; i < puzzle.cellCount; i++) {
        if (g.isEditable(i)) g.place(i, puzzle.solution[i]);
      }
      for (int v = 1; v <= puzzle.size; v++) {
        expect(g.isExhausted(v), isTrue, reason: '$v should be all placed');
      }
    });

    test('save and restore round-trips exactly', () {
      final g = GameState(puzzle);
      final e = List.generate(puzzle.cellCount, (i) => i)
          .firstWhere((i) => g.isEditable(i));
      g.place(e, puzzle.solution[e]);
      g.elapsedSeconds = 123;
      g.mistakes = 2;
      final r = GameState.fromJson(g.toJson())!;
      expect(r.entries, g.entries);
      expect(r.elapsedSeconds, 123);
      expect(r.mistakes, 2);
      expect(r.puzzle.solution, puzzle.solution);
      expect(r.puzzle.constraints.length, puzzle.constraints.length);
    });

    test('a corrupt save returns null instead of throwing', () {
      expect(GameState.fromJson('not json'), isNull);
      expect(GameState.fromJson('{"size":"wrong"}'), isNull);
    });
  });

  group('Daily puzzle', () {
    test('is deterministic regardless of time of day', () {
      final a = DailyPuzzle.forDate(DateTime(2026, 3, 15, 0, 0, 1));
      final b = DailyPuzzle.forDate(DateTime(2026, 3, 15, 23, 59));
      expect(a.solution, b.solution);
      expect(a.givens, b.givens);
    });

    test('consecutive days differ', () {
      expect(DailyPuzzle.forDate(DateTime(2026, 5, 1)).solution,
          isNot(DailyPuzzle.forDate(DateTime(2026, 5, 2)).solution));
    });

    test('weekday ramp follows newspaper convention', () {
      expect(DailyPuzzle.difficultyFor(DateTime(2026, 7, 27)), Difficulty.gentle);
      expect(DailyPuzzle.difficultyFor(DateTime(2026, 7, 30)), Difficulty.medium);
      expect(DailyPuzzle.difficultyFor(DateTime(2026, 8, 1)), Difficulty.hard);
    });

    test('a month of dailies all generate and are unique', () {
      var d = DateTime(2026, 1, 1);
      int n = 0;
      while (d.isBefore(DateTime(2026, 2, 1))) {
        final p = DailyPuzzle.forDate(d);
        expect(FutoshikiEngine.countSolutions(p, limit: 2), 1,
            reason: '${d.toIso8601String().substring(0, 10)} is not unique');
        d = d.add(const Duration(days: 1));
        n++;
      }
      expect(n, 31);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('Theme accessibility', () {
    testWidgets('buttons meet a 56dp minimum target', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(children: [
            FilledButton(onPressed: () {}, child: const Text('Play')),
            OutlinedButton(onPressed: () {}, child: const Text('Easy')),
          ]),
        ),
      ));
      for (final t in [find.byType(FilledButton), find.byType(OutlinedButton)]) {
        expect(tester.getSize(t).height, greaterThanOrEqualTo(56.0));
      }
    });

    testWidgets('high contrast is pure black on white', (tester) async {
      final hc = AppTheme.light(highContrast: true);
      expect(hc.colorScheme.onSurface, const Color(0xFF000000));
      expect(hc.colorScheme.surface, const Color(0xFFFFFFFF));
    });
  });

  group('Board widget', () {
    testWidgets('renders and reports the tapped cell', (tester) async {
      final p =
          FutoshikiGenerator.generate(difficulty: Difficulty.easy, seed: 7);
      final g = GameState(p);
      int? tapped;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 360,
              child: FutoshikiBoard(
                game: g,
                fontScale: 1.15,
                highContrast: false,
                highlightPeers: true,
                showMistakes: true,
                onTapCell: (i) => tapped = i,
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final rect = tester.getRect(find.byType(CustomPaint).last);
      final n = p.size;
      // Board is n cells + (n-1) gutters, so the tap maths must account for
      // the gutter width, not assume an even grid.
      final cell = rect.width / (n + (n - 1) * kGutterRatio);
      final step = cell + cell * kGutterRatio;
      await tester.tapAt(
          rect.topLeft + Offset(step * 2 + cell / 2, step * 1 + cell / 2));
      await tester.pumpAndSettle();
      expect(tapped, 1 * n + 2);
    });
  });
}
