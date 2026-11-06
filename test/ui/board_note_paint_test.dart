import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/domain/case_definition.dart';
import 'package:murdoku_app/domain/character_definition.dart';
import 'package:murdoku_app/domain/object_definition.dart';
import 'package:murdoku_app/session/game_session.dart';
import 'package:murdoku_app/ui/screens/case_screen.dart';
import 'package:murdoku_app/ui/session/game_progress_store.dart';
import 'package:murdoku_app/ui/widgets/board_viewport_stub.dart';

CaseDefinition _fixture({bool blocked = false}) {
  final objects = List.generate(6, (_) => List<String?>.filled(6, null));
  if (blocked) {
    objects[1][2] = 'rock';
  }
  return CaseDefinition(
    id: blocked ? 'note-paint-blocked' : 'note-paint',
    title: 'Note Paint',
    difficulty: 'easy',
    rows: 6,
    columns: 6,
    roomGrid: List.generate(6, (_) => List<int?>.filled(6, 0)),
    roomNames: const {0: 'Room'},
    objectGrid: objects,
    objects: blocked
        ? const {'rock': ObjectDefinition(name: 'Rock', isOccupiable: false)}
        : const <String, ObjectDefinition>{},
    generalClues: const [],
    characters: const [
      CharacterDefinition(
        id: 'A',
        name: 'Anthony',
        clue: 'An important clue',
        solution: (row: 0, column: 0),
      ),
      CharacterDefinition(
        id: 'V',
        name: 'Victim',
        clue: 'The victim',
        solution: (row: 5, column: 5),
      ),
    ],
    murderId: 'A',
  );
}

void _landscape(WidgetTester tester) {
  tester.view.physicalSize = const Size(844, 390);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _show(
  WidgetTester tester,
  GameProgressStore store, {
  bool blocked = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CaseScreen(
        caseData: _fixture(blocked: blocked),
        progressStore: store,
      ),
    ),
  );
  await tester.pump();
}

Offset _cell(WidgetTester tester, int row, int col) {
  final view = tester.widget<BoardViewportStub>(find.byType(BoardViewportStub));
  return tester.getTopLeft(find.byKey(const ValueKey('visible-board-region'))) +
      Offset((col + 0.5) * view.cellSize, (row + 0.5) * view.cellSize);
}

Future<void> _selectA(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('select-character-A')));
  await tester.pump();
}

