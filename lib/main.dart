import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'domain/board_actions.dart';
import 'session/board_session.dart';
import 'domain/board_state.dart';

// Smoke test: a description and its board.
typedef SmokeStep = ({String title, BoardState board});

// Tools available in the temporary live-debugging screen.
enum DebugTool { cross, noteA, noteB, placeA, placeB, erase }

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

  // Live gameplay state is coordinated by BoardSession.
  late final BoardSession session;

  @override
  void initState() {
    super.initState();
    session = BoardSession(initialBoard: BoardState.empty(6, 6));
  }

  // Returns the label of the selected debugging tool.
  String toolLabel(DebugTool tool) {
    return switch (tool) {
      DebugTool.cross => 'Cross',
      DebugTool.noteA => 'Note A',
      DebugTool.noteB => 'Note B',
      DebugTool.placeA => 'Place A',
      DebugTool.placeB => 'Place B',
      DebugTool.erase => 'Eraser',
    };
  }

  // Checks whether a character is already placed on the board.
  bool characterPlaced(String characterId) {
    final board = session.board;

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

  // Applies the selected tool through BoardSession.
  void applyTool(CellPosition position) {
    final changed = switch (selectedTool) {
      DebugTool.cross => session.toggleCross(position),
      DebugTool.noteA => session.toggleNote(position, 'suspectA'),
      DebugTool.noteB => session.toggleNote(position, 'suspectB'),
      DebugTool.placeA => session.placeCharacter(position, 'suspectA'),
      DebugTool.placeB => session.placeCharacter(position, 'suspectB'),
      DebugTool.erase => session.eraseCell(position),
    };

    setState(() {
      message = changed
          ? '${toolLabel(selectedTool)} at '
                '(${position.row}, ${position.column})'
          : 'No change at (${position.row}, ${position.column})';

      // Return to Cross after successfully placing a character.
      if (changed &&
          (selectedTool == DebugTool.placeA ||
              selectedTool == DebugTool.placeB)) {
        selectedTool = DebugTool.cross;
      }
    });
  }

  // Restores the board before the most recent action.
  void undoAction() {
    setState(() {
      session.undo();
      message = 'Restored the previous board state.';
    });
  }

  // Clears the board and permanently discards its Undo history.
  void clearBoard() {
    setState(() {
      session.clearAll();
      selectedTool = DebugTool.cross;
      message = 'Board and Undo history cleared.';
    });
  }

  // Converts a cell into a short display label.
  String cellLabel(CellState cell) {
    if (cell.characterId != null) {
      return cell.characterId!.replaceFirst('suspect', '');
    }

    if (cell.crossed) {
      return 'X';
    }

    return cell.notes.map((id) => id.replaceFirst('suspect', '')).join(' ');
  }

  // Selects a background color based on the cell content.
  Color cellColor(CellState cell) {
    if (cell.characterId != null) return Colors.teal.shade100;
    if (cell.crossed) return Colors.red.shade100;
    if (cell.notes.isNotEmpty) return Colors.amber.shade100;
    return Colors.grey.shade200;
  }

  // Renders the board using the current immutable BoardState.
  Widget buildBoard(BoardState board) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep the board square and inside the available area.
        final side = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;

        return Center(
          child: SizedBox.square(
            dimension: side,
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: board.columns,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: board.rows * board.columns,
              itemBuilder: (context, index) {
                // Convert the grid index into a board position.
                final position = (
                  row: index ~/ board.columns,
                  column: index % board.columns,
                );

                final cell = board.cellAt(position);

                // Only Live Session mode allows cell interaction.
                return Material(
                  color: cellColor(cell),
                  child: InkWell(
                    onTap: liveMode ? () => applyTool(position) : null,
                    child: Center(
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
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // Displays the tools for interacting with the live board.
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

            // A character cannot be selected while already placed.
            onSelected:
                (tool == DebugTool.placeA && characterPlaced('suspectA')) ||
                    (tool == DebugTool.placeB && characterPlaced('suspectB'))
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

  @override
  Widget build(BuildContext context) {
    // Replay reads stored states; Live reads the current session.
    final board = liveMode ? session.board : widget.steps[stepIndex].board;

    return Scaffold(
      appBar: AppBar(title: const Text('Murdoku - WP-01B')),
      body: SafeArea(
        child: Column(
          children: [
            // Switch between recorded and interactive board states.
            Padding(
              padding: const EdgeInsets.all(12),
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

            // Show the title or latest action feedback.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Text(
                    liveMode
                        ? 'Live Session'
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

            // Select the action to perform in Live Session.
            if (liveMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: buildToolSelector(),
              ),

            // Display the board in both modes.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: buildBoard(board),
              ),
            ),

            // Original Previous/Next navigation in Replay mode.
            if (!liveMode)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton(
                      onPressed: stepIndex > 0
                          ? () => setState(() => stepIndex--)
                          : null,
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
              ),

            // Actual Undo controls in Live Session mode.
            if (liveMode)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text('Undo steps: ${session.undoDepth}'),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton.icon(
                          onPressed: session.canUndo ? undoAction : null,
                          icon: const Icon(Icons.undo),
                          label: const Text('Undo'),
                        ),
                        OutlinedButton.icon(
                          onPressed: clearBoard,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Clear all'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
