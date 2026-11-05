import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'domain/board_actions.dart';
import 'domain/board_state.dart';
import 'domain/solution_evaluation.dart';
import 'session/game_session.dart';

// Static replay snapshots for the temporary domain smoke test
typedef SmokeStep = ({String title, BoardState board});

// Temporary editing modes for the live gameplay debugger
enum DebugTool { cross, noteA, noteB, placeA, placeB, placeV, erase }

// Smoke-test assertions cover immutable transformations and rejected actions
void main() {
  final original = BoardState.empty(6, 6);
  final position = (row: 2, column: 3);

  final noteA = toggleNote(original, position, 'suspectA');
  final notesAB = toggleNote(noteA, position, 'suspectB');

  assert(notesAB.cellAt(position).notes.length == 2);
  assert(notesAB.cellAt(position).notes.contains('suspectA'));
  assert(notesAB.cellAt(position).notes.contains('suspectB'));
  assert(original.cellAt(position).isEmpty);

  final crossed = toggleCross(notesAB, position);

  assert(crossed.cellAt(position).crossed);
  assert(crossed.cellAt(position).notes.isEmpty);
  assert(notesAB.cellAt(position).notes.length == 2);

  final blockedNote = toggleNote(crossed, position, 'suspectA');

  assert(identical(blockedNote, crossed));

  final cleared = toggleCross(crossed, position);
  final renoted = toggleNote(cleared, position, 'suspectB');

  assert(cleared.cellAt(position).isEmpty);
  assert(
    renoted.cellAt(position).notes == {'suspectB'} ||
        (renoted.cellAt(position).notes.length == 1 &&
            renoted.cellAt(position).notes.contains('suspectB')),
  );

  final placed = placeCharacter(renoted, position, 'suspectA');

  assert(placed.cellAt(position).characterId == 'suspectA');
  assert(placed.cellAt(position).notes.isEmpty);

  assert(placed.cellAt((row: 2, column: 0)).crossed);
  assert(placed.cellAt((row: 0, column: 3)).crossed);

  assert(placed.cellAt((row: 0, column: 0)).isEmpty);

  final blockedCross = toggleCross(placed, position);

  assert(identical(blockedCross, placed));

  // Deliberate debugging sequence for manual cross clearing and same-row placement
  final secondPosition = (row: 2, column: 5);
  final available = toggleCross(placed, secondPosition);
  final secondPlaced = placeCharacter(available, secondPosition, 'suspectB');

  assert(secondPlaced.cellAt(position).characterId == 'suspectA');
  assert(secondPlaced.cellAt(secondPosition).characterId == 'suspectB');

  final erased = eraseCell(secondPlaced, position);

  assert(erased.cellAt(position).isEmpty);

  assert(erased.cellAt((row: 2, column: 0)).crossed);
  assert(erased.cellAt((row: 0, column: 3)).crossed);

  assert(secondPlaced.cellAt(position).characterId == 'suspectA');
  assert(original.cellAt(position).isEmpty);

  if (kDebugMode) {
    print('WP-01B: All board-action assertions passed!');
  }

  runApp(
    MyApp(
      steps: [
        (title: 'Empty board', board: original),
        (title: 'Add note A', board: noteA),
        (title: 'Combine notes A + B', board: notesAB),
        (title: 'Cross overwrites notes', board: crossed),
        (title: 'Note blocked by cross', board: blockedNote),
        (title: 'Remove cross', board: cleared),
        (title: 'Add note B again', board: renoted),
        (title: 'Place character A', board: placed),
        (title: 'Cross blocked by character', board: blockedCross),
        (title: 'Clear a cross in the row', board: available),
        (title: 'Place character B', board: secondPlaced),
        (title: 'Erase character A', board: erased),
      ],
    ),
  );
}

// Debug-only presentation outside the case-driven gameplay UI
class MyApp extends StatelessWidget {
  final List<SmokeStep> steps;

  const MyApp({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Murdoku Domain Test',
      debugShowCheckedModeBanner: false,
      home: SmokeTestScreen(steps: steps),
    );
  }
}


class SmokeTestScreen extends StatefulWidget {
  final List<SmokeStep> steps;

