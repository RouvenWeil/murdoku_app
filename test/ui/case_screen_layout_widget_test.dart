import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/domain/case_definition.dart';
import 'package:murdoku_app/domain/character_definition.dart';
import 'package:murdoku_app/domain/object_definition.dart';
import 'package:murdoku_app/ui/screens/case_screen.dart';
import 'package:murdoku_app/ui/widgets/board_viewport_stub.dart';
import 'package:murdoku_app/ui/widgets/tool_panel_stub.dart';

CaseDefinition _fixture(int rows, int columns) => CaseDefinition(
  id: 'viewport-fixture',
  title: 'Viewport Fixture',
  difficulty: 'easy',
  rows: rows,
  columns: columns,
  roomGrid: List.generate(rows, (_) => List<int?>.filled(columns, 0)),
  roomNames: const {0: 'Room'},
  objectGrid: List.generate(rows, (_) => List<String?>.filled(columns, null)),
  objects: const <String, ObjectDefinition>{},
  generalClues: const ['A general clue'],
  characters: const [
    CharacterDefinition(
      id: 'A',
      name: 'Anthony',
      clue: 'A clue',
      solution: (row: 0, column: 0),
    ),
    CharacterDefinition(
      id: 'V',
      name: 'Victim',
      clue: 'Another clue',
      solution: (row: 1, column: 1),
    ),
  ],
  murderId: 'A',
);

void main() {
  testWidgets('small case fits and hides the minimap', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(home: CaseScreen(caseData: _fixture(6, 6))),
    );

    final board = tester.widget<BoardViewportStub>(
      find.byType(BoardViewportStub),
    );
    final tools = tester.widget<ToolPanelStub>(find.byType(ToolPanelStub));
    expect(board.visibleRows, 6);
    expect(board.visibleColumns, 6);
    expect(tools.showMinimap, isFalse);
    expect(find.byKey(const ValueKey('case-minimap')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large case shows complete cells and compact minimap tools', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 272);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(home: CaseScreen(caseData: _fixture(16, 16))),
    );

    final board = tester.widget<BoardViewportStub>(
      find.byType(BoardViewportStub),
    );
    final tools = tester.widget<ToolPanelStub>(find.byType(ToolPanelStub));
    expect(board.visibleRows, 5);
    expect(board.visibleColumns, 5);
    expect(board.cellSize, greaterThanOrEqualTo(48));
    expect(tools.showMinimap, isTrue);
    expect(find.byKey(const ValueKey('case-minimap')), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);
    expect(find.text('Note'), findsNothing);
    final compactButtons = find.descendant(
      of: find.byType(ToolPanelStub),
      matching: find.byType(OutlinedButton),
    );
    expect(compactButtons, findsNWidgets(3));
    for (var index = 0; index < 3; index++) {
      final target = tester.getSize(compactButtons.at(index));
      expect(target.width, greaterThanOrEqualTo(48));
      expect(target.height, greaterThanOrEqualTo(48));
    }
    final submit = tester.getSize(find.widgetWithText(FilledButton, 'Submit'));
    expect(submit.height, greaterThanOrEqualTo(48));
    expect(
      tester.getSize(find.byKey(const ValueKey('visible-board-region'))),
      const Size(256, 256),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('stacked tools keep a readable minimap and 48dp targets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(560, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(home: CaseScreen(caseData: _fixture(16, 16))),
    );

    final tools = tester.widget<ToolPanelStub>(find.byType(ToolPanelStub));
    final board = tester.widget<BoardViewportStub>(
      find.byType(BoardViewportStub),
    );
    expect(tools.arrangement, ToolPanelArrangement.stacked);
    expect(board.visibleRows, 4);
    expect(
      tester.getSize(find.byKey(const ValueKey('case-minimap'))).shortestSide,
      greaterThanOrEqualTo(96),
    );
    final icons = find.descendant(
      of: find.byType(ToolPanelStub),
      matching: find.byType(OutlinedButton),
    );
    expect(icons, findsNWidgets(3));
    for (var i = 0; i < 3; i++) {
      final size = tester.getSize(icons.at(i));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(find.text('Undo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('single-column compact controls fit the tight-width layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(560, 336);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(home: CaseScreen(caseData: _fixture(16, 16))),
    );

    final tools = tester.widget<ToolPanelStub>(find.byType(ToolPanelStub));
    final board = tester.widget<BoardViewportStub>(
      find.byType(BoardViewportStub),
    );
    expect(tools.arrangement, ToolPanelArrangement.singleColumn);
    expect(board.visibleRows, 4);
    expect(find.text('Cross'), findsOneWidget);
    expect(find.text('Erase'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);
    final buttons = find.descendant(
      of: find.byType(ToolPanelStub),
      matching: find.byType(OutlinedButton),
    );
    expect(buttons, findsNWidgets(3));
    for (var i = 0; i < 3; i++) {
      final size = tester.getSize(buttons.at(i));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    final submit = tester.getSize(find.widgetWithText(FilledButton, 'Submit'));
    expect(submit.height, greaterThanOrEqualTo(48));
    final minimap = tester.getSize(find.byKey(const ValueKey('case-minimap')));
    expect(minimap.shortestSide, greaterThanOrEqualTo(96));
    expect(tester.takeException(), isNull);
  });

  testWidgets('rectangular board produces matching rectangular minimap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 336);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(home: CaseScreen(caseData: _fixture(10, 9))),
    );

    final mapSize = tester.getSize(find.byKey(const ValueKey('case-minimap')));
    expect(mapSize.width / mapSize.height, closeTo(9 / 10, 0.00001));
    expect(mapSize.shortestSide, greaterThanOrEqualTo(96));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an infeasible landscape window gets a safe fallback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(home: CaseScreen(caseData: _fixture(16, 16))),
    );

    expect(
      find.text('Not enough space for accessible board controls'),
      findsOneWidget,
    );
    expect(find.byType(BoardViewportStub), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
