import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:murdoku_app/session/game_session.dart';

import 'domain/board_actions.dart';
import 'domain/board_state.dart';
import 'domain/solution_evaluation.dart';

// Smoke test: a description and its board.
typedef SmokeStep = ({String title, BoardState board});

// Tools available in the temporary live-debugging screen.
enum DebugTool { cross, noteA, noteB, placeA, placeB, placeV, erase }

void main() {
  // WP-01B: Combined domain-action smoke test.

  // Create an empty 6x6 board.
  final original = BoardState.empty(6, 6);
  final position = (row: 2, column: 3);

  // STEP 1: Add two notes to the same cell.
  final noteA = toggleNote(original, position, 'suspectA');
  final notesAB = toggleNote(noteA, position, 'suspectB');

  // Verify that notes combine without changing the original.
  assert(notesAB.cellAt(position).notes.length == 2);
  assert(notesAB.cellAt(position).notes.contains('suspectA'));
  assert(notesAB.cellAt(position).notes.contains('suspectB'));
  assert(original.cellAt(position).isEmpty);

  // STEP 2: Replace both notes with a cross.
  final crossed = toggleCross(notesAB, position);

  // Verify that the cross overwrites the notes.
  assert(crossed.cellAt(position).crossed);
  assert(crossed.cellAt(position).notes.isEmpty);
  assert(notesAB.cellAt(position).notes.length == 2);

  // STEP 3: Attempt to add a note to a crossed cell.
  final blockedNote = toggleNote(crossed, position, 'suspectA');

  // Verify that the action was rejected.
  assert(identical(blockedNote, crossed));

  // STEP 4: Toggle the cross off and add a new note.
  final cleared = toggleCross(crossed, position);
  final renoted = toggleNote(cleared, position, 'suspectB');

  // Verify that removing the cross did not restore old notes.
  assert(cleared.cellAt(position).isEmpty);
  assert(
    renoted.cellAt(position).notes == {'suspectB'} ||
        (renoted.cellAt(position).notes.length == 1 &&
            renoted.cellAt(position).notes.contains('suspectB')),
  );

  // STEP 5: Place a character on the noted cell.
  final placed = placeCharacter(renoted, position, 'suspectA');

  // Verify placement and note removal.
  assert(placed.cellAt(position).characterId == 'suspectA');
  assert(placed.cellAt(position).notes.isEmpty);

  // Verify automatic crosses in the row and column.
  assert(placed.cellAt((row: 2, column: 0)).crossed);
  assert(placed.cellAt((row: 0, column: 3)).crossed);

  // Verify unrelated cells remain empty.
  assert(placed.cellAt((row: 0, column: 0)).isEmpty);

  // STEP 6: Attempt to cross an occupied character cell.
  final blockedCross = toggleCross(placed, position);

  // Verify that the character cannot be overwritten.
  assert(identical(blockedCross, placed));

  // STEP 7: Allow a second character in the same row.
  final secondPosition = (row: 2, column: 5);
  final available = toggleCross(placed, secondPosition);
  final secondPlaced = placeCharacter(available, secondPosition, 'suspectB');

  // Verify that both characters are preserved.
  assert(secondPlaced.cellAt(position).characterId == 'suspectA');
  assert(secondPlaced.cellAt(secondPosition).characterId == 'suspectB');

  // STEP 8: Erase the original character.
  final erased = eraseCell(secondPlaced, position);

  // Verify that the character is gone.
  assert(erased.cellAt(position).isEmpty);

  // Verify that its generated crosses remain.
  assert(erased.cellAt((row: 2, column: 0)).crossed);
  assert(erased.cellAt((row: 0, column: 3)).crossed);

  // Verify that the previous board remains unchanged.
  assert(secondPlaced.cellAt(position).characterId == 'suspectA');
  assert(original.cellAt(position).isEmpty);

  // Report success when running in debug mode.
  if (kDebugMode) {
    print('WP-01B: All board-action assertions passed!');
  }

  // Open a visual viewer for each state of the smoke test.
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

// Displays our smoke-test board states in a simple Flutter app.
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

// Displays either recorded board states or a live BoardSession.

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

  // Synthetic reference solution for the smoke test.
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

  // Returns the character ID represented by a placement tool.
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

  // All gameplay actions go through GameSession.
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

      // Return to the default tool after placing a character.
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

  // Submit explicitly; never evaluate automatically.
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

  // Replaying creates a new GameSession.
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

  // Submission feedback takes precedence over normal cell colors.
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
                final position = (
                  row: index ~/ board.columns,
                  column: index % board.columns,
                );

                final cell = board.cellAt(position);

                final verdict = liveMode ? game.feedbackByCell[position] : null;

                return Material(
                  color: cellColor(cell, verdict),
                  child: InkWell(
                    // Solved boards cannot be edited.
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

                        // Feedback symbols supplement the colors.
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
    // Replay uses stored board snapshots.
    // Live Session uses the current GameSession.
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
