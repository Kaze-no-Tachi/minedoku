import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:minedoku_engine/minedoku_engine.dart';

import '../theme/app_theme.dart';

/// The puzzle grid.
///
/// The whole board is drawn by one painter rather than a tree of widgets. Cell
/// surfaces, accessibility patterns, markers and region outlines all have to
/// line up on shared edges, and a painter with the full geometry in hand is far
/// easier to keep consistent than per-cell borders that meet in the middle. It
/// also keeps a 9x9 board at 81 painted rects instead of hundreds of widgets.
///
/// A transparent [GestureDetector] grid sits on top purely for hit testing.
class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.board,
    required this.theme,
    required this.onTapCell,
    required this.onLongPressCell,
    this.showPatterns = false,
    this.conflictCells = const {},
    this.hintCell,
    this.relatedCells = const [],
    this.interactive = true,
  });

  final GameBoard board;
  final GameTheme theme;
  final ValueChanged<int> onTapCell;
  final ValueChanged<int> onLongPressCell;

  /// Draws a distinct texture per region, the accessible channel that works
  /// regardless of how the player perceives colour.
  final bool showPatterns;

  final Set<int> conflictCells;
  final int? hintCell;

  /// The row, column or colour a hint is talking about. When set, every other
  /// cell dims so the explanation has something to point at.
  final List<int> relatedCells;

  /// False for decorative boards, such as the one behind the title screen.
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final size = board.size;

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(theme.cornerRadius),
          border: Border.all(color: theme.boardOutline, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(theme.cornerRadius - 3),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cell = constraints.biggest.shortestSide / size;

              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BoardPainter(
                        board: board,
                        theme: theme,
                        showPatterns: showPatterns,
                        blockedWash: AppTheme.blockedOverlay(brightness),
                        conflictCells: conflictCells,
                        hintCell: hintCell,
                        dimmedCells: _dimmed(),
                      ),
                    ),
                  ),
                  if (interactive)
                    for (var i = 0; i < size * size; i++)
                      Positioned(
                        left: (i % size) * cell,
                        top: (i ~/ size) * cell,
                        width: cell,
                        height: cell,
                        child: Semantics(
                          // The mark is part of the label so a screen reader
                          // can read the board, not just locate it.
                          label: 'Row ${i ~/ size + 1}, '
                              'column ${i % size + 1}, '
                              '${_describe(board.markAt(i))}',
                          button: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onTapCell(i),
                            onLongPress: () => onLongPressCell(i),
                          ),
                        ),
                      ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static String _describe(CellMark mark) => switch (mark) {
        CellMark.empty => 'empty',
        CellMark.blocked => 'ruled out',
        CellMark.maybe => 'unsure',
        CellMark.mine => 'mine placed',
      };

  Set<int> _dimmed() {
    if (relatedCells.isEmpty) return const {};
    final spotlight = relatedCells.toSet();
    return {
      for (var i = 0; i < board.size * board.size; i++)
        if (!spotlight.contains(i) && i != hintCell) i,
    };
  }
}

class _BoardPainter extends CustomPainter {
  const _BoardPainter({
    required this.board,
    required this.theme,
    required this.showPatterns,
    required this.blockedWash,
    required this.conflictCells,
    required this.hintCell,
    required this.dimmedCells,
  });

  final GameBoard board;
  final GameTheme theme;
  final bool showPatterns;
  final Color blockedWash;
  final Set<int> conflictCells;
  final int? hintCell;
  final Set<int> dimmedCells;

  @override
  void paint(Canvas canvas, Size size) {
    final n = board.size;
    final unit = size.width / n;

    for (var i = 0; i < n * n; i++) {
      final rect = Rect.fromLTWH(
        (i % n) * unit,
        (i ~/ n) * unit,
        unit,
        unit,
      );
      // Dimming happens per cell rather than over the whole board, so the
      // spotlit region keeps its full colour while the rest recedes.
      final dim = dimmedCells.contains(i);
      if (dim) canvas.saveLayer(rect, Paint()..color = const Color(0x4DFFFFFF));

      CellArt.paintSurface(
        canvas,
        rect,
        fill: theme.regionColor(board.puzzle.regions[i]),
        surface: theme.surface,
      );

      if (showPatterns) {
        RegionPattern.forRegion(board.puzzle.regions[i])
            .paint(canvas, rect, theme.patternColor, unit);
      }

      final mark = board.markAt(i);
      if (mark == CellMark.maybe) {
        // No wash: an unsure cell is undecided, not ruled out.
        CellArt.paintMaybe(
          canvas,
          rect,
          color: theme.glyphColor.withValues(alpha: 0.75),
        );
      } else if (mark == CellMark.blocked) {
        canvas.drawRect(rect, Paint()..color = blockedWash);
        CellArt.paintBlocked(
          canvas,
          rect,
          glyph: theme.blockedGlyph,
          color: theme.glyphColor.withValues(alpha: 0.55),
        );
      } else if (mark == CellMark.mine) {
        CellArt.paintMine(
          canvas,
          rect,
          glyph: theme.mineGlyph,
          color: theme.glyphColor,
        );
      }

      if (conflictCells.contains(i)) {
        _outline(canvas, rect, AppTheme.conflict);
      } else if (hintCell == i) {
        _outline(canvas, rect, AppTheme.hintGlow);
      }

      if (dim) canvas.restore();
    }

    _paintGrid(canvas, unit, n);
  }

  void _outline(Canvas canvas, Rect rect, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(2.5), const Radius.circular(4)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  /// Heavy lines where two regions meet, hairlines inside a region.
  ///
  /// Each internal edge is drawn exactly once, from the cell below or to the
  /// right of it, so shared borders never come out double weight.
  void _paintGrid(Canvas canvas, double unit, int n) {
    final heavy = Paint()
      ..color = theme.boardOutline
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square;
    final light = Paint()
      ..color = theme.gridLine
      ..strokeWidth = 1;

    for (var row = 0; row < n; row++) {
      for (var col = 0; col < n; col++) {
        final index = row * n + col;
        final x = col * unit;
        final y = row * unit;

        if (row > 0) {
          final differs =
              board.puzzle.regions[index - n] != board.puzzle.regions[index];
          canvas.drawLine(
            Offset(x, y),
            Offset(x + unit, y),
            differs ? heavy : light,
          );
        }
        if (col > 0) {
          final differs =
              board.puzzle.regions[index - 1] != board.puzzle.regions[index];
          canvas.drawLine(
            Offset(x, y),
            Offset(x, y + unit),
            differs ? heavy : light,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.theme.id != theme.id ||
      old.showPatterns != showPatterns ||
      old.hintCell != hintCell ||
      old.blockedWash != blockedWash ||
      !setEquals(old.conflictCells, conflictCells) ||
      !setEquals(old.dimmedCells, dimmedCells) ||
      !listEquals(old.board.marks, board.marks) ||
      !listEquals(old.board.puzzle.regions, board.puzzle.regions);
}
