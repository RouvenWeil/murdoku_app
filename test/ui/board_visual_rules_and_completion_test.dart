import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/data/case_loader.dart';
import 'package:murdoku_app/domain/case_definition.dart';
import 'package:murdoku_app/domain/character_definition.dart';
import 'package:murdoku_app/domain/object_definition.dart';
import 'package:murdoku_app/session/game_session.dart';
import 'package:murdoku_app/ui/board/board_viewport_geometry.dart';
import 'package:murdoku_app/ui/screens/case_screen.dart';
import 'package:murdoku_app/ui/screens/case_selection_screen.dart';
import 'package:murdoku_app/ui/session/game_progress_store.dart';
import 'package:murdoku_app/ui/widgets/board_viewport_stub.dart';
import 'package:murdoku_app/ui/widgets/murdoku_buttons.dart';
import 'package:murdoku_app/ui/widgets/tool_panel_stub.dart';

CaseDefinition _case({int size = 3}) => CaseDefinition(
  id: 'render-fixture-$size',
  title: 'Rendering Fixture',
  difficulty: 'easy',
  rows: size,
  columns: size,
  roomGrid: List.generate(size, (_) => List<int?>.filled(size, 0)),
  roomNames: const {0: 'Room'},
  objectGrid: List.generate(
    size,
    (r) => List.generate(size, (c) => r == 0 && c == 0 ? 'blocked' : null),
  ),
  objects: const {
    'blocked': ObjectDefinition(name: 'Blocked', isOccupiable: false),
  },
  generalClues: const ['A general clue'],
  characters: const [
    CharacterDefinition(
      id: 'A',
      name: 'Anthony',
      clue: 'A clue',
      solution: (row: 0, column: 1),
    ),
    CharacterDefinition(
      id: 'V',
      name: 'Victim',
      clue: 'V clue',
      solution: (row: 1, column: 2),
    ),
  ],
  murderId: 'A',
);

void _landscape(WidgetTester tester, {bool small = false}) {
  tester.view.physicalSize = small
      ? const Size(720, 272)
      : const Size(844, 390);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Offset _cell(WidgetTester tester, int row, int column) {
  final view = tester.widget<BoardViewportStub>(find.byType(BoardViewportStub));
  return tester.getTopLeft(find.byKey(const ValueKey('visible-board-region'))) +
      Offset((column + 0.5) * view.cellSize, (row + 0.5) * view.cellSize);
}

Future<void> _hold(WidgetTester tester, int row, int column) async {
  await tester.pump();
  final touch = await tester.startGesture(_cell(tester, row, column));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 220));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  await touch.up();
  await tester.pump();
}

