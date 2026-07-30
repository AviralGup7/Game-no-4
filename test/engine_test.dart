import 'package:flutter_test/flutter_test.dart';
import 'package:large_print_futoshiki/engine/futoshiki_engine.dart';
import 'package:large_print_futoshiki/engine/generator.dart';

void main() {
  group('uniqueness - the critical invariant', () {
    test('every generated puzzle has EXACTLY one solution', () {
      int n = 0;
      for (final d in Difficulty.values) {
        for (int s = 0; s < 6; s++) {
          final p = FutoshikiGenerator.generate(
              difficulty: d, seed: s * 211 + 13);
          expect(FutoshikiEngine.countSolutions(p, limit: 3), 1,
              reason: '${d.label} seed ${s * 211 + 13} is not unique');
          n++;
        }
      }
      expect(n, 24);
    });

    test('solver reproduces the stored solution', () {
      for (final d in Difficulty.values) {
        for (int s = 0; s < 4; s++) {
          final p =
              FutoshikiGenerator.generate(difficulty: d, seed: s * 97 + 5);
          expect(FutoshikiEngine.solve(p), p.solution);
        }
      }
    });

    test('givens always agree with the solution', () {
      for (final d in Difficulty.values) {
        final p = FutoshikiGenerator.generate(difficulty: d, seed: 4242);
        for (int i = 0; i < p.cellCount; i++) {
          if (p.givens[i] != 0) expect(p.givens[i], p.solution[i]);
        }
      }
    });
  });

  group('solution validity', () {
    test('the solution is a Latin square', () {
      for (final d in Difficulty.values) {
        final p = FutoshikiGenerator.generate(difficulty: d, seed: 77);
        final n = p.size;
        for (int r = 0; r < n; r++) {
          final row = <int>{};
          for (int c = 0; c < n; c++) {
            row.add(p.solution[r * n + c]);
          }
          expect(row.length, n, reason: '${d.label}: row $r repeats a digit');
          expect(row, everyElement(inInclusiveRange(1, n)));
        }
        for (int c = 0; c < n; c++) {
          final col = <int>{};
          for (int r = 0; r < n; r++) {
            col.add(p.solution[r * n + c]);
          }
          expect(col.length, n, reason: '${d.label}: column $c repeats');
        }
      }
    });

    test('every sign points the correct way', () {
      for (final d in Difficulty.values) {
        final p = FutoshikiGenerator.generate(difficulty: d, seed: 31);
        for (final con in p.constraints) {
          expect(p.solution[con.hi], greaterThan(p.solution[con.lo]),
              reason: '${d.label}: a sign contradicts the solution');
        }
      }
    });

    test('signs only join adjacent cells', () {
      for (final d in Difficulty.values) {
        final p = FutoshikiGenerator.generate(difficulty: d, seed: 8);
        final n = p.size;
        for (final con in p.constraints) {
          final ar = con.hi ~/ n, ac = con.hi % n;
          final br = con.lo ~/ n, bc = con.lo % n;
          final dist = (ar - br).abs() + (ac - bc).abs();
          expect(dist, 1, reason: 'sign joins non-adjacent cells');
        }
      }
    });

    test('the solution has no conflicts and is complete', () {
      final p =
          FutoshikiGenerator.generate(difficulty: Difficulty.medium, seed: 5);
      expect(FutoshikiEngine.findConflicts(p, p.solution), isEmpty);
      expect(FutoshikiEngine.isComplete(p, p.solution), isTrue);
    });
  });

  group('determinism', () {
    test('same seed gives the same puzzle', () {
      final a =
          FutoshikiGenerator.generate(difficulty: Difficulty.easy, seed: 99);
      final b =
          FutoshikiGenerator.generate(difficulty: Difficulty.easy, seed: 99);
      expect(a.solution, b.solution);
      expect(a.givens, b.givens);
      expect(a.constraints.length, b.constraints.length);
    });

    test('different seeds give different puzzles', () {
      final a =
          FutoshikiGenerator.generate(difficulty: Difficulty.easy, seed: 1);
      final b =
          FutoshikiGenerator.generate(difficulty: Difficulty.easy, seed: 2);
      expect(a.solution, isNot(b.solution));
    });
  });

  group('conflict detection', () {
    late FutoshikiPuzzle p;
    setUp(() =>
        p = FutoshikiGenerator.generate(difficulty: Difficulty.easy, seed: 3));

    test('duplicate in a row is flagged', () {
      final g = List<int>.filled(p.cellCount, 0);
      g[0] = 2;
      g[1] = 2;
      expect(FutoshikiEngine.findConflicts(p, g), containsAll([0, 1]));
    });

    test('duplicate in a column is flagged', () {
      final g = List<int>.filled(p.cellCount, 0);
      g[0] = 3;
      g[p.size] = 3;
      expect(FutoshikiEngine.findConflicts(p, g), containsAll([0, p.size]));
    });

    test('a violated inequality is flagged', () {
      final con = p.constraints.first;
      final g = List<int>.filled(p.cellCount, 0);
      g[con.hi] = 1;
      g[con.lo] = p.size; // deliberately backwards
      expect(FutoshikiEngine.findConflicts(p, g),
          containsAll([con.hi, con.lo]));
    });

    test('an empty grid is not complete', () {
      expect(FutoshikiEngine.isComplete(p, List<int>.filled(p.cellCount, 0)),
          isFalse);
    });
  });

  group('hints', () {
    test('a hint is always correct, and hints can finish a puzzle', () {
      final p =
          FutoshikiGenerator.generate(difficulty: Difficulty.easy, seed: 21);
      final grid = List<int>.from(p.givens);
      int guard = 0;
      while (grid.contains(0) && guard++ < 100) {
        final h = FutoshikiEngine.findHint(p, grid);
        expect(h, isNotNull);
        expect(h!.value, p.solution[h.index],
            reason: 'hint contradicts the solution');
        grid[h.index] = h.value;
      }
      expect(FutoshikiEngine.isComplete(p, grid), isTrue);
    });

    test('returns null on a finished grid', () {
      final p =
          FutoshikiGenerator.generate(difficulty: Difficulty.gentle, seed: 9);
      expect(FutoshikiEngine.findHint(p, p.solution), isNull);
    });
  });

  group('performance', () {
    test('generation stays fast enough for the UI thread', () {
      final sw = Stopwatch()..start();
      for (final d in Difficulty.values) {
        for (int s = 0; s < 3; s++) {
          FutoshikiGenerator.generate(difficulty: d, seed: s * 17 + 2);
        }
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(6000),
          reason: '12 puzzles took ${sw.elapsedMilliseconds}ms');
    });
  });
}
