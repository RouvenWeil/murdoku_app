import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/case_definition.dart';
import '../widgets/board_viewport_stub.dart';
import '../widgets/clue_panel_stub.dart';
import '../widgets/tool_panel_stub.dart';

// Board geometry before side-panel surplus allocation
class CaseScreenLayout {
  const CaseScreenLayout._({
    required this.isPartial,
    required this.toolArrangement,
    required this.clueWidth,
    required this.toolWidth,
    required this.boardViewportWidth,
    required this.boardRegionWidth,
    required this.boardRegionHeight,
    required this.cellSize,
    required this.visibleRows,
    required this.visibleColumns,
    required this.minimapWidth,
    required this.minimapHeight,
  });

  static const double minimumCellSize = 48;
  static const double boardMargin = 8;
  static const double dividerWidth = 1;
  static const double minimumClueWidth = 220;
  static const double preferredClueWidth = 340;
  static const double minimumFullToolWidth = 112;
  static const double preferredFullToolWidth = 172;
  static const double panelPadding = 8;
  static const double controlGap = 8;
  static const double minimumMinimapSize = 96;
  static const double preferredMinimapSize = 128;

  final bool isPartial;
  final ToolPanelArrangement toolArrangement;
  final double clueWidth;
  final double toolWidth;
  final double boardViewportWidth;
  final double boardRegionWidth;
  final double boardRegionHeight;
  final double cellSize;
  final int visibleRows;
  final int visibleColumns;
  final double minimapWidth;
  final double minimapHeight;

  // Shorter minimap side, irrespective of the board's aspect ratio
  double get minimapSize => math.min(minimapWidth, minimapHeight);

  static CaseScreenLayout? calculate({
    required Size availableSize,
    required int rows,
    required int columns,
  }) {
    if (rows <= 0 || columns <= 0) {
      throw ArgumentError('Board dimensions must be positive');
    }

    final width = availableSize.width;
    final height = availableSize.height;
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      return null;
    }

    const separators = 2 * dividerWidth;
    const boardPadding = 2 * boardMargin;
    final boardHeightLimit = height - boardPadding;
    final fullBoardWidthLimit =
        width -
        minimumClueWidth -
        minimumFullToolWidth -
        separators -
        boardPadding;

    // A complete board has priority when its cells meet the touch-size floor
    final fullCellSize = math.min(
      fullBoardWidthLimit / columns,
      boardHeightLimit / rows,
    );
    if (fullCellSize >= minimumCellSize) {
      return _allocate(
        width: width,
        minimumToolWidth: minimumFullToolWidth,
        preferredToolWidth: preferredFullToolWidth,
        arrangement: ToolPanelArrangement.expanded,
        rows: rows,
        columns: columns,
        cellSize: fullCellSize,
      );
    }

    // The minimap keeps its board aspect ratio with a 96dp shorter side
    final mapWidthFactor = math.max(1.0, columns / rows);
    final mapHeightFactor = math.max(1.0, rows / columns);
    final minimumMapWidth = minimumMinimapSize * mapWidthFactor;
    final minimumMapHeight = minimumMinimapSize * mapHeightFactor;

    _PartialCandidate? best;
    for (final arrangement in const [
      ToolPanelArrangement.horizontal,
      ToolPanelArrangement.stacked,
      ToolPanelArrangement.singleColumn,
    ]) {
      final controlRows = switch (arrangement) {
        ToolPanelArrangement.horizontal => 2,
        ToolPanelArrangement.stacked => 3,
        ToolPanelArrangement.singleColumn => 4,
        ToolPanelArrangement.expanded => throw StateError('Not a compact mode'),
      };
      final controlWidth = switch (arrangement) {
        ToolPanelArrangement.horizontal => 3 * minimumCellSize + 2 * controlGap,
        ToolPanelArrangement.stacked => 2 * minimumCellSize + controlGap,
        ToolPanelArrangement.singleColumn => minimumCellSize,
        ToolPanelArrangement.expanded => throw StateError('Not a compact mode'),
      };
      final minimumToolWidth =
          math.max(controlWidth, minimumMapWidth) + 2 * panelPadding;
      final chromeHeight =
          controlRows * (minimumCellSize + controlGap) + 2 * panelPadding;
      if (height + 0.000001 < minimumMapHeight + chromeHeight) continue;

      final squareSide = math.min(
        width - minimumClueWidth - minimumToolWidth - separators - boardPadding,
        boardHeightLimit,
      );
      if (squareSide + 0.000001 < minimumCellSize) continue;

      // Settled partial views show a square integer count of complete cells
      final count = math.min(
        math.min(rows, columns),
        (squareSide / minimumCellSize).floor(),
      );
      if (count < 1) continue;

      final candidate = _PartialCandidate(
        arrangement: arrangement,
        minimumToolWidth: minimumToolWidth,
        preferredToolWidth: math.max(minimumToolWidth, switch (arrangement) {
          ToolPanelArrangement.horizontal => 192.0,
          ToolPanelArrangement.stacked => 136.0,
          ToolPanelArrangement.singleColumn => 128.0,
          ToolPanelArrangement.expanded => throw StateError(
            'Not a compact mode',
          ),
        }),
        squareSide: squareSide,
        count: count,
        chromeHeight: chromeHeight,
      );

      // Candidate priority: complete-cell count, cell size, then fewer control rows
      if (best == null ||
          candidate.count > best.count ||
          (candidate.count == best.count &&
              candidate.squareSide > best.squareSide + 0.000001)) {
        best = candidate;
      }
    }
    if (best == null) return null;

