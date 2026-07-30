/// Streaks, history and stats. The daily streak is the strongest retention
/// mechanic available: loss aversion turns it into an asset players protect.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'daily_puzzle.dart';

class Progress extends ChangeNotifier {
  static const _kDone = 'completed_days';
  static const _kBest = 'best_streak';
  static const _kTotal = 'total_puzzles';
  static const _kSeconds = 'total_seconds';
  static const _kBestTimes = 'best_times';
  static const _kSaved = 'saved_game';

  SharedPreferences? _p;
  final Set<int> _done = {};
  int _best = 0, _total = 0, _seconds = 0;
  final Map<String, int> _bestTimes = {};

  int get bestStreak => _best;
  int get totalPuzzles => _total;
  int get totalSeconds => _seconds;
  Map<String, int> get bestTimes => Map.unmodifiable(_bestTimes);

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    _done
      ..clear()
      ..addAll((_p?.getStringList(_kDone) ?? const [])
          .map(int.tryParse)
          .whereType<int>());
    _best = _p?.getInt(_kBest) ?? 0;
    _total = _p?.getInt(_kTotal) ?? 0;
    _seconds = _p?.getInt(_kSeconds) ?? 0;
    _bestTimes.clear();
    for (final e in _p?.getStringList(_kBestTimes) ?? const <String>[]) {
      final parts = e.split(':');
      if (parts.length == 2) {
        final v = int.tryParse(parts[1]);
        if (v != null) _bestTimes[parts[0]] = v;
      }
    }
    notifyListeners();
  }

  bool isComplete(DateTime d) => _done.contains(DailyPuzzle.dateKey(d));

  /// Consecutive days ending today, or yesterday if today is unplayed - so the
  /// streak is not shown as broken before the player has had a chance.
  int get currentStreak {
    final now = DateTime.now();
    var cursor = isComplete(now)
        ? DateTime(now.year, now.month, now.day)
        : DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 1));
    int n = 0;
    while (_done.contains(DailyPuzzle.dateKey(cursor))) {
      n++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return n;
  }

  Future<void> markComplete(DateTime day,
      {int seconds = 0, String? difficultyKey}) async {
    if (_done.add(DailyPuzzle.dateKey(day))) {
      _total++;
      _seconds += seconds;
      if (currentStreak > _best) _best = currentStreak;
    }
    if (difficultyKey != null && seconds > 0) {
      final prev = _bestTimes[difficultyKey];
      if (prev == null || seconds < prev) _bestTimes[difficultyKey] = seconds;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> recordPractice(int seconds, String key) async {
    _total++;
    _seconds += seconds;
    final prev = _bestTimes[key];
    if (prev == null || seconds < prev) _bestTimes[key] = seconds;
    await _persist();
    notifyListeners();
  }

  // Losing a half-finished puzzle to a back-press is infuriating, and this
  // audience backgrounds apps mid-puzzle more often.
  Future<void> saveGame(String json) async => _p?.setString(_kSaved, json);
  String? loadGame() => _p?.getString(_kSaved);
  Future<void> clearSavedGame() async => _p?.remove(_kSaved);

  Future<void> _persist() async {
    await _p?.setStringList(_kDone, _done.map((e) => '$e').toList());
    await _p?.setInt(_kBest, _best);
    await _p?.setInt(_kTotal, _total);
    await _p?.setInt(_kSeconds, _seconds);
    await _p?.setStringList(_kBestTimes,
        _bestTimes.entries.map((e) => '${e.key}:${e.value}').toList());
  }
}
