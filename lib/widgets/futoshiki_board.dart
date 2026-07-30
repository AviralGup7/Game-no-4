/// The Futoshiki board, custom-painted.
///
/// The layout problem unique to futoshiki: inequality signs live BETWEEN
/// cells, not inside them. So the board is not an NxN grid of equal cells -
/// it is N cells plus N-1 narrow gutters in each direction. Cells get the
/// lion's share of the space (they hold the numerals, which must stay large);
/// gutters get just enough for a legible chevron.
///
/// CustomPainter rather than many widgets: one repaint for the whole board,
/// which matters on the low-end hardware this audience often uses.
library;

import 'package:flutter/material.dart';
import '../models/game_state.dart';
import 'app_theme.dart';

/// Fraction of a cell's width used by the sign gutter.
const double kGutterRatio = 0.34;

class FutoshikiBoard extends StatelessWidget {
  final GameState game;
  final double fontScale;
  final bool highContrast;
  final bool highlightPeers;
  final bool showMistakes;
  final int? hintIndex;
  final ValueChanged<int> onTapCell;

  const FutoshikiBoard({
    super.key,
    required this.game,
    required this.fontScale,
    required this.highContrast,
    required this.highlightPeers,
    required this.showMistakes,
    required this.onTapCell,
    this.hintIndex,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = game.puzzle.size;

    return LayoutBuilder(
      builder: (context, c) {
        final side = c.biggest.shortestSide;
        // side = n*cell + (n-1)*gutter, gutter = cell*kGutterRatio
        final cell = side / (n + (n - 1) * kGutterRatio);
        final gutter = cell * kGutterRatio;
        final step = cell + gutter;

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                // Map a tap to the nearest CELL, treating gutters as belonging
                // to the cell before them. An older player aiming at a small
                // square should not have their tap swallowed by a gap.
                int col = (d.localPosition.dx / step).floor().clamp(0, n - 1);
                int row = (d.localPosition.dy / step).floor().clamp(0, n - 1);
                onTapCell(row * n + col);
              },
              child: CustomPaint(
                painter: _BoardPainter(
                  game: game,
                  scheme: scheme,
                  fontScale: fontScale,
                  highContrast: highContrast,
                  highlightPeers: highlightPeers,
                  showMistakes: showMistakes,
                  hintIndex: hintIndex,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BoardPainter extends CustomPainter {
  final GameState game;
  final ColorScheme scheme;
  final double fontScale;
  final bool highContrast;
  final bool highlightPeers;
  final bool showMistakes;
  final int? hintIndex;

  _BoardPainter({
    required this.game,
    required this.scheme,
    required this.fontScale,
    required this.highContrast,
    required this.highlightPeers,
    required this.showMistakes,
    this.hintIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = game.puzzle;
    final n = p.size;
    final cell = size.width / (n + (n - 1) * kGutterRatio);
    final gutter = cell * kGutterRatio;
    final step = cell + gutter;

    Rect rectOf(int i) => Rect.fromLTWH(
        (i % n) * step, (i ~/ n) * step, cell, cell);

    final sel = game.selected;
    final selValue = sel >= 0 ? game.entries[sel] : 0;
    final peers = <int>{};
    if (sel >= 0 && highlightPeers) {
      final sr = sel ~/ n, sc = sel % n;
      for (int k = 0; k < n; k++) {
        peers..add(sr * n + k)..add(k * n + sc);
      }
    }
    final wrong = showMistakes ? game.wrongCells : const <int>{};

    canvas.drawRect(Offset.zero & size, Paint()..color = scheme.surface);

    // ---- cells ----
    for (int i = 0; i < p.cellCount; i++) {
      final r = rectOf(i);

      Color? fill;
      if (peers.contains(i)) fill = AppTheme.peerFill(scheme);
      // Same-value highlight beats peer highlight: it is the stronger signal.
      if (selValue != 0 && game.entries[i] == selValue) {
        fill = AppTheme.sameValueFill(scheme);
      }
      if (i == sel) fill = AppTheme.selectedFill(scheme);
      if (i == hintIndex) fill = AppTheme.hintFill(scheme);

      final rr = RRect.fromRectAndRadius(r, Radius.circular(cell * 0.10));
      if (fill != null) canvas.drawRRect(rr, Paint()..color = fill);
      canvas.drawRRect(
        rr,
        Paint()
          ..color = highContrast
              ? scheme.outline
              : scheme.onSurface.withValues(alpha: .55)
          ..strokeWidth = highContrast ? 2.4 : 1.6
          ..style = PaintingStyle.stroke,
      );

      final v = game.entries[i];
      if (v != 0) {
        final given = p.isGiven(i);
        final isWrong = wrong.contains(i);
        final colour = isWrong
            ? AppTheme.wrongText(scheme)
            : given
                ? AppTheme.givenText(scheme)
                : AppTheme.enteredText(scheme);
        _text(canvas, '$v', r.center, cell * 0.58 * fontScale, colour,
            given ? FontWeight.w800 : FontWeight.w600);
        if (isWrong) {
          // Underline too: never signal an error by colour alone.
          final w = cell * 0.34;
          canvas.drawLine(
            Offset(r.center.dx - w / 2, r.center.dy + cell * 0.29),
            Offset(r.center.dx + w / 2, r.center.dy + cell * 0.29),
            Paint()
              ..color = AppTheme.wrongText(scheme)
              ..strokeWidth = 2.5,
          );
        }
      } else if (game.notes[i].isNotEmpty) {
        final per = n <= 4 ? 2 : 3;
        for (final note in game.notes[i]) {
          final k = note - 1;
          final nr = k ~/ per, nc = k % per;
          final gapx = cell / (per + 1), gapy = cell / (per + 1);
          final np = Offset(r.left + gapx * (nc + 1), r.top + gapy * (nr + 1));
          _text(canvas, '$note', np, cell * 0.20 * fontScale,
              scheme.onSurface.withValues(alpha: .60), FontWeight.w600);
        }
      }
    }

    // ---- inequality signs, drawn in the gutters ----
    final signPaint = Paint()
      ..color = AppTheme.signColour(scheme)
      ..strokeWidth = (cell * 0.075).clamp(2.5, 6.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final con in p.constraints) {
      final a = con.hi < con.lo ? con.hi : con.lo;
      final b = con.hi < con.lo ? con.lo : con.hi;
      final horizontal = (b - a) == 1;
      final ra = rectOf(a);
      // Chevron points toward the SMALLER value, like the mouth of < opening
      // to the larger - the convention every printed futoshiki uses.
      final pointsToB = con.hi == a;

      if (horizontal) {
        final cx = ra.right + gutter / 2;
        final cy = ra.center.dy;
        _chevron(canvas, Offset(cx, cy), gutter * 0.30, signPaint,
            horizontal: true, pointsForward: pointsToB);
      } else {
        final cx = ra.center.dx;
        final cy = ra.bottom + gutter / 2;
        _chevron(canvas, Offset(cx, cy), gutter * 0.30, signPaint,
            horizontal: false, pointsForward: pointsToB);
      }
    }
  }

  /// A ">" style chevron. [pointsForward] means the apex points right (or
  /// down), i.e. the FIRST cell is the larger one.
  void _chevron(Canvas canvas, Offset c, double s, Paint paint,
      {required bool horizontal, required bool pointsForward}) {
    final path = Path();
    if (horizontal) {
      final dx = pointsForward ? s : -s;
      path.moveTo(c.dx - dx, c.dy - s);
      path.lineTo(c.dx + dx, c.dy);
      path.lineTo(c.dx - dx, c.dy + s);
    } else {
      final dy = pointsForward ? s : -s;
      path.moveTo(c.dx - s, c.dy - dy);
      path.lineTo(c.dx, c.dy + dy);
      path.lineTo(c.dx + s, c.dy - dy);
    }
    canvas.drawPath(path, paint);
  }

  void _text(Canvas canvas, String s, Offset centre, double size, Color colour,
      FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          color: colour,
          fontWeight: weight,
          height: 1.0,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(centre.dx - tp.width / 2, centre.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
