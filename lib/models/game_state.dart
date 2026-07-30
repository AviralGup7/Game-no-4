/// Mutable game state: entries, notes, undo, timer. Kept out of the widget
/// tree so it is unit-testable and serialisable for save/resume.
library;

import 'dart:convert';
import '../engine/futoshiki_engine.dart';

class _Move {
  final int index;
  final int prevValue;
  final Set<int> prevNotes;
  _Move(this.index, this.prevValue, this.prevNotes);
}

class GameState {
  final FutoshikiPuzzle puzzle;
  final List<int> entries;
  final List<Set<int>> notes;
  final List<_Move> _undo = [];

  int selected = -1;
  bool noteMode = false;
  int mistakes = 0;
  int hintsUsed = 0;
  int elapsedSeconds = 0;

  GameState(this.puzzle)
      : entries = List<int>.from(puzzle.givens),
        notes = List.generate(puzzle.cellCount, (_) => <int>{});

  bool isEditable(int i) => !puzzle.isGiven(i);
  bool get canUndo => _undo.isNotEmpty;

  int get filledCount => entries.where((v) => v != 0).length;

  /// How many of [v] are placed. Drives the "used up" state on the number pad,
  /// saving the player from counting by eye.
  int countOf(int v) => entries.where((e) => e == v).length;
  bool isExhausted(int v) => countOf(v) >= puzzle.size;

  /// Returns true if the placed value was WRONG.
  bool place(int index, int value) {
    if (!isEditable(index)) return false;
    _undo.add(_Move(index, entries[index], Set.of(notes[index])));
    entries[index] = value;
    notes[index].clear();
    final wrong = value != 0 && value != puzzle.solution[index];
    if (wrong) mistakes++;
    return wrong;
  }

  void toggleNote(int index, int value) {
    if (!isEditable(index) || entries[index] != 0) return;
    _undo.add(_Move(index, entries[index], Set.of(notes[index])));
    if (!notes[index].add(value)) notes[index].remove(value);
  }

  void erase(int index) {
    if (!isEditable(index)) return;
    if (entries[index] == 0 && notes[index].isEmpty) return;
    _undo.add(_Move(index, entries[index], Set.of(notes[index])));
    entries[index] = 0;
    notes[index].clear();
  }

  void undo() {
    if (_undo.isEmpty) return;
    final m = _undo.removeLast();
    entries[m.index] = m.prevValue;
    notes[m.index]
      ..clear()
      ..addAll(m.prevNotes);
  }

  Set<int> get conflicts => FutoshikiEngine.findConflicts(puzzle, entries);

  Set<int> get wrongCells {
    final out = <int>{};
    for (int i = 0; i < puzzle.cellCount; i++) {
      if (isEditable(i) && entries[i] != 0 && entries[i] != puzzle.solution[i]) {
        out.add(i);
      }
    }
    return out;
  }

  bool get isSolved {
    for (int i = 0; i < puzzle.cellCount; i++) {
      if (entries[i] != puzzle.solution[i]) return false;
    }
    return true;
  }

  Hint? nextHint() => FutoshikiEngine.findHint(puzzle, entries);

  String toJson() => jsonEncode({
        'size': puzzle.size,
        'givens': puzzle.givens,
        'solution': puzzle.solution,
        'difficulty': puzzle.difficulty.index,
        'seed': puzzle.seed,
        'cons': puzzle.constraints.map((c) => [c.hi, c.lo]).toList(),
        'entries': entries,
        'notes': notes.map((s) => s.toList()).toList(),
        'mistakes': mistakes,
        'hints': hintsUsed,
        'seconds': elapsedSeconds,
      });

  static GameState? fromJson(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final p = FutoshikiPuzzle(
        size: m['size'] as int,
        givens: (m['givens'] as List).cast<int>(),
        solution: (m['solution'] as List).cast<int>(),
        constraints: (m['cons'] as List)
            .map((e) => Constraint((e as List)[0] as int, e[1] as int))
            .toList(),
        difficulty: Difficulty.values[m['difficulty'] as int],
        seed: m['seed'] as int,
      );
      final g = GameState(p);
      final e = (m['entries'] as List).cast<int>();
      for (int i = 0; i < g.entries.length && i < e.length; i++) {
        g.entries[i] = e[i];
      }
      final n = m['notes'] as List;
      for (int i = 0; i < g.notes.length && i < n.length; i++) {
        g.notes[i] = (n[i] as List).cast<int>().toSet();
      }
      g.mistakes = m['mistakes'] as int? ?? 0;
      g.hintsUsed = m['hints'] as int? ?? 0;
      g.elapsedSeconds = m['seconds'] as int? ?? 0;
      return g;
    } catch (_) {
      // A corrupt save must never crash the app; just start fresh.
      return null;
    }
  }
}
