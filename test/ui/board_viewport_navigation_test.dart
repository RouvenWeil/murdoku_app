import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/domain/case_definition.dart';
import 'package:murdoku_app/domain/character_definition.dart';
import 'package:murdoku_app/domain/object_definition.dart';
import 'package:murdoku_app/ui/board/board_viewport_geometry.dart';
import 'package:murdoku_app/ui/screens/case_screen.dart';
import 'package:murdoku_app/ui/widgets/board_viewport_stub.dart';

CaseDefinition _fixture() => CaseDefinition(
  id: 'navigation-fixture',
  title: 'Navigation Fixture',
  difficulty: 'hard',
  rows: 16,
  columns: 16,
  roomGrid: List.generate(16, (_) => List<int?>.filled(16, 0)),
  roomNames: const {0: 'Room'},
  objectGrid: List.generate(16, (_) => List<String?>.filled(16, null)),
  objects: const <String, ObjectDefinition>{},
  generalClues: const ['General clue'],
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

void main() {
  group('Shared board viewport coordinates', () {
    test('restored origins clamp when the visible region changes', () {
      final geometry = BoardViewportGeometry(
        rows: 16,
        columns: 16,
        visibleRows: 5,
        visibleColumns: 5,
        cellSize: 50,
        origin: (row: 15, column: 14),
      );
      expect(geometry.origin, (row: 11, column: 11));
    });

    test('two-finger drag snaps to whole cells and respects boundaries', () {
      final geometry = BoardViewportGeometry(
        rows: 16,
        columns: 16,
        visibleRows: 5,
        visibleColumns: 5,
        cellSize: 50,
        origin: (row: 5, column: 5),
      );
      expect(geometry.snappedAfterDrag(const Offset(-120, 75)), (
        row: 3,
        column: 7,
      ));
      expect(
        geometry.constrainDrag(const Offset(-1000, 1000)),
        const Offset(-300, 250),
      );
    });

    test('screen position to row/column includes viewport origin', () {
      final geometry = BoardViewportGeometry(
        rows: 16,
        columns: 16,
        visibleRows: 5,
        visibleColumns: 5,
        cellSize: 50,
        origin: (row: 3, column: 7),
      );
      expect(geometry.cellAt(const Offset(125, 175)), (row: 6, column: 9));
      expect(geometry.cellAt(const Offset(251, 10)), isNull);
    });

    test('minimap navigation reaches all four edges', () {
      final geometry = BoardViewportGeometry(
        rows: 16,
        columns: 16,
        visibleRows: 5,
        visibleColumns: 5,
        cellSize: 50,
      );
      expect(geometry.centerOnMinimap(const Offset(0, 0), const Size(96, 96)), (
        row: 0,
        column: 0,
      ));
      expect(
        geometry.centerOnMinimap(const Offset(96, 96), const Size(96, 96)),
        (row: 11, column: 11),
      );
      expect(
        geometry.viewportOnMinimap(const Size(160, 160)),
        const Rect.fromLTWH(0, 0, 50, 50),
      );
    });

    test('per-case viewport store does not mix cases', () {
      final store = BoardViewportStore();
      store.setOrigin('case-a', (row: 3, column: 7));
      expect(store.originFor('case-a'), (row: 3, column: 7));
      expect(store.originFor('case-b'), (row: 0, column: 0));
    });
  });

  testWidgets('minimap tap moves the board to the far corner', (tester) async {
    tester.view.physicalSize = const Size(720, 272);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = BoardViewportStore();
    await tester.pumpWidget(
      MaterialApp(
        home: CaseScreen(caseData: _fixture(), viewportStore: store),
      ),
    );

    final finder = find.byKey(const ValueKey('case-minimap'));
    final topLeft = tester.getTopLeft(finder);
    final size = tester.getSize(finder);
    await tester.tapAt(topLeft + Offset(size.width - 3, size.height - 3));
    await tester.pumpAndSettle();

    final viewport = tester.widget<BoardViewportStub>(
      find.byType(BoardViewportStub),
    );
    expect(viewport.origin, (row: 11, column: 11));
    expect(store.originFor('navigation-fixture'), viewport.origin);
    expect(tester.takeException(), isNull);
  });

  testWidgets('board movement requires two pointers and snaps on release', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 272);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = BoardViewportStore();
    await tester.pumpWidget(
      MaterialApp(
        home: CaseScreen(caseData: _fixture(), viewportStore: store),
      ),
    );

    final boardRect = tester.getRect(
      find.byKey(const ValueKey('visible-board-region')),
    );
    final first = await tester.startGesture(
      boardRect.topLeft + const Offset(150, 120),
      pointer: 1,
    );
    await first.moveBy(const Offset(-40, -40));
    await tester.pump();
    expect(store.originFor('navigation-fixture'), (row: 0, column: 0));

    final second = await tester.startGesture(
      boardRect.topLeft + const Offset(190, 160),
      pointer: 2,
    );
    await first.moveBy(const Offset(-85, -85));
    await second.moveBy(const Offset(-85, -85));
    await tester.pump();
    await second.up();
    await first.up();
    await tester.pumpAndSettle();

    final viewport = tester.widget<BoardViewportStub>(
      find.byType(BoardViewportStub),
    );
    expect(viewport.origin.row, greaterThan(0));
    expect(viewport.origin.column, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
