import 'package:flutter/material.dart';

import '../../domain/board_state.dart';
import '../../domain/case_definition.dart';
import '../../domain/solution_evaluation.dart';
import '../board/board_scene.dart';
import '../design/murdoku_tokens.dart';
import '../session/game_progress_store.dart';

// These are the current attempt's states, not a second completion record.
enum CaseAttemptStatus { notStarted, inProgress, solved, unavailable }

CaseAttemptStatus caseAttemptStatus(
  GameProgress? progress, {
  bool unavailable = false,
}) {
  if (unavailable) return CaseAttemptStatus.unavailable;
  if (progress == null || !progress.attemptStarted) {
    return CaseAttemptStatus.notStarted;
  }
  return progress.isSolved
      ? CaseAttemptStatus.solved
      : CaseAttemptStatus.inProgress;
}

class CasePreview extends StatelessWidget {
  const CasePreview({
    super.key,
    required this.caseData,
    this.boardState,
    this.feedbackByCell = const {},
    this.isSolved = false,
  });

  final CaseDefinition caseData;
  final BoardState? boardState;
  final Map<CellPosition, PlacementVerdict> feedbackByCell;
  final bool isSolved;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      // A preview is only a picture of the current board. The surrounding
      // card is the tap target; no gestures or duplicate game state here.
      child: AspectRatio(
        aspectRatio: caseData.columns / caseData.rows,
        child: LayoutBuilder(
          builder: (context, constraints) => ClipRRect(
            borderRadius: BorderRadius.circular(MurdokuTokens.space4),
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSolved
                      ? MurdokuTokens.boardCorrect
                      : MurdokuTokens.boardRoomWall,
                  width: MurdokuTokens.borderWidth,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  BoardScene(
                    caseData: caseData,
                    cellSize: constraints.maxWidth / caseData.columns,
                    boardState: boardState,
                    feedbackByCell: feedbackByCell,
                  ),
                  if (isSolved)
                    ColoredBox(
                      color: const Color(0xAA10241D),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(MurdokuTokens.space4),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'CASE SOLVED',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: MurdokuTokens.boardCorrect,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
