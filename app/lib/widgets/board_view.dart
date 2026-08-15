import 'package:flutter/material.dart';
import 'package:minedoku_engine/minedoku_engine.dart';

import '../theme.dart';
import 'mine_icon.dart';

/// The puzzle grid.
///
/// Cells are laid out by hand inside a [Stack] rather than with a `GridView`,
/// because the region outlines have to be painted across cell boundaries and
/// that is far easier with known pixel positions.
class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.board,
    required this.onTapCell,
    required this.onLongPressCell,
    this.conflictCells = const {},
    this.hintCell,
    this.relatedCells = const [],
    this.revealSolution = false,
  });

  final GameBoard board;
  final ValueChanged<int> onTapCell;
  final ValueChanged<int> onLongPressCell;
  final Set<int> conflictCells;
  final int? hintCell;

  /// The row, column or colour a hint is talking about. When this is set, every
  /// other cell is dimmed so the explanation has something to point at.
  final List<int> relatedCells;

  /// Dims everything except the answer. Used by the "show solution" action.
  final bool revealSolution;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final size = board.size;
    final spotlight = relatedCells.toSet();

    // A Container (not a DecoratedBox) so the 3px frame insets its child, and
    // the LayoutBuilder sits inside the frame so cells are measured against the
    // space actually available to them. Measuring outside the border overflows
    // the clip and shaves the last row and column.
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: MinedokuTheme.regionBorder(brightness),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cell = constraints.biggest.shortestSide / size;

              return SizedBox.expand(
                child: Stack(
                  children: [
                    for (var i = 0; i < size * size; i++)
                      Positioned(
                        left: (i % size) * cell,
                        top: (i ~/ size) * cell,
                        width: cell,
                        height: cell,
                        child: _Cell(
                          extent: cell,
                          regionColor: MinedokuTheme.regionColor(
                            board.puzzle.regions[i],
                          ),
                          mark: board.markAt(i),
                          inConflict: conflictCells.contains(i),
                          isHint: hintCell == i,
                          dimmed: (revealSolution &&
                                  !board.puzzle.solutionCells.contains(i)) ||
                              (spotlight.isNotEmpty &&
                                  !spotlight.contains(i) &&
                                  hintCell != i),
                          onTap: () => onTapCell(i),
                          onLongPress: () => onLongPressCell(i),
                          semanticLabel: 'Row ${i ~/ size + 1}, '
                              'column ${i % size + 1}',
                        ),
                      ),
                    // Painted last so region outlines sit above every cell.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _RegionOutlinePainter(
                            size: size,
                            regions: board.puzzle.regions,
                            regionLine: MinedokuTheme.regionBorder(brightness),
                            cellLine: MinedokuTheme.cellBorder(brightness),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.extent,
    required this.regionColor,
    required this.mark,
    required this.inConflict,
    required this.isHint,
    required this.dimmed,
    required this.onTap,
    required this.onLongPress,
    required this.semanticLabel,
  });

  final double extent;
  final Color regionColor;
  final CellMark mark;
  final bool inConflict;
  final bool isHint;
  final bool dimmed;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          opacity: dimmed ? 0.35 : 1,
          duration: const Duration(milliseconds: 250),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: regionColor),
              if (mark == CellMark.blocked)
                ColoredBox(color: MinedokuTheme.blockedOverlay(brightness)),
              Center(child: _content(context)),
              if (inConflict)
                Padding(
                  padding: const EdgeInsets.all(2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: MinedokuTheme.conflict,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              if (isHint)
                Padding(
                  padding: const EdgeInsets.all(2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: MinedokuTheme.hintGlow,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: child,
      ),
      child: switch (mark) {
        CellMark.mine => MineIcon(
            key: const ValueKey('mine'),
            size: extent * 0.62,
          ),
        CellMark.blocked => Icon(
            Icons.close_rounded,
            key: const ValueKey('blocked'),
            size: extent * 0.5,
            color: const Color(0xFF241E33).withValues(alpha: 0.5),
          ),
        CellMark.empty => const SizedBox.shrink(key: ValueKey('empty')),
      },
    );
  }
}

/// Draws the lines between cells: heavy where two regions meet, hairline
/// inside a region.
///
/// Each internal edge is drawn exactly once (from the cell below or to the
/// right of it) so shared borders do not come out double-weight.
class _RegionOutlinePainter extends CustomPainter {
  const _RegionOutlinePainter({
    required this.size,
    required this.regions,
    required this.regionLine,
    required this.cellLine,
  });

  final int size;
  final List<int> regions;
  final Color regionLine;
  final Color cellLine;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final cell = canvasSize.width / size;
    final heavy = Paint()
      ..color = regionLine
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square;
    final light = Paint()
      ..color = cellLine
      ..strokeWidth = 1;

    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        final index = row * size + col;
        final x = col * cell;
        final y = row * cell;

        if (row > 0) {
          final differs = regions[index - size] != regions[index];
          canvas.drawLine(
            Offset(x, y),
            Offset(x + cell, y),
            differs ? heavy : light,
          );
        }
        if (col > 0) {
          final differs = regions[index - 1] != regions[index];
          canvas.drawLine(
            Offset(x, y),
            Offset(x, y + cell),
            differs ? heavy : light,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_RegionOutlinePainter oldDelegate) =>
      oldDelegate.size != size ||
      oldDelegate.regions != regions ||
      oldDelegate.regionLine != regionLine;
}
