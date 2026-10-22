import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'domain/board_actions.dart';
import 'domain/board_state.dart';

// One step of the smoke test: a description and its board.
typedef SmokeStep = ({String title, BoardState board});

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

// Displays one board state at a time.
class SmokeTestScreen extends StatefulWidget {
  final List<SmokeStep> steps;

  const SmokeTestScreen({super.key, required this.steps});

  @override
  State<SmokeTestScreen> createState() => _SmokeTestScreenState();
}

class _SmokeTestScreenState extends State<SmokeTestScreen> {
  int stepIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Read the currently selected smoke-test step.
    final step = widget.steps[stepIndex];
    final board = step.board;

    return Scaffold(
      appBar: AppBar(title: const Text('Murdoku - WP-01B')),
      body: SafeArea(
        child: Column(
          children: [
            // Describe the currently displayed action.
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Step ${stepIndex + 1} / ${widget.steps.length}'),
                  const SizedBox(height: 8),
                  Text(
                    step.title,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Display the immutable board as a square grid.
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AspectRatio(
                      aspectRatio: board.columns / board.rows,
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
                          // Translate the grid index into row and column.
                          final position = (
                            row: index ~/ board.columns,
                            column: index % board.columns,
                          );

                          // Read the corresponding cell from the model.
                          final cell = board.cellAt(position);

                          // Decide which marking to display.
                          String label = '';
                          if (cell.characterId != null) {
                            label = cell.characterId!.replaceFirst(
                              'suspect',
                              '',
                            );
                          } else if (cell.crossed) {
                            label = 'X';
                          } else if (cell.notes.isNotEmpty) {
                            label = cell.notes
                                .map((id) => id.replaceFirst('suspect', ''))
                                .join(' ');
                          }

                          // Use a different background for each marking.
                          final color = cell.characterId != null
                              ? Colors.teal.shade100
                              : cell.crossed
                              ? Colors.red.shade100
                              : cell.notes.isNotEmpty
                              ? Colors.amber.shade100
                              : Colors.grey.shade200;

                          // Draw the cell.
                          return Container(
                            alignment: Alignment.center,
                            color: color,
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: cell.notes.isNotEmpty ? 12 : 20,
                                fontWeight: cell.characterId != null
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: Colors.black87,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Navigate through the saved smoke-test states.
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
          ],
        ),
      ),
    );
  }
}
