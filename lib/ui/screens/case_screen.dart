import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/case_definition.dart';
import '../../domain/board_state.dart';
import '../../session/game_session.dart';
import '../session/game_progress_store.dart';
import '../session/clue_pin_store.dart';
import '../board/board_viewport_geometry.dart';
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
    // Once board and clue widths are secure, give unused width to the minimap.
    // Its upper bound comes from available height, not a fixed 128dp cap.
    final unusedWidth = math.max(
      0.0,
      surplus - initialClueExtra - toolExtra - extraClue,
    );
    final baseToolWidth = minimumToolWidth + toolExtra;
    final mapHeightLimitedToolWidth =
        arrangement == ToolPanelArrangement.expanded
        ? baseToolWidth
        : math.max(
            baseToolWidth,
            (height - minimapChromeHeight) / mapHeightFactor * mapWidthFactor +
                2 * panelPadding,
          );
    final toolWidth =
        baseToolWidth +
        math.min(unusedWidth, mapHeightLimitedToolWidth - baseToolWidth);
    final boardViewportWidth = width - clueWidth - toolWidth - 2 * dividerWidth;

    final isPartial = arrangement != ToolPanelArrangement.expanded;
    final mapShortSide = isPartial
        ? math.min(
            (toolWidth - 2 * panelPadding) / mapWidthFactor,
            (height - minimapChromeHeight) / mapHeightFactor,
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
  const CaseScreen({
    super.key,
    required this.caseData,
    this.pinStore,
    this.viewportStore,
    this.progressStore,
  });

  final CaseDefinition caseData;
  final CluePinStore? pinStore;
  final BoardViewportStore? viewportStore;
  final GameProgressStore? progressStore;

  @override
  State<CaseScreen> createState() => _CaseScreenState();
}

class _CaseScreenState extends State<CaseScreen> {
  String? selectedCharacterId;
  BoardTool _activeTool = BoardTool.note;
  Offset _boardPan = Offset.zero;
  late GameSession _game;

  GameProgressStore get _progressStore =>
      widget.progressStore ?? GameProgressStore.instance;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  void _loadSession() {
    final saved = _progressStore.read(widget.caseData.id);
    _game = GameSession.fromCase(
      widget.caseData,
      restoredBoard: saved?.board,
      restoredFeedback: saved?.feedbackByCell ?? const {},
      previouslySolved: saved?.isSolved ?? false,
    );
  }

