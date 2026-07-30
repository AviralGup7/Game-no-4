library;

import 'package:flutter/material.dart';
import '../engine/futoshiki_engine.dart';
import '../models/game_state.dart';
import '../services/daily_puzzle.dart';
import '../services/settings.dart';
import '../services/progress.dart';
import '../services/ads.dart';
import '../services/iap.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'how_to_play.dart';

class HomeScreen extends StatefulWidget {
  final Settings settings;
  final Progress progress;
  final AdService ads;
  final IapService iap;
  const HomeScreen({
    super.key,
    required this.settings,
    required this.progress,
    required this.ads,
    required this.iap,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // First run: show how-to-play. Almost nobody has seen a futoshiki, and the
    // arrows are meaningless until explained.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!widget.settings.seenTutorial && mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => HowToPlayScreen(settings: widget.settings)));
        await widget.settings.markTutorialSeen();
      }
    });
  }

  Future<void> _open(GameState g, String title, {DateTime? daily}) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(
        game: g,
        settings: widget.settings,
        progress: widget.progress,
        ads: widget.ads,
        title: title,
        dailyDate: daily,
      ),
    ));
    if (mounted) setState(() {});
  }

  Future<void> _playDaily() async {
    if (_busy) return;
    setState(() => _busy = true);
    final today = DateTime.now();
    try {
      final p = DailyPuzzle.forDate(today);
      if (!mounted) return;
      setState(() => _busy = false);
      await _open(GameState(p), "Today's Puzzle", daily: today);
    } on GenerationFailure {
      if (!mounted) return;
      setState(() => _busy = false);
      _fail();
    }
  }

  Future<void> _playPractice(Difficulty d) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final seed = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
      final p = DailyPuzzle.practice(difficulty: d, seed: seed);
      if (!mounted) return;
      setState(() => _busy = false);
      await _open(GameState(p), d.label);
    } on GenerationFailure {
      if (!mounted) return;
      setState(() => _busy = false);
      _fail();
    }
  }

  void _fail() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not build that puzzle. Please try again.',
            style: TextStyle(fontSize: 17))));
  }

  Future<void> _resume() async {
    final raw = widget.progress.loadGame();
    if (raw == null) return;
    final g = GameState.fromJson(raw);
    if (g == null) {
      await widget.progress.clearSavedGame();
      if (mounted) setState(() {});
      return;
    }
    await _open(g, 'Continue');
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final fs = s.fontScale;
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final doneToday = widget.progress.isComplete(today);
    final streak = widget.progress.currentStreak;
    final saved = widget.progress.loadGame() != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Futoshiki'),
        actions: [
          IconButton(
            iconSize: 28,
            tooltip: 'How to play',
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => HowToPlayScreen(settings: s))),
          ),
          IconButton(
            iconSize: 28,
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                      settings: s,
                      progress: widget.progress,
                      iap: widget.iap)));
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            if (streak > 0)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🔥', style: TextStyle(fontSize: 28 * fs)),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                            '$streak day${streak == 1 ? "" : "s"} in a row',
                            style: TextStyle(
                                fontSize: 21 * fs,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            if (saved) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 78,
                child: OutlinedButton.icon(
                  onPressed: _resume,
                  icon: const Icon(Icons.play_circle_outline, size: 30),
                  label: Text('Continue puzzle',
                      style: TextStyle(
                          fontSize: 20 * fs, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: 92,
              child: FilledButton.icon(
                onPressed: _busy ? null : _playDaily,
                icon: Icon(doneToday ? Icons.replay : Icons.today, size: 32),
                label: Text(
                  doneToday ? 'Play today again' : "Today's Puzzle",
                  style:
                      TextStyle(fontSize: 23 * fs, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                doneToday
                    ? '✓ Finished today'
                    : '${DailyPuzzle.difficultyFor(today).label} · new puzzle every day',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15.5 * fs, color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 26),
            Text('Practice',
                style:
                    TextStyle(fontSize: 21 * fs, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...Difficulty.values.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: SizedBox(
                    height: 76,
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _playPractice(d),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(d.label,
                                    style: TextStyle(
                                        fontSize: 20 * fs,
                                        fontWeight: FontWeight.w700)),
                                Text('${d.blurb}  ·  ${d.size}×${d.size}',
                                    style: TextStyle(
                                        fontSize: 13.5 * fs,
                                        fontWeight: FontWeight.w400,
                                        color: scheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 30),
                        ],
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
