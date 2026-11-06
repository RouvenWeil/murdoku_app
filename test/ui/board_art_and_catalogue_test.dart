import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/data/case_loader.dart';
import 'package:murdoku_app/domain/board_state.dart';
import 'package:murdoku_app/ui/board/board_scene.dart';
import 'package:murdoku_app/ui/design/murdoku_assets.dart';
import 'package:murdoku_app/ui/screens/case_selection_screen.dart';
import 'package:murdoku_app/ui/session/game_progress_store.dart';
import 'package:murdoku_app/ui/widgets/case_catalogue_card.dart';
import 'package:murdoku_app/ui/widgets/case_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all five case PNGs are registered and bundled', () async {
    for (final id in const [
      'car-repair',
      'horse-with-no-name',
      'river-crossing',
      'art-museum-heist',
      'golf-course',
    ]) {
      final definition = await CaseLoader.load(id);
      final path = MurdokuAssets.boardBackground(definition.id);
      expect(path, isNotNull);
      expect((await rootBundle.load(path!)).lengthInBytes, greaterThan(1000));
    }
    expect(MurdokuAssets.boardBackground('readability-6'), isNull);
    expect(
      MurdokuAssets.portrait('horse-with-no-name', 'V'),
      'assets/characters/horse-with-no-name/v.png',
    );
    expect(MurdokuAssets.portrait('golf-course', 'V'), isNull);
  });

  test('catalogue status belongs to the current attempt only', () {
    final empty = BoardState.empty(6, 6);
    final started = GameProgress(
      board: empty,
      feedbackByCell: const {},
      isSolved: false,
    );
    final replayed = GameProgress(
      board: empty,
      feedbackByCell: const {},
      isSolved: false,
      attemptStarted: false,
    );
    final solved = GameProgress(
      board: empty,
      feedbackByCell: const {},
      isSolved: true,
    );
    expect(caseAttemptStatus(null), CaseAttemptStatus.notStarted);
    expect(caseAttemptStatus(replayed), CaseAttemptStatus.notStarted);
    expect(caseAttemptStatus(started), CaseAttemptStatus.inProgress);
    expect(caseAttemptStatus(solved), CaseAttemptStatus.solved);
    expect(
      caseAttemptStatus(solved, unavailable: true),
      CaseAttemptStatus.unavailable,
    );
  });

  testWidgets('full board and minimap share the same PNG, including panning', (
    tester,
  ) async {
    final definition = await CaseLoader.load('river-crossing');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: BoardScene(
                  caseData: definition,
                  cellSize: 20,
                  originColumn: 3,
                  originRow: 2,
                  translation: const Offset(5, -4),
                ),
              ),
              SizedBox(
                width: 90,
                height: 100,
                child: BoardScene(caseData: definition, cellSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
    final images = tester
        .widgetList<Image>(
          find.byKey(const ValueKey('board-art-river-crossing')),
        )
        .toList();
    expect(images, hasLength(2));
    for (final image in images) {
      expect(
        (image.image as AssetImage).assetName,
        MurdokuAssets.boardBackground('river-crossing'),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'catalogue preview uses current marks and only solved shows overlay',
    (tester) async {
      final definition = await CaseLoader.load('car-repair');
      final board = BoardState.empty(
        6,
        6,
      ).withCell((row: 0, column: 0), CellState(notes: {'A'}));
      final progress = GameProgress(
        board: board,
        feedbackByCell: const {},
        isSolved: false,
      );
      final solvedProgress = GameProgress(
        board: board,
        feedbackByCell: const {},
        isSolved: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 350,
              height: 210,
              child: CaseCatalogueCard(
                caseData: definition,
                progress: progress,
                status: CaseAttemptStatus.inProgress,
                onOpen: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('CASE SOLVED'), findsNothing);
      expect(
        tester.widget<CasePreview>(find.byType(CasePreview)).boardState,
        same(board),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 350,
              height: 210,
              child: CaseCatalogueCard(
                caseData: definition,
                progress: solvedProgress,
                status: CaseAttemptStatus.solved,
                onOpen: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('CASE SOLVED'), findsOneWidget);
      expect(find.text('Solved'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('catalogue starts with not started on a clean in-memory store', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: CaseSelectionScreen(progressStore: GameProgressStore()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Not started'), findsWidgets);
    expect(find.byType(CasePreview), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
