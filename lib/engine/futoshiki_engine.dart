/// Futoshiki generation and solving.
///
/// Pure Dart, no Flutter imports, so the engine unit-tests on a bare VM.
///
/// Futoshiki rules:
///   * An N x N grid holds the digits 1..N.
///   * Every row and every column contains each digit exactly once (a Latin
///     square) - note there are NO 3x3 boxes, unlike sudoku.
///   * Some adjacent pairs carry a < or > sign that the solution must satisfy.
///
/// The non-negotiable invariant, as in every game in this portfolio: each
/// puzzle has EXACTLY ONE solution. A player who satisfies every visible
/// constraint and is still told they are wrong concludes the app is broken.
library;

/// Deterministic PRNG so a seed maps to the same puzzle on every device.
/// This is what lets the daily puzzle work with no server.
class Mulberry32 {
  int _s;
  Mulberry32(int seed) : _s = seed & 0xFFFFFFFF;

  double next() {
    _s = (_s + 0x6D2B79F5) & 0xFFFFFFFF;
    int t = _s;
    t = (t ^ (t >>> 15)) * (t | 1) & 0xFFFFFFFF;
    t = (t ^ (t + ((t ^ (t >>> 7)) * (t | 61) & 0xFFFFFFFF))) & 0xFFFFFFFF;
    return ((t ^ (t >>> 14)) & 0xFFFFFFFF) / 4294967296.0;
  }

  int nextInt(int max) => (next() * max).floor();

  void shuffle<T>(List<T> l) {
    for (int i = l.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = l[i];
      l[i] = l[j];
      l[j] = t;
    }
  }
}

enum Difficulty { gentle, easy, medium, hard }

extension DifficultyInfo on Difficulty {
  String get label => switch (this) {
        Difficulty.gentle => 'Gentle',
        Difficulty.easy => 'Easy',
        Difficulty.medium => 'Medium',
        Difficulty.hard => 'Hard',
      };

  /// Plain language. "Expert"/"evil" naming implies failure and discourages
  /// people from starting - the opposite of what this audience needs.
  String get blurb => switch (this) {
        Difficulty.gentle => 'A small grid to warm up',
        Difficulty.easy => 'A relaxed puzzle',
        Difficulty.medium => 'A bit more thinking',
        Difficulty.hard => 'A real challenge',
      };

  /// Grid size. Futoshiki is traditionally 4x4 to 7x7; beyond that the
  /// inequality chains get hard to hold in your head.
  int get size => switch (this) {
        Difficulty.gentle => 4,
        Difficulty.easy => 5,
        Difficulty.medium => 6,
        Difficulty.hard => 7,
      };
}

/// A "greater than" relation between two adjacent cells: [hi] holds the
/// larger value. Stored one-directionally so rendering never has to guess
/// which way the chevron points.
class Constraint {
  final int hi;
  final int lo;
  const Constraint(this.hi, this.lo);

  @override
  bool operator ==(Object other) =>
      other is Constraint && other.hi == hi && other.lo == lo;
  @override
  int get hashCode => hi * 1000 + lo;
}

class FutoshikiPuzzle {
  final int size;
  /// Pre-filled cells shown to the player; 0 = empty.
  final List<int> givens;
  final List<int> solution;
  final List<Constraint> constraints;
  final Difficulty difficulty;
  final int seed;

  const FutoshikiPuzzle({
    required this.size,
    required this.givens,
    required this.solution,
    required this.constraints,
    required this.difficulty,
    required this.seed,
  });

  int get cellCount => size * size;
  bool isGiven(int i) => givens[i] != 0;
  int get givenCount => givens.where((v) => v != 0).length;

  String get debugString {
    final b = StringBuffer();
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final i = r * size + c;
        b.write(solution[i] == 0 ? '.' : '${solution[i]}');
        if (c < size - 1) {
          final a = i, d = i + 1;
          if (constraints.contains(Constraint(a, d))) {
            b.write(' > ');
          } else if (constraints.contains(Constraint(d, a))) {
            b.write(' < ');
          } else {
            b.write('   ');
          }
        }
      }
      b.writeln();
      if (r < size - 1) {
        for (int c = 0; c < size; c++) {
          final a = r * size + c, d = (r + 1) * size + c;
          if (constraints.contains(Constraint(a, d))) {
            b.write('v');
          } else if (constraints.contains(Constraint(d, a))) {
            b.write('^');
          } else {
            b.write(' ');
          }
          if (c < size - 1) b.write('   ');
        }
        b.writeln();
      }
    }
    return b.toString();
  }
}

class GenerationFailure implements Exception {
  final String message;
  GenerationFailure(this.message);
  @override
  String toString() => 'GenerationFailure: $message';
}

class FutoshikiEngine {
  /// Constraints indexed by the cell they touch, so the solver never scans
  /// the whole list. Built per puzzle because the constraint set varies.
  static Map<int, List<Constraint>> indexConstraints(FutoshikiPuzzle p) {
    final m = <int, List<Constraint>>{};
    for (final c in p.constraints) {
      (m[c.hi] ??= []).add(c);
      (m[c.lo] ??= []).add(c);
    }
    return m;
  }

