/// Futoshiki puzzle generation.
///
/// Strategy:
///   1. Build a random Latin square (the solution).
///   2. Add inequality signs between adjacent cells.
///   3. Start from ALL cells given, then remove givens one at a time,
///      keeping a removal only while the puzzle still has exactly one
///      solution.
///
/// Step 3 is the standard "dig out" method and guarantees uniqueness by
/// construction rather than by rejection - which matters, because on the
/// kakuro build (game #3) rejection-based generation failed 60/60 times.
library;

import 'futoshiki_engine.dart';

class FutoshikiGenerator {
  static FutoshikiPuzzle generate({
    required Difficulty difficulty,
    required int seed,
  }) {
    final n = difficulty.size;
    final rng = Mulberry32(seed);
    final solution = _latinSquare(n, rng);

    // Sign density: more signs means more deduction from inequalities and
    // fewer numbers needed on screen, which is the flavour that makes
    // futoshiki distinct from sudoku.
    final density = switch (difficulty) {
      Difficulty.gentle => 0.42,
      Difficulty.easy => 0.38,
      Difficulty.medium => 0.34,
      Difficulty.hard => 0.30,
    };

    final constraints = _signs(n, solution, density, rng);

    // Dig out: begin fully revealed, then remove while uniqueness holds.
    final givens = List<int>.from(solution);
    final order = List.generate(n * n, (i) => i);
    rng.shuffle(order);

    for (final cell in order) {
      final keep = givens[cell];
      givens[cell] = 0;
      final probe = FutoshikiPuzzle(
        size: n,
        givens: givens,
        solution: solution,
        constraints: constraints,
        difficulty: difficulty,
        seed: seed,
      );
      if (FutoshikiEngine.countSolutions(probe, limit: 2) != 1) {
        givens[cell] = keep; // removal broke uniqueness: put it back
      }
    }

    final puzzle = FutoshikiPuzzle(
      size: n,
      givens: givens,
      solution: solution,
      constraints: constraints,
      difficulty: difficulty,
      seed: seed,
    );

    // Defensive: the dig-out loop should make this impossible, but a puzzle
    // with two solutions is the one bug the player cannot diagnose, so we
    // verify rather than assume.
    if (FutoshikiEngine.countSolutions(puzzle, limit: 2) != 1) {
      throw GenerationFailure(
          'Generated ${difficulty.label} puzzle from seed $seed is not unique.');
    }
    return puzzle;
  }

  /// A random Latin square via backtracking on a shuffled value order.
  static List<int> _latinSquare(int n, Mulberry32 rng) {
    final g = List<int>.filled(n * n, 0);

    bool rec(int idx) {
      if (idx == n * n) return true;
      final r = idx ~/ n, c = idx % n;
      final vals = List.generate(n, (i) => i + 1);
      rng.shuffle(vals);
      for (final v in vals) {
        bool ok = true;
        for (int k = 0; k < n; k++) {
          if (g[r * n + k] == v || g[k * n + c] == v) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
        g[idx] = v;
        if (rec(idx + 1)) return true;
        g[idx] = 0;
      }
      return false;
    }

    rec(0);
    return g;
  }

  /// Place inequality signs on a random subset of adjacent pairs, always
  /// pointing the correct way for the solution.
  static List<Constraint> _signs(
      int n, List<int> sol, double density, Mulberry32 rng) {
    final pairs = <List<int>>[];
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        final i = r * n + c;
        if (c < n - 1) pairs.add([i, i + 1]);
        if (r < n - 1) pairs.add([i, i + n]);
      }
    }
    rng.shuffle(pairs);
    final take = (pairs.length * density).round();

    final out = <Constraint>[];
    for (int k = 0; k < take && k < pairs.length; k++) {
      final a = pairs[k][0], b = pairs[k][1];
      out.add(sol[a] > sol[b] ? Constraint(a, b) : Constraint(b, a));
    }
    return out;
  }
}
