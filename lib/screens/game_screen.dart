library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine/futoshiki_engine.dart';
import '../models/game_state.dart';
import '../services/settings.dart';
import '../services/progress.dart';
import '../services/ads.dart';
import '../widgets/futoshiki_board.dart';

class GameScreen extends StatefulWidget {
  final GameState game;
  final Settings settings;
  final Progress progress;
  final AdService ads;
  final DateTime? dailyDate;
  final String title;

  const GameScreen({
    super.key,
    required this.game,
    required this.settings,
    required this.progress,
    required this.ads,
    required this.title,
    this.dailyDate,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  Timer? _timer;
  int? _hintIndex;
  bool _finished = false;
  late final AnimationController _shake;

  GameState get g => widget.game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shake = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    // Elapsed only, never a countdown. Time pressure is the most common
    // complaint from older players.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _finished) return;
      setState(() => g.elapsedSeconds++);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _startTimer();
    } else {
      _timer?.cancel();
      _save();
    }
  }

  Future<void> _save() async {
    if (_finished) return;
    await widget.progress.saveGame(g.toJson());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shake.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _haptic(bool ok) {
    if (!widget.settings.haptics) return;
    ok ? HapticFeedback.selectionClick() : HapticFeedback.mediumImpact();
  }

  void _tapCell(int i) {
    setState(() {
      g.selected = i;
      _hintIndex = null;
    });
    if (widget.settings.haptics) HapticFeedback.selectionClick();
  }

  void _enter(int v) {
    final sel = g.selected;
    if (sel < 0) {
      _toast('Tap a square first');
      return;
    }
    if (!g.isEditable(sel)) {
      _toast('That number was given to you');
      return;
    }
    setState(() {
      if (g.noteMode) {
        g.toggleNote(sel, v);
        _haptic(true);
      } else {
        final wrong = g.place(sel, v);
        _haptic(!wrong);
        if (wrong) _shake.forward(from: 0);
      }
      _hintIndex = null;
    });
    if (g.isSolved) _win();
    _save();
  }

  void _erase() {
    if (g.selected < 0) return;
    setState(() => g.erase(g.selected));
    _haptic(true);
    _save();
  }

  void _undo() {
    if (!g.canUndo) return;
    setState(g.undo);
    _haptic(true);
    _save();
  }

  Future<void> _hint() async {
    final h = g.nextHint();
    if (h == null) return;
    final granted = await widget.ads.showRewarded(context);
    if (!granted || !mounted) return;
    setState(() {
      g.place(h.index, h.value);
      g.hintsUsed++;
      g.selected = h.index;
      _hintIndex = h.index;
    });
    _haptic(true);
    if (!mounted) return;
    // Explain the deduction, so a hint teaches rather than just fills a gap.
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(h.explanation, style: const TextStyle(fontSize: 16)),
        duration: const Duration(seconds: 6),
      ));
    if (g.isSolved) _win();
    _save();
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
          content: Text(m, style: const TextStyle(fontSize: 17)),
          duration: const Duration(seconds: 2)));
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Future<void> _win() async {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    await widget.progress.clearSavedGame();

    final key = g.puzzle.difficulty.label;
    if (widget.dailyDate != null) {
      await widget.progress.markComplete(widget.dailyDate!,
          seconds: g.elapsedSeconds, difficultyKey: key);
    } else {
      await widget.progress.recordPractice(g.elapsedSeconds, key);
    }
    if (!mounted) return;

    final streak = widget.progress.currentStreak;
    final best = widget.progress.bestTimes[key];
    final isBest = best != null && g.elapsedSeconds <= best;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Solved!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 10),
            Text('Time  ${_fmt(g.elapsedSeconds)}',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            if (isBest)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Your best yet!',
                    style: TextStyle(fontSize: 18, color: Color(0xFF2E7D32))),
              ),
            const SizedBox(height: 8),
            Text('Mistakes ${g.mistakes}   ·   Hints ${g.hintsUsed}',
                style: const TextStyle(fontSize: 16)),
            if (widget.dailyDate != null && streak > 0) ...[
              const SizedBox(height: 12),
              Text('$streak day${streak == 1 ? "" : "s"} in a row 🔥',
                  style: const TextStyle(
                      fontSize: 21, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
    widget.ads.maybeShowInterstitial();
  }

  Future<bool> _confirmLeave() async {
    if (_finished || g.filledCount == g.puzzle.givenCount) return true;
    await _save();
    if (!mounted) return true;
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave this puzzle?'),
        content: const Text(
            'Your progress is saved. You can carry on from the main screen.',
            style: TextStyle(fontSize: 17)),
        actions: [
          OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep playing')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Leave')),
        ],
      ),
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final scheme = Theme.of(context).colorScheme;
    final fs = s.fontScale;
    final landscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    final board = Padding(
      padding: const EdgeInsets.all(10),
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          final dx = _shake.isAnimating
              ? (1 - _shake.value) * 8 * (1 - 2 * ((_shake.value * 4) % 1))
              : 0.0;
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: FutoshikiBoard(
          game: g,
          fontScale: fs,
          highContrast: s.highContrast,
          highlightPeers: s.highlightPeers,
          showMistakes: s.showMistakes,
          hintIndex: _hintIndex,
          onTapCell: _tapCell,
        ),
      ),
    );

    final controls = _Controls(
      game: g,
      fontScale: fs,
      onNumber: _enter,
      onErase: _erase,
      onUndo: _undo,
      onHint: _hint,
      onToggleNotes: () {
        setState(() => g.noteMode = !g.noteMode);
        _haptic(true);
      },
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (!leave || !mounted) return;
        Navigator.of(this.context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Text(
                  _fmt(g.elapsedSeconds),
                  style: TextStyle(
                    fontSize: 19 * fs,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: .75),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: landscape
              ? Row(children: [
                  Expanded(flex: 5, child: board),
                  Expanded(
                      flex: 4, child: SingleChildScrollView(child: controls)),
                ])
              : Column(children: [
                  Expanded(child: board),
                  controls,
                ]),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final GameState game;
  final double fontScale;
  final ValueChanged<int> onNumber;
  final VoidCallback onErase, onUndo, onHint, onToggleNotes;

  const _Controls({
    required this.game,
    required this.fontScale,
    required this.onNumber,
    required this.onErase,
    required this.onUndo,
    required this.onHint,
    required this.onToggleNotes,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = game.puzzle.size;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _action(context, Icons.undo, 'Undo', game.canUndo ? onUndo : null),
              _action(context, Icons.backspace_outlined, 'Erase', onErase),
              _action(
                  context,
                  game.noteMode ? Icons.edit_note : Icons.edit_outlined,
                  'Notes',
                  onToggleNotes,
                  active: game.noteMode),
              _action(context, Icons.lightbulb_outline, 'Hint', onHint),
            ],
          ),
          const SizedBox(height: 8),
          // Only 1..N keys - a 5x5 futoshiki has no 6. Showing keys that can
          // never be used would be a small but constant source of confusion.
          LayoutBuilder(builder: (context, c) {
            final gap = 6.0;
            final w = (c.maxWidth - gap * (n - 1)) / n;
            final h = (w * 1.15).clamp(56.0, 84.0);
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(n, (k) {
                final v = k + 1;
                final done = game.isExhausted(v);
                return SizedBox(
                  width: w,
                  height: h,
                  child: Semantics(
                    label: done ? 'Number $v, all placed' : 'Number $v',
                    button: true,
                    child: Material(
                      color: done
                          ? scheme.surfaceContainerHighest.withValues(alpha: .35)
                          : scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: done ? null : () => onNumber(v),
                        child: Center(
                          child: Text('$v',
                              style: TextStyle(
                                fontSize:
                                    (w * 0.46).clamp(22.0, 38.0) * fontScale,
                                fontWeight: FontWeight.w700,
                                color: done
                                    ? scheme.onSurface.withValues(alpha: .28)
                                    : scheme.onPrimaryContainer,
                              )),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _action(BuildContext context, IconData icon, String label,
      VoidCallback? onTap,
      {bool active = false}) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = onTap == null;
    return Expanded(
      child: Semantics(
        button: true,
        enabled: !disabled,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 62),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: active ? scheme.secondaryContainer : Colors.transparent,
              border: Border.all(
                  color: active ? scheme.secondary : scheme.outlineVariant,
                  width: active ? 2 : 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 26,
                    color: disabled
                        ? scheme.onSurface.withValues(alpha: .3)
                        : scheme.onSurface),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(
                        fontSize: 12.5 * fontScale,
                        fontWeight: FontWeight.w600,
                        color: disabled
                            ? scheme.onSurface.withValues(alpha: .3)
                            : scheme.onSurface)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