  /// Can [v] legally sit at [cell]?
  static bool canPlace(
    List<int> grid,
    int size,
    Map<int, List<Constraint>> byCell,
    int cell,
    int v,
  ) {
    final r = cell ~/ size, c = cell % size;
    for (int k = 0; k < size; k++) {
      if (grid[r * size + k] == v && r * size + k != cell) return false;
      if (grid[k * size + c] == v && k * size + c != cell) return false;
    }
    // Inequalities are only checked once BOTH ends are filled; a partial grid
    // must stay explorable.
    for (final con in byCell[cell] ?? const <Constraint>[]) {
      final other = con.hi == cell ? con.lo : con.hi;
      final ov = grid[other];
      if (ov == 0) continue;
      final hiVal = con.hi == cell ? v : ov;
      final loVal = con.hi == cell ? ov : v;
      if (hiVal <= loVal) return false;
    }
    return true;
  }

  /// Count solutions, stopping at [limit]. Branches on the most-constrained
  /// cell, which prunes the tree enough to run on every generated puzzle.
  static int countSolutions(FutoshikiPuzzle p, {int limit = 2}) {
    final grid = List<int>.from(p.givens);
    final byCell = indexConstraints(p);
    return _count(grid, p.size, byCell, limit);
  }

  static int _count(
      List<int> g, int size, Map<int, List<Constraint>> byCell, int limit) {
    int best = -1, bestCount = 99;
    List<int> bestCands = const [];

    for (int i = 0; i < g.length; i++) {
      if (g[i] != 0) continue;
      final cands = <int>[];
      for (int v = 1; v <= size; v++) {
        if (canPlace(g, size, byCell, i, v)) cands.add(v);
      }
      if (cands.isEmpty) return 0;
      if (cands.length < bestCount) {
        bestCount = cands.length;
        best = i;
        bestCands = cands;
        if (bestCount == 1) break;
      }
    }
    if (best == -1) return 1;

    int total = 0;
    for (final v in bestCands) {
      g[best] = v;
      total += _count(g, size, byCell, limit);
      g[best] = 0;
      if (total >= limit) return total;
    }
    return total;
  }

  static List<int>? solve(FutoshikiPuzzle p) {
    final grid = List<int>.from(p.givens);
    final byCell = indexConstraints(p);
    return _solve(grid, p.size, byCell) ? grid : null;
  }

  static bool _solve(
      List<int> g, int size, Map<int, List<Constraint>> byCell) {
    int best = -1, bestCount = 99;
    List<int> bestCands = const [];
    for (int i = 0; i < g.length; i++) {
      if (g[i] != 0) continue;
      final cands = <int>[];
      for (int v = 1; v <= size; v++) {
        if (canPlace(g, size, byCell, i, v)) cands.add(v);
      }
      if (cands.isEmpty) return false;
      if (cands.length < bestCount) {
        bestCount = cands.length;
        best = i;
        bestCands = cands;
        if (bestCount == 1) break;
      }
    }
    if (best == -1) return true;
    for (final v in bestCands) {
      g[best] = v;
      if (_solve(g, size, byCell)) return true;
      g[best] = 0;
    }
    return false;
  }

  /// Indices that break a rule in the current grid. Used for live feedback.
  static Set<int> findConflicts(FutoshikiPuzzle p, List<int> grid) {
    final bad = <int>{};
    final n = p.size;
    for (int r = 0; r < n; r++) {
      final seen = <int, int>{};
      for (int c = 0; c < n; c++) {
        final i = r * n + c, v = grid[i];
        if (v == 0) continue;
        final prev = seen[v];
        if (prev != null) {
          bad..add(prev)..add(i);
        } else {
          seen[v] = i;
        }
      }
    }
    for (int c = 0; c < n; c++) {
      final seen = <int, int>{};
      for (int r = 0; r < n; r++) {
        final i = r * n + c, v = grid[i];
        if (v == 0) continue;
        final prev = seen[v];
        if (prev != null) {
          bad..add(prev)..add(i);
        } else {
          seen[v] = i;
        }
      }
    }
    for (final con in p.constraints) {
      final a = grid[con.hi], b = grid[con.lo];
      if (a == 0 || b == 0) continue;
      if (a <= b) bad..add(con.hi)..add(con.lo);
    }
    return bad;
  }

  static bool isComplete(FutoshikiPuzzle p, List<int> grid) =>
      !grid.contains(0) && findConflicts(p, grid).isEmpty;

  static List<int> candidates(
      FutoshikiPuzzle p, List<int> grid, int cell) {
    if (grid[cell] != 0) return const [];
    final byCell = indexConstraints(p);
    final out = <int>[];
    for (int v = 1; v <= p.size; v++) {
      if (canPlace(grid, p.size, byCell, cell, v)) out.add(v);
    }
    return out;
  }

  /// Next logically deducible cell: one with a single candidate. Falls back to
  /// any empty cell. A hint that names a forced move teaches; one that just
  /// fills a gap does not.
  static Hint? findHint(FutoshikiPuzzle p, List<int> grid) {
    for (int i = 0; i < grid.length; i++) {
      if (grid[i] != 0) continue;
      final c = candidates(p, grid, i);
      if (c.length == 1) {
        return Hint(index: i, value: c.first, forced: true);
      }
    }
    for (int i = 0; i < grid.length; i++) {
      if (grid[i] == 0) {
        return Hint(index: i, value: p.solution[i], forced: false);
      }
    }
    return null;
  }
}

class Hint {
  final int index;
  final int value;
  final bool forced;
  const Hint({required this.index, required this.value, required this.forced});

  String get explanation => forced
      ? 'Only one number can go here. Every other option is already used in '
          'this row or column, or breaks an arrow.'
      : 'Here is the next number.';
}
