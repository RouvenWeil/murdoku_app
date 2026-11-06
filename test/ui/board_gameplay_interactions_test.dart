import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/domain/board_state.dart';
import 'package:murdoku_app/domain/case_definition.dart';
import 'package:murdoku_app/domain/character_definition.dart';
import 'package:murdoku_app/domain/object_definition.dart';
import 'package:murdoku_app/ui/board/board_scene_painter.dart';
import 'package:murdoku_app/ui/board/board_viewport_geometry.dart';
import 'package:murdoku_app/ui/screens/case_screen.dart';
import 'package:murdoku_app/ui/session/game_progress_store.dart';
import 'package:murdoku_app/ui/widgets/board_viewport_stub.dart';
import 'package:murdoku_app/ui/widgets/tool_panel_stub.dart';

CaseDefinition _case({int size = 6}) => CaseDefinition(
  id: 'interaction-case-$size',
  title: 'Interaction Case',
  difficulty: 'easy',
  rows: size,
  columns: size,
  roomGrid: List.generate(size, (_) => List<int?>.filled(size, 0)),
  roomNames: const {0: 'Room'},
  objectGrid: List.generate(size, (_) => List<String?>.filled(size, null)),
  objects: const <String, ObjectDefinition>{},
  generalClues: const ['A general clue'],
  characters: const [
    CharacterDefinition(
      id: 'A',
      name: 'Anthony',
      clue: 'Clue A',
      solution: (row: 0, column: 0),
    ),
    CharacterDefinition(
      id: 'V',
      name: 'Victim',
      clue: 'Clue V',
      solution: (row: 1, column: 1),
    ),
  ],
  murderId: 'A',
);