  const SmokeTestScreen({super.key, required this.steps});

  @override
  State<SmokeTestScreen> createState() => _SmokeTestScreenState();
}

class _SmokeTestScreenState extends State<SmokeTestScreen> {
  int stepIndex = 0;
  bool liveMode = false;
  DebugTool selectedTool = DebugTool.cross;
  String message = 'Select a tool and tap a cell.';

  // Synthetic reference solution independent of authored case JSON
  final CaseSolution debugSolution = CaseSolution(
    rows: 6,
    columns: 6,
    characterPositions: {
      'suspectA': (row: 1, column: 1),
      'suspectB': (row: 3, column: 3),
      'victim': (row: 4, column: 5),
    },
  );

  late GameSession game;

  @override
  void initState() {
    super.initState();
    game = createGame();
  }

  GameSession createGame() {
    return GameSession(
      initialBoard: BoardState.empty(debugSolution.rows, debugSolution.columns),
      solution: debugSolution,
    );
  }

  String toolLabel(DebugTool tool) {
    return switch (tool) {
      DebugTool.cross => 'Cross',
      DebugTool.noteA => 'Note A',
      DebugTool.noteB => 'Note B',
      DebugTool.placeA => 'Place A',
      DebugTool.placeB => 'Place B',
      DebugTool.placeV => 'Place V',
      DebugTool.erase => 'Eraser',
    };
  }

  String? placementId(DebugTool tool) {
    return switch (tool) {
      DebugTool.placeA => 'suspectA',
      DebugTool.placeB => 'suspectB',
      DebugTool.placeV => 'victim',
      _ => null,
    };
  }

  bool characterPlaced(String characterId) {
    final board = game.board;

    for (var row = 0; row < board.rows; row++) {
      for (var column = 0; column < board.columns; column++) {
        if (board.cellAt((row: row, column: column)).characterId ==
            characterId) {
          return true;
        }
      }
    }

    return false;
  }

  // Gameplay commands routed through GameSession for feedback consistency
  void applyTool(CellPosition position) {
    final changed = switch (selectedTool) {
      DebugTool.cross => game.toggleCross(position),
      DebugTool.noteA => game.toggleNote(position, 'suspectA'),
      DebugTool.noteB => game.toggleNote(position, 'suspectB'),
      DebugTool.placeA => game.placeCharacter(position, 'suspectA'),
      DebugTool.placeB => game.placeCharacter(position, 'suspectB'),
      DebugTool.placeV => game.placeCharacter(position, 'victim'),
      DebugTool.erase => game.eraseCell(position),
    };

    setState(() {
      message = changed
          ? '${toolLabel(selectedTool)} at '
                '(${position.row}, ${position.column})'
          : 'No change at '
                '(${position.row}, ${position.column})';

      if (changed && placementId(selectedTool) != null) {
        selectedTool = DebugTool.cross;
      }
    });
  }

  void undoAction() {
    if (!game.undo()) return;

    setState(() {
      message = 'Restored board; invalidated feedback stays cleared.';
    });
  }

  void clearBoard() {
    if (!game.clearAll()) return;

    setState(() {
      selectedTool = DebugTool.cross;
      message = 'Board, feedback and Undo history cleared.';
    });
  }

  // Submit remains explicit even after all characters are placed
  void submitBoard() {
    if (!game.canSubmit) return;

    final result = game.submit();

    setState(() {
      if (result.solved) {
        message = 'SOLVED! Board locked.';
      } else {
        final incorrectCount = result.feedbackByCell.values
            .where((value) => value == PlacementVerdict.incorrect)
            .length;

        message =
            'Incorrect submission: '
            '$incorrectCount misplaced character(s).';
      }
    });
  }

  // New attempt replaces the solved session with fresh board and feedback state
  void newAttempt() {
    setState(() {
      game = createGame();
      selectedTool = DebugTool.cross;
      message = 'New attempt started.';
    });
  }

  String cellLabel(CellState cell) {
    if (cell.characterId == 'victim') {
      return 'V';
    }

    if (cell.characterId != null) {
      return cell.characterId!.replaceFirst('suspect', '');
    }

    if (cell.crossed) {
      return 'X';
    }

    return cell.notes.map((id) => id.replaceFirst('suspect', '')).join(' ');
  }