  @override
  void didUpdateWidget(covariant CaseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.caseData.id != widget.caseData.id ||
        oldWidget.progressStore != widget.progressStore) {
      _loadSession();
      selectedCharacterId = null;
      _activeTool = BoardTool.note;
      _boardPan = Offset.zero;
    }
  }

  Set<String> get _placedCharacterIds {
    final result = <String>{};
    for (var row = 0; row < _game.board.rows; row++) {
      for (var column = 0; column < _game.board.columns; column++) {
        final id = _game.board.cellAt((row: row, column: column)).characterId;
        if (id != null) {
          result.add(id);
        }
      }
    }
    return result;
  }

  void _apply(bool Function() action) {
    if (!action()) {
      return;
    }
    _progressStore.save(widget.caseData.id, _game);
    setState(() {});
  }

  // Tool eligibility depends on markable cells, not just board dimensions
  bool get _hasFreeCell {
    for (var row = 0; row < _game.board.rows; row++) {
      for (var column = 0; column < _game.board.columns; column++) {
        final position = (row: row, column: column);
        if (!widget.caseData.canOccupy(position)) continue;
        final cell = _game.board.cellAt(position);
        if (!cell.crossed && cell.characterId == null) return true;
      }
    }
    return false;
  }

  bool get _hasErasableCell {
    for (var row = 0; row < _game.board.rows; row++) {
      for (var column = 0; column < _game.board.columns; column++) {
        if (!_game.board.cellAt((row: row, column: column)).isEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  void _tapCell(CellPosition position) {
    if (_game.isSolved || !widget.caseData.canOccupy(position)) {
      return;
    }
    switch (_activeTool) {
      case BoardTool.note:
        if (selectedCharacterId != null &&
            !_placedCharacterIds.contains(selectedCharacterId) &&
            widget.caseData.canOccupy(position)) {
          _apply(() => _game.toggleNote(position, selectedCharacterId!));
        }
        return;
      case BoardTool.cross:
        _apply(() => _game.toggleCross(position));
        return;
      case BoardTool.erase:
        _apply(() => _game.eraseCell(position));
        return;
    }
  }

  void _placeCell(CellPosition position) {
    if (_activeTool != BoardTool.note || selectedCharacterId == null) {
      return;
    }
    _apply(() => _game.placeCharacter(position, selectedCharacterId!));
  }

  void _selectTool(BoardTool tool) {
    if (_game.isSolved) {
      return;
    }
    setState(() {
      // A second tap on Cross/Erase returns to the default Note tool
      _activeTool = _activeTool == tool ? BoardTool.note : tool;
    });
  }

  void _undo() => _apply(_game.undo);

  void _resetBoard() {
    if (_game.isSolved) {
      _game = GameSession.fromCase(widget.caseData);
    } else {
      _game.clearAll();
    }
    _progressStore.clear(widget.caseData.id);
    setState(() {
      selectedCharacterId = null;
      _activeTool = BoardTool.note;
    });
  }

  void _submit() {
    if (!_game.canSubmit) {
      return;
    }
    final result = _game.submit();
    _progressStore.save(widget.caseData.id, _game);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.solved
              ? 'Case solved!'
              : 'Some placements are incorrect. Review the marked cells.',
        ),
      ),
    );
  }

  CluePinStore get _pinStore => widget.pinStore ?? CluePinStore.instance;
  BoardViewportStore get _viewportStore =>
      widget.viewportStore ?? BoardViewportStore.instance;

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

                final viewportGeometry = BoardViewportGeometry(
                  rows: widget.caseData.rows,
                  columns: widget.caseData.columns,
                  visibleRows: layout.visibleRows,
                  visibleColumns: layout.visibleColumns,
                  cellSize: layout.cellSize,
                  origin: _viewportStore.originFor(widget.caseData.id),
                );
                void navigate(BoardOrigin target) {
                  setState(() {
                    _viewportStore.setOrigin(
                      widget.caseData.id,
                      viewportGeometry.clampOrigin(target),
                    );
                    _boardPan = Offset.zero;
                  });
                }

                return Row(
                  children: [
                    SizedBox(
                      width: layout.clueWidth,
                      child: CluePanelStub(
                        caseData: widget.caseData,
                        selectedCharacterId: selectedCharacterId,
                        placedCharacterIds: _placedCharacterIds,
                        pinnedClueId: _pinStore.pinnedFor(widget.caseData.id),
                        onPinClue: (id) => setState(() {
                          _pinStore.toggle(widget.caseData.id, id);
                        }),
                        onCharacterSelected: (id) => setState(() {
                          selectedCharacterId = id;
                          _activeTool = BoardTool.note;
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
                        origin: viewportGeometry.origin,
                        onOriginChanged: navigate,
                        boardState: _game.board,
                        feedbackByCell: _game.feedbackByCell,
                        onCellTap: _tapCell,
                        onPlacementHold: _placeCell,
                        enablePlacementHold:
                            !_game.isSolved &&
                            _activeTool == BoardTool.note &&
                            selectedCharacterId != null &&
                            !_placedCharacterIds.contains(selectedCharacterId),
                        onPanChanged: (delta) => setState(() {
                          _boardPan = delta;
                        }),
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
                        origin: viewportGeometry.origin,
                        visibleRows: layout.visibleRows,
                        visibleColumns: layout.visibleColumns,
                        boardCellSize: layout.cellSize,
                        boardPan: _boardPan,
                        boardState: _game.board,
                        feedbackByCell: _game.feedbackByCell,
                        activeTool: _activeTool,
                        crossEnabled: !_game.isSolved && _hasFreeCell,
                        noteEnabled:
                            !_game.isSolved &&
                            selectedCharacterId != null &&
                            !_placedCharacterIds.contains(
                              selectedCharacterId,
                            ) &&
                            _hasFreeCell,
                        eraseEnabled: !_game.isSolved && _hasErasableCell,
                        isSolved: _game.isSolved,
                        onReplay: _resetBoard,
                        onToolSelected: _game.isSolved ? null : _selectTool,
                        onUndo: _game.canUndo ? _undo : null,
                        onSubmit: _game.canSubmit ? _submit : null,
                        onClearAll: _hasErasableCell && !_game.isSolved
                            ? _resetBoard
                            : null,
                        onMinimapNavigate: navigate,
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
