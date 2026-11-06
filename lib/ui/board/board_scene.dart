import 'package:flutter/material.dart';

import '../../domain/board_state.dart';
import '../../domain/case_definition.dart';
import '../../domain/solution_evaluation.dart';
import '../design/murdoku_assets.dart';
import 'board_scene_painter.dart';

/// The same board layers are used in the game, minimap and case cards.
class BoardScene extends StatelessWidget {
  const BoardScene({
    super.key,
    required this.caseData,
    required this.cellSize,
    this.originRow = 0,
    this.originColumn = 0,
    this.translation = Offset.zero,
    this.boardState,
    this.feedbackByCell = const {},
    this.viewportOutline,
    this.holdCell,
    this.holdProgress = 0,
    this.paintCrosses = true,
    this.child,
  });

  final CaseDefinition caseData;
  final double cellSize;
  final int originRow;
  final int originColumn;
  final Offset translation;
  final BoardState? boardState;
  final Map<CellPosition, PlacementVerdict> feedbackByCell;
  final Rect? viewportOutline;
  final CellPosition? holdCell;
  final double holdProgress;
  final bool paintCrosses;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final background = MurdokuAssets.boardBackground(caseData.id);
    final painter = BoardScenePainter(
      caseData: caseData,
      cellSize: cellSize,
      originRow: originRow,
      originColumn: originColumn,
      translation: translation,
      boardState: boardState,
      feedbackByCell: feedbackByCell,
      viewportOutline: viewportOutline,
      holdCell: holdCell,
      holdProgress: holdProgress,
      paintCrosses: paintCrosses,
      paintStaticScene: background == null,
    );
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        if (background != null)
          Positioned(
            // The PNG is the entire grid, not the current viewport. Moving
            // it by exactly the same cell offset keeps taps and marks aligned.
            left: translation.dx - originColumn * cellSize,
            top: translation.dy - originRow * cellSize,
            width: caseData.columns * cellSize,
            height: caseData.rows * cellSize,
            child: IgnorePointer(
              child: Image.asset(
                background,
                key: ValueKey('board-art-${caseData.id}'),
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
                errorBuilder: (context, error, stack) {
                  // If an image goes missing, keep the board playable instead
                  // of hiding it. The old grid painter is the fallback only.
                  assert(() {
                    debugPrint('Missing board artwork: $background ($error)');
                    return true;
                  }());
                  return CustomPaint(
                    painter: BoardScenePainter(
                      caseData: caseData,
                      cellSize: cellSize,
                      paintAnnotations: false,
                    ),
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
          ),
        Positioned.fill(
          child: CustomPaint(
            painter: painter,
            child: child ?? const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}