  Color cellColor(CellState cell, PlacementVerdict? verdict) {
    if (verdict == PlacementVerdict.correct) {
      return Colors.green.shade100;
    }

    if (verdict == PlacementVerdict.incorrect) {
      return Colors.red.shade200;
    }

    if (cell.characterId != null) {
      return Colors.teal.shade100;
    }

    if (cell.crossed) {
      return Colors.red.shade100;
    }

    if (cell.notes.isNotEmpty) {
      return Colors.amber.shade100;
    }

    return Colors.grey.shade200;
  }

  // Board rendering derived from immutable snapshots and current feedback
  Widget buildBoard(BoardState board) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;

        return Center(
          child: SizedBox.square(
            dimension: side,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: board.columns,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: board.rows * board.columns,
              itemBuilder: (context, index) {
                // Row-major indexing consistent with JSON room and object grids
                final position = (
                  row: index ~/ board.columns,
                  column: index % board.columns,
                );

                final cell = board.cellAt(position);

                // Feedback shown only for live gameplay and never for static replay
                final verdict = liveMode ? game.feedbackByCell[position] : null;

                return Material(
                  color: cellColor(cell, verdict),
                  child: InkWell(
                    onTap: liveMode && !game.isSolved
                        ? () => applyTool(position)
                        : null,
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            cellLabel(cell),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: cell.notes.isNotEmpty ? 12 : 20,
                              fontWeight: cell.characterId != null
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: Colors.black87,
                            ),
                          ),
                        ),

                        if (verdict != null)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Icon(
                              verdict == PlacementVerdict.correct
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: verdict == PlacementVerdict.correct
                                  ? Colors.green.shade800
                                  : Colors.red.shade900,
                              size: 15,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget buildToolSelector() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 0,
      children: [
        for (final tool in DebugTool.values)
          ChoiceChip(
            label: Text(toolLabel(tool)),
            selected: selectedTool == tool,
            onSelected:
                game.isSolved ||
                    (placementId(tool) != null &&
                        characterPlaced(placementId(tool)!))
                ? null
                : (_) {
                    setState(() {
                      selectedTool = tool;
                    });
                  },
          ),
      ],
    );
  }

  Widget buildReplayControls() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton(
            onPressed: stepIndex > 0 ? () => setState(() => stepIndex--) : null,
            child: const Text('Previous'),
          ),
          FilledButton(
            onPressed: stepIndex < widget.steps.length - 1
                ? () => setState(() => stepIndex++)
                : null,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Widget buildLiveControls() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            game.isSolved
                ? 'Completed attempt — editing locked'
                : 'Undo steps: ${game.undoDepth}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: game.canUndo ? undoAction : null,
                icon: const Icon(Icons.undo),
                label: const Text('Undo'),
              ),
              FilledButton.icon(
                onPressed: game.canSubmit ? submitBoard : null,
                icon: const Icon(Icons.check),
                label: const Text('Submit'),
              ),
              if (game.isSolved)
                OutlinedButton.icon(
                  onPressed: newAttempt,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('New attempt'),
                )
              else
                OutlinedButton.icon(
                  onPressed: clearBoard,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear all'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Replay uses recorded snapshots while live mode uses the active session
    final board = liveMode ? game.board : widget.steps[stepIndex].board;

    return Scaffold(
      appBar: AppBar(title: const Text('Murdoku - WP-01C')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Replay')),
                  ButtonSegment(value: true, label: Text('Live Session')),
                ],
                selected: {liveMode},
                onSelectionChanged: (selection) {
                  setState(() {
                    liveMode = selection.first;
                  });
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Text(
                    liveMode
                        ? (game.isSolved ? 'CASE SOLVED' : 'Live Session')
                        : 'Step ${stepIndex + 1} / '
                              '${widget.steps.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    liveMode ? message : widget.steps[stepIndex].title,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            if (liveMode && !game.isSolved)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: buildToolSelector(),
              ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: buildBoard(board),
              ),
            ),

            if (liveMode) buildLiveControls() else buildReplayControls(),
          ],
        ),
      ),
    );
  }
}