void main() {
  testWidgets('supplied 32px cross SVG is bundled', (tester) async {
    final data = await rootBundle.loadString('assets/ui/Vector-Cross.svg');
    expect(data, contains('viewBox="0 0 32 32"'));
  });

  test(
    'case session rejects blocked-cell notes, crosses, erases, placements',
    () {
      final session = GameSession.fromCase(_case());
      const blocked = (row: 0, column: 0);
      expect(session.toggleNote(blocked, 'A'), false);
      expect(session.toggleCross(blocked), false);
      expect(session.eraseCell(blocked), false);
      expect(session.placeCharacter(blocked, 'A'), false);
      expect(session.undoDepth, 0);
      expect(session.board.cellAt(blocked).isEmpty, true);
    },
  );

  test(
    'auto-crosses skip non-occupiable cells without changing compound Undo',
    () {
      final session = GameSession.fromCase(_case());
      expect(session.placeCharacter((row: 0, column: 1), 'A'), true);
      expect(session.board.cellAt((row: 0, column: 0)).isEmpty, true);
      expect(session.board.cellAt((row: 0, column: 2)).crossed, true);
      expect(session.undoDepth, 1);
      expect(session.undo(), true);
      expect(session.board.cellAt((row: 0, column: 2)).isEmpty, true);
    },
  );

  testWidgets('labels and eligibility update with selection and board marks', (
    tester,
  ) async {
    _landscape(tester);
    final progress = GameProgressStore();
    await tester.pumpWidget(
      MaterialApp(
        home: CaseScreen(caseData: _case(), progressStore: progress),
      ),
    );
    MurdokuToolButton button(String id) =>
        tester.widget<MurdokuToolButton>(find.byKey(ValueKey('tool-$id')));
    expect(button('cross').label, 'Place\nCross');
    expect(button('note').label, 'Notes');
    expect(button('erase').label, 'Erase Cell');
    expect(button('erase').subtitle, isNull);
    expect(button('note').onPressed, isNull);
    expect(button('erase').onPressed, isNull);
    expect(find.text('SUBMIT'), findsOneWidget);
    expect(
      tester
          .widget<MurdokuSubmitButton>(find.byType(MurdokuSubmitButton))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('select-character-A')));
    await tester.pump();
    expect(button('note').selected, isTrue);
    expect(button('note').onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('tool-cross')));
    await tester.pump();
    expect(button('cross').selected, isTrue);
    await tester.tap(find.byKey(const ValueKey('select-character-V')));
    await tester.pump();
    expect(button('note').selected, isTrue);
    expect(button('cross').selected, isFalse);
  });

  testWidgets('blocked cells ignore tools and crosses display supplied SVG', (
    tester,
  ) async {
    _landscape(tester);
    final progress = GameProgressStore();
    await tester.pumpWidget(
      MaterialApp(
        home: CaseScreen(caseData: _case(), progressStore: progress),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('tool-cross')));
    await tester.pump();
    await tester.tapAt(_cell(tester, 0, 0));
    await tester.pump();
    expect(progress.read('render-fixture-3'), isNull);
    await tester.tapAt(_cell(tester, 2, 0));
    await tester.pump();
    expect(
      progress.read('render-fixture-3')!.board.cellAt((
        row: 2,
        column: 0,
      )).crossed,
      isTrue,
    );
    expect(find.byKey(const ValueKey('board-cross-2-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('board-cross-0-0')), findsNothing);
    expect(
      tester
          .widget<MurdokuToolButton>(find.byKey(const ValueKey('tool-erase')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('Cross and Notes disable when every occupiable cell is used', (
    tester,
  ) async {
    _landscape(tester);
    final definition = _case();
    final session = GameSession.fromCase(definition);
    expect(session.placeCharacter((row: 0, column: 1), 'A'), true);
    expect(session.placeCharacter((row: 1, column: 2), 'V'), true);
    expect(session.toggleCross((row: 2, column: 0)), true);
    final progress = GameProgressStore()..save(definition.id, session);
    await tester.pumpWidget(
      MaterialApp(
        home: CaseScreen(caseData: definition, progressStore: progress),
      ),
    );
    final tools = tester.widget<ToolPanelStub>(find.byType(ToolPanelStub));
    expect(tools.crossEnabled, false);
    expect(tools.noteEnabled, false);
    expect(tools.eraseEnabled, true);
    expect(
      tester
          .widget<MurdokuToolButton>(find.byKey(const ValueKey('tool-cross')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<MurdokuToolButton>(find.byKey(const ValueKey('tool-erase')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('solved Submit becomes PLAY AGAIN and replay clears progress', (
    tester,
  ) async {
    _landscape(tester);
    final progress = GameProgressStore();
    await tester.pumpWidget(
      MaterialApp(
        home: CaseScreen(caseData: _case(), progressStore: progress),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('select-character-A')));
    await _hold(tester, 0, 1);
    await tester.tap(find.byKey(const ValueKey('select-character-V')));
    await _hold(tester, 1, 2);
    expect(find.text('PLAY AGAIN'), findsNothing);
    await tester.tap(find.text('SUBMIT'));
    await tester.pump();
    expect(progress.read('render-fixture-3')?.isSolved, true);
    expect(find.text('PLAY AGAIN'), findsOneWidget);
    await tester.tap(find.text('PLAY AGAIN'));
    await tester.pump();
    expect(progress.read('render-fixture-3'), isNull);
    expect(find.text('SUBMIT'), findsOneWidget);
  });

  testWidgets('solved case is labelled in catalogue', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final definition = await CaseLoader.load('car-repair');
    final session = GameSession.fromCase(definition);
    for (final character in definition.characters) {
      expect(session.placeCharacter(character.solution, character.id), true);
    }
    expect(session.submit().solved, true);
    final store = GameProgressStore()..save(definition.id, session);
    await tester.pumpWidget(
      MaterialApp(home: CaseSelectionScreen(progressStore: store)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Solved'), findsOneWidget);
  });

  testWidgets('Shift + touch drag navigates Android Studio emulator fallback', (
    tester,
  ) async {
    _landscape(tester, small: true);
    final viewport = BoardViewportStore();
    final progress = GameProgressStore();
    await tester.pumpWidget(
      MaterialApp(
        home: CaseScreen(
          caseData: _case(size: 16),
          progressStore: progress,
          viewportStore: viewport,
        ),
      ),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    final touch = await tester.startGesture(
      _cell(tester, 2, 2),
      kind: PointerDeviceKind.touch,
    );
    await touch.moveBy(const Offset(-110, -95));
    await touch.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(viewport.originFor('render-fixture-16').row, greaterThan(0));
    expect(viewport.originFor('render-fixture-16').column, greaterThan(0));
    expect(progress.read('render-fixture-16'), isNull);
  });
}