    final cellSize = best.squareSide / best.count;
    return _allocate(
      width: width,
      minimumToolWidth: best.minimumToolWidth,
      preferredToolWidth: best.preferredToolWidth,
      arrangement: best.arrangement,
      rows: best.count,
      columns: best.count,
      cellSize: cellSize,
      height: height,
      mapWidthFactor: mapWidthFactor,
      mapHeightFactor: mapHeightFactor,
      minimapChromeHeight: best.chromeHeight,
    );
  }

  static CaseScreenLayout _allocate({
    required double width,
    required double minimumToolWidth,
    required double preferredToolWidth,
    required ToolPanelArrangement arrangement,
    required int rows,
    required int columns,
    required double cellSize,
    double height = 0,
    double mapWidthFactor = 1,
    double mapHeightFactor = 1,
    double minimapChromeHeight = 0,
  }) {
    final boardWidth = columns * cellSize;
    final boardHeight = rows * cellSize;
    final minimumBoardViewportWidth = boardWidth + 2 * boardMargin;
    final surplus = math.max(
      0.0,
      width -
          minimumBoardViewportWidth -
          minimumClueWidth -
          minimumToolWidth -
          2 * dividerWidth,
    );

    // Clue readability gets first claim on spare space
    final initialClueExtra = math.min(
      preferredClueWidth - minimumClueWidth,
      surplus * 0.75,
    );
    final toolExtra = math.min(
      preferredToolWidth - minimumToolWidth,
      surplus - initialClueExtra,
    );
    final extraClue = math.min(
      preferredClueWidth - minimumClueWidth - initialClueExtra,
      surplus - initialClueExtra - toolExtra,
    );
    final clueWidth = minimumClueWidth + initialClueExtra + extraClue;
    final toolWidth = minimumToolWidth + toolExtra;
    final boardViewportWidth = width - clueWidth - toolWidth - 2 * dividerWidth;

    final isPartial = arrangement != ToolPanelArrangement.expanded;
    final mapShortSide = isPartial
        ? math.min(
            preferredMinimapSize,
            math.min(
              (toolWidth - 2 * panelPadding) / mapWidthFactor,
              (height - minimapChromeHeight) / mapHeightFactor,
            ),
          )
        : 0.0;

    return CaseScreenLayout._(
      isPartial: isPartial,
      toolArrangement: arrangement,
      clueWidth: clueWidth,
      toolWidth: toolWidth,
      boardViewportWidth: boardViewportWidth,
      boardRegionWidth: boardWidth,
      boardRegionHeight: boardHeight,
      cellSize: cellSize,
      visibleRows: rows,
      visibleColumns: columns,
      minimapWidth: mapShortSide * mapWidthFactor,
      minimapHeight: mapShortSide * mapHeightFactor,
    );
  }
}

class _PartialCandidate {
  const _PartialCandidate({
    required this.arrangement,
    required this.minimumToolWidth,
    required this.preferredToolWidth,
    required this.squareSide,
    required this.count,
    required this.chromeHeight,
  });

  final ToolPanelArrangement arrangement;
  final double minimumToolWidth;
  final double preferredToolWidth;
  final double squareSide;
  final int count;
  final double chromeHeight;
}

class CaseScreen extends StatefulWidget {
  const CaseScreen({super.key, required this.caseData});

  final CaseDefinition caseData;

  @override
  State<CaseScreen> createState() => _CaseScreenState();
}

class _CaseScreenState extends State<CaseScreen> {
  String? selectedCharacterId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            // Visual fallback for windows where Android ignores orientation requests
            if (orientation == Orientation.portrait) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.screen_rotation, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Rotate to landscape',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.caseData.title} uses a landscape layout',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Back to cases'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final layout = CaseScreenLayout.calculate(
                  availableSize: constraints.biggest,
                  rows: widget.caseData.rows,
                  columns: widget.caseData.columns,
                );

                if (layout == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        'Not enough space for accessible board controls',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  );
                }

                return Row(
                  children: [
                    SizedBox(
                      width: layout.clueWidth,
                      child: CluePanelStub(
                        caseData: widget.caseData,
                        selectedCharacterId: selectedCharacterId,
                        onCharacterSelected: (id) => setState(() {
                          selectedCharacterId = id;
                        }),
                        onBack: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: BoardViewportStub(
                        caseData: widget.caseData,
                        visibleRows: layout.visibleRows,
                        visibleColumns: layout.visibleColumns,
                        cellSize: layout.cellSize,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: layout.toolWidth,
                      child: ToolPanelStub(
                        caseData: widget.caseData,
                        showMinimap: layout.isPartial,
                        arrangement: layout.toolArrangement,
                        minimapWidth: layout.minimapWidth,
                        minimapHeight: layout.minimapHeight,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