void _landscape(WidgetTester tester, {bool largeGrid = false}) {
  tester.view.physicalSize = largeGrid
      ? const Size(720, 272)
      : const Size(844, 390);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _show(
  WidgetTester tester,
  GameProgressStore progress, {
  int size = 6,
  BoardViewportStore? viewportStore,
}) => tester.pumpWidget(
  MaterialApp(
    home: CaseScreen(
      caseData: _case(size: size),
      progressStore: progress,
      viewportStore: viewportStore,
    ),
  ),
);

Offset _cell(WidgetTester tester, int row, int column) {
  final viewport = tester.widget<BoardViewportStub>(
    find.byType(BoardViewportStub),
  );
  return tester.getTopLeft(find.byKey(const ValueKey('visible-board-region'))) +
      Offset(
        (column + 0.5) * viewport.cellSize,
        (row + 0.5) * viewport.cellSize,
      );
}

Future<void> _holdCell(WidgetTester tester, int row, int column) async {
  // Apply the character selection before starting the pointer gesture
  await tester.pump();
  final gesture = await tester.startGesture(_cell(tester, row, column));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 220));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets(
    'selected suspect tap toggles notes; cross, erase, Undo are real actions',
    (tester) async {
      _landscape(tester);
      final store = GameProgressStore();
      await _show(tester, store);
      await tester.tap(find.byKey(const ValueKey('select-character-A')));
      await tester.tapAt(_cell(tester, 3, 3));
      await tester.pump();
      expect(
        store.read('interaction-case-6')!.board.cellAt((
          row: 3,
          column: 3,
        )).notes,
        {'A'},
      );
      await tester.tapAt(_cell(tester, 3, 3));
      await tester.pump();
      expect(
        store.read('interaction-case-6')!.board.cellAt((
          row: 3,
          column: 3,
        )).notes,
        isEmpty,
      );

      await tester.tap(find.byKey(const ValueKey('tool-cross')));
      await tester.tapAt(_cell(tester, 3, 3));
      await tester.pump();
      expect(
        store.read('interaction-case-6')!.board.cellAt((
          row: 3,
          column: 3,
        )).crossed,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('tool-erase')));
      await tester.tapAt(_cell(tester, 3, 3));
      await tester.pump();
      expect(
        store.read('interaction-case-6')!.board.cellAt((
          row: 3,
          column: 3,
        )).isEmpty,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('tool-undo')));
      await tester.pump();
      expect(
        store.read('interaction-case-6')!.board.cellAt((
          row: 3,
          column: 3,
        )).crossed,
        isTrue,
      );
    },
  );

  testWidgets('hold commits one compound placement, never a tentative note', (
    tester,
  ) async {
    _landscape(tester);
    final store = GameProgressStore();
    await _show(tester, store);
    await tester.tap(find.byKey(const ValueKey('select-character-A')));
    await _holdCell(tester, 2, 2);
    final board = store.read('interaction-case-6')!.board;
    expect(board.cellAt((row: 2, column: 2)).characterId, 'A');
    expect(board.cellAt((row: 2, column: 2)).notes, isEmpty);
    expect(board.cellAt((row: 2, column: 0)).crossed, isTrue);
    expect(board.cellAt((row: 0, column: 2)).crossed, isTrue);
    await tester.tap(find.byKey(const ValueKey('tool-undo')));
    await tester.pump();
    expect(
      store.read('interaction-case-6')!.board.cellAt((
        row: 2,
        column: 2,
      )).isEmpty,
      isTrue,
    );
    expect(
      store.read('interaction-case-6')!.board.cellAt((
        row: 2,
        column: 0,
      )).isEmpty,
      isTrue,
    );
  });

  testWidgets('releasing a partial hold leaves only a tentative note', (
    tester,
  ) async {
    _landscape(tester);
    final store = GameProgressStore();
    await _show(tester, store);
    await tester.tap(find.byKey(const ValueKey('select-character-A')));
    final touch = await tester.startGesture(_cell(tester, 1, 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await touch.up();
    await tester.pump();
    final cell = store.read('interaction-case-6')!.board.cellAt((
      row: 1,
      column: 1,
    ));
    expect(cell.notes, {'A'});
    expect(cell.characterId, isNull);
  });

  testWidgets('second finger cancels placement and does not create a note', (
    tester,
  ) async {
    _landscape(tester);
    final store = GameProgressStore();
    await _show(tester, store);
    await tester.tap(find.byKey(const ValueKey('select-character-A')));
    final a = await tester.startGesture(_cell(tester, 1, 1), pointer: 9);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final b = await tester.startGesture(_cell(tester, 2, 2), pointer: 10);
    await tester.pump(const Duration(milliseconds: 700));
    await b.up();
    await a.up();
    await tester.pumpAndSettle();
    expect(store.read('interaction-case-6'), isNull);
  });

  testWidgets('dragging in Cross mode does not mark the board', (tester) async {
    _landscape(tester);
    final store = GameProgressStore();
    await _show(tester, store);
    await tester.tap(find.byKey(const ValueKey('tool-cross')));
    await tester.pump();
    final a = await tester.startGesture(_cell(tester, 1, 1));
    await a.moveBy(const Offset(35, 0));
    await a.up();
    await tester.pump();
    expect(store.read('interaction-case-6'), isNull);
  });

  testWidgets('debug right-button drag pans without marking any cell', (
    tester,
  ) async {
    _landscape(tester, largeGrid: true);
    final store = GameProgressStore();
    final viewport = BoardViewportStore();
    await _show(tester, store, size: 16, viewportStore: viewport);
    final right = await tester.startGesture(
      _cell(tester, 2, 2),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await right.moveBy(const Offset(-110, -95));
    await right.up();
    await tester.pumpAndSettle();
    expect(viewport.originFor('interaction-case-16').column, greaterThan(0));
    expect(viewport.originFor('interaction-case-16').row, greaterThan(0));
    expect(store.read('interaction-case-16'), isNull);
  });

  testWidgets('short right-click never marks or places a character', (
    tester,
  ) async {
    _landscape(tester);
    final store = GameProgressStore();
    await _show(tester, store);
    await tester.tap(find.byKey(const ValueKey('select-character-A')));
    final right = await tester.startGesture(
      _cell(tester, 2, 2),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await right.up();
    await tester.pumpAndSettle();
    expect(store.read('interaction-case-6'), isNull);
  });

  testWidgets('hold on Erase clears all and cannot be undone', (tester) async {
    _landscape(tester);
    final store = GameProgressStore();
    await _show(tester, store);
    await tester.tap(find.byKey(const ValueKey('tool-cross')));
    await tester.tapAt(_cell(tester, 2, 2));
    await tester.pump();
    expect(store.read('interaction-case-6'), isNotNull);
    final hold = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('tool-erase'))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await hold.up();
    await tester.pump();
    expect(store.read('interaction-case-6'), isNull);
    final undo = tester.widget<ToolPanelStub>(find.byType(ToolPanelStub));
    expect(undo.onUndo, isNull);
  });

  testWidgets(
    'case reopening restores board but resets selection, tool and undo',
    (tester) async {
      _landscape(tester);
      final store = GameProgressStore();
      await _show(tester, store);
      await tester.tap(find.byKey(const ValueKey('select-character-A')));
      await tester.tapAt(_cell(tester, 3, 3));
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await _show(tester, store);
      final view = tester.widget<BoardViewportStub>(
        find.byType(BoardViewportStub),
      );
      final tools = tester.widget<ToolPanelStub>(find.byType(ToolPanelStub));
      expect(view.boardState!.cellAt((row: 3, column: 3)).notes, {'A'});
      expect(tools.onUndo, isNull);
      expect(tools.activeTool, BoardTool.note);
      expect(view.enablePlacementHold, isFalse);
    },
  );

  testWidgets('Submit is explicit and records verdicts only on demand', (
    tester,
  ) async {
    _landscape(tester);
    final store = GameProgressStore();
    await _show(tester, store);
    await tester.tap(find.byKey(const ValueKey('select-character-A')));
    await _holdCell(tester, 2, 2);
    await tester.tap(find.byKey(const ValueKey('select-character-V')));
    await _holdCell(tester, 4, 4);
    expect(store.read('interaction-case-6')!.feedbackByCell, isEmpty);
    final tool = tester.widget<ToolPanelStub>(find.byType(ToolPanelStub));
    expect(tool.onSubmit, isNotNull);
    await tester.tap(find.text('SUBMIT'));
    await tester.pump();
    expect(store.read('interaction-case-6')!.feedbackByCell.length, 2);
    expect(store.read('interaction-case-6')!.isSolved, isFalse);
  });

  test('scene painter repaints when immutable marks or feedback changes', () {
    final old = BoardState.empty(6, 6);
    final changed = old.withCell((row: 1, column: 1), CellState(notes: {'A'}));
    final definition = _case();
    final a = BoardScenePainter(
      caseData: definition,
      cellSize: 48,
      boardState: old,
    );
    final b = BoardScenePainter(
      caseData: definition,
      cellSize: 48,
      boardState: changed,
    );
    expect(b.shouldRepaint(a), isTrue);
  });
}