Future<void> _swipeAcrossRow(WidgetTester tester, int row) async {
  final gesture = await tester.startGesture(_cell(tester, row, 0));
  await tester.pump();
  // One large OS move should still visit intervening cells.
  await gesture.moveTo(_cell(tester, row, 5));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  test(
    'each additive note writes a separate Undo step and never toggles off',
    () {
      final session = GameSession.fromCase(_fixture(blocked: true));
      expect(session.toggleNote((row: 1, column: 0), 'V'), isTrue);
      expect(session.addNote((row: 1, column: 0), 'A'), isTrue);
      expect(session.addNote((row: 1, column: 1), 'A'), isTrue);
      expect(session.addNote((row: 1, column: 3), 'A'), isTrue);
      expect(session.addNote((row: 1, column: 2), 'A'), isFalse); // Rock
      expect(session.addNote((row: 1, column: 1), 'A'), isFalse); // Revisited
      expect(session.undoDepth, 4);
      expect(session.board.cellAt((row: 1, column: 0)).notes, {'A', 'V'});
      expect(session.board.cellAt((row: 1, column: 2)).notes, isEmpty);
      expect(session.undo(), isTrue);
      expect(session.board.cellAt((row: 1, column: 3)).notes, isEmpty);
      expect(session.board.cellAt((row: 1, column: 1)).notes, {'A'});
      expect(session.undo(), isTrue);
      expect(session.board.cellAt((row: 1, column: 1)).notes, isEmpty);
      expect(session.board.cellAt((row: 1, column: 0)).notes, {'A', 'V'});
      expect(session.undo(), isTrue);
      expect(session.board.cellAt((row: 1, column: 0)).notes, {'V'});
    },
  );

  test(
    'painting cannot overwrite existing crosses or committed characters',
    () {
      final session = GameSession.fromCase(_fixture(blocked: true));
      expect(session.toggleNote((row: 1, column: 1), 'A'), isTrue);
      expect(session.toggleCross((row: 1, column: 4)), isTrue);
      final history = session.undoDepth;
      expect(session.addNote((row: 1, column: 1), 'A'), isFalse);
      expect(session.addNote((row: 1, column: 2), 'A'), isFalse);
      expect(session.addNote((row: 1, column: 4), 'A'), isFalse);
      expect(session.undoDepth, history);
      expect(session.addNote((row: 2, column: 2), 'A'), isTrue);
      expect(session.placeCharacter((row: 3, column: 3), 'V'), isTrue);
      expect(session.addNote((row: 3, column: 3), 'A'), isFalse);
    },
  );

  testWidgets(
    'drag writes every visited cell before release; Undo is per cell',
    (tester) async {
      _landscape(tester);
      final store = GameProgressStore();
      await _show(tester, store);
      await _selectA(tester);
      final finger = await tester.startGesture(_cell(tester, 1, 0));
      await tester.pump();
      await finger.moveTo(_cell(tester, 1, 5));
      await tester.pump();
      // Edits must already be authoritative while the finger is still down.
      final duringDrag = store.read('note-paint')!.board;
      for (var col = 0; col < 6; col++) {
        expect(duringDrag.cellAt((row: 1, column: col)).notes, {'A'});
      }
      await finger.up();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('tool-undo')));
      await tester.pump();
      final afterUndo = store.read('note-paint')!.board;
      for (var col = 0; col < 5; col++) {
        expect(afterUndo.cellAt((row: 1, column: col)).notes, {'A'});
      }
      expect(afterUndo.cellAt((row: 1, column: 5)).isEmpty, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stroke skips blocked objects and existing crosses', (
    tester,
  ) async {
    _landscape(tester);
    final store = GameProgressStore();
    await _show(tester, store, blocked: true);
    await tester.tap(find.byKey(const ValueKey('tool-cross')));
    await tester.pump();
    await tester.tapAt(_cell(tester, 1, 4));
    await tester.pump();
    await _selectA(tester);
    await _swipeAcrossRow(tester, 1);
    final board = store.read('note-paint-blocked')!.board;
    expect(board.cellAt((row: 1, column: 0)).notes, {'A'});
    expect(board.cellAt((row: 1, column: 1)).notes, {'A'});
    expect(board.cellAt((row: 1, column: 2)).isEmpty, isTrue);
    expect(board.cellAt((row: 1, column: 3)).notes, {'A'});
    expect(board.cellAt((row: 1, column: 4)).crossed, isTrue);
    expect(board.cellAt((row: 1, column: 5)).notes, {'A'});
    await tester.tap(find.byKey(const ValueKey('tool-undo')));
    await tester.pump();
    final afterUndo = store.read('note-paint-blocked')!.board;
    expect(afterUndo.cellAt((row: 1, column: 4)).crossed, isTrue);
    expect(afterUndo.cellAt((row: 1, column: 5)).isEmpty, isTrue);
    expect(afterUndo.cellAt((row: 1, column: 3)).notes, {'A'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('drag over an existing note does not toggle it off', (
    tester,
  ) async {
    _landscape(tester);
    final store = GameProgressStore();
    await _show(tester, store);
    await _selectA(tester);
    await tester.tapAt(_cell(tester, 1, 0));
    await tester.pump();
    await _swipeAcrossRow(tester, 1);
    expect(store.read('note-paint')!.board.cellAt((row: 1, column: 0)).notes, {
      'A',
    });
    expect(store.read('note-paint')!.board.cellAt((row: 1, column: 5)).notes, {
      'A',
    });
  });

  testWidgets('a second finger preserves notes but cancels further painting', (
    tester,
  ) async {
    _landscape(tester);
    final store = GameProgressStore();
    await _show(tester, store);
    await _selectA(tester);
    final first = await tester.startGesture(_cell(tester, 1, 0), pointer: 7);
    await tester.pump();
    await first.moveTo(_cell(tester, 1, 3));
    await tester.pump();
    final second = await tester.startGesture(_cell(tester, 2, 1), pointer: 8);
    await tester.pump();
    await second.up();
    await first.up();
    await tester.pumpAndSettle();
    final board = store.read('note-paint')!.board;
    for (var col = 0; col < 4; col++) {
      expect(board.cellAt((row: 1, column: col)).notes, {'A'});
    }
    expect(board.cellAt((row: 1, column: 4)).notes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('holding on a painted cell commits placement before release', (
    tester,
  ) async {
    _landscape(tester);
    final store = GameProgressStore();
    await _show(tester, store);
    await _selectA(tester);
    final finger = await tester.startGesture(_cell(tester, 1, 0));
    await tester.pump();
    await finger.moveTo(_cell(tester, 1, 3));
    await tester.pump();
    expect(store.read('note-paint')!.board.cellAt((row: 1, column: 3)).notes, {
      'A',
    });
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pump(); // Begin the ring's ticker.
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      store.read('note-paint')!.board.cellAt((row: 1, column: 3)).characterId,
      'A',
    );
    // Placement is a separate Undo step; the earlier note edits remain.
    await finger.up();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tool-undo')));
    await tester.pump();
    final restored = store.read('note-paint')!.board;
    expect(restored.cellAt((row: 1, column: 3)).notes, {'A'});
    expect(restored.cellAt((row: 1, column: 0)).notes, {'A'});
  });

  testWidgets('moving to another cell restarts the hold dwell timer', (
    tester,
  ) async {
    _landscape(tester);
    final store = GameProgressStore();
    await _show(tester, store);
    await _selectA(tester);
    final finger = await tester.startGesture(_cell(tester, 1, 0));
    await tester.pump();
    await finger.moveTo(_cell(tester, 1, 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await finger.moveTo(_cell(tester, 1, 4));
    await tester.pump();
    expect(
      store.read('note-paint')!.board.cellAt((row: 1, column: 1)).characterId,
      isNull,
    );
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      store.read('note-paint')!.board.cellAt((row: 1, column: 4)).characterId,
      'A',
    );
    await finger.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a suspect or with Cross active, dragging adds nothing', (
    tester,
  ) async {
    _landscape(tester);
    final store = GameProgressStore();
    await _show(tester, store);
    await _swipeAcrossRow(tester, 1);
    expect(store.read('note-paint'), isNull);
    await _selectA(tester);
    await tester.tap(find.byKey(const ValueKey('tool-cross')));
    await tester.pump();
    await _swipeAcrossRow(tester, 1);
    expect(store.read('note-paint'), isNull);
  });
}
