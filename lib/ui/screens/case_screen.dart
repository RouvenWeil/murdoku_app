import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/board_state.dart';
import '../../domain/case_definition.dart';
import '../../session/game_session.dart';
import '../../session/foreground_case_clock.dart';
import '../board/board_viewport_geometry.dart';
import '../design/murdoku_tokens.dart';
import '../design/murdoku_typography.dart';
import '../session/clue_pin_store.dart';
import '../session/game_progress_store.dart';
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

  static const double minimumCellSize = MurdokuTokens.minTouchSize;
  static const double boardMargin = MurdokuTokens.panelInset;
  static const double dividerWidth = 1;
  static const double minimumClueWidth = 220;
  static const double preferredClueWidth = 340;
  static const double minimumFullToolWidth = 112;
  static const double preferredFullToolWidth = 172;
  static const double panelPadding = MurdokuTokens.panelInset;
  static const double controlGap = MurdokuTokens.space8;
  static const double minimumMinimapSize = 96;
  static const double preferredMinimapSize = 128;
  static const double preferredHorizontalToolWidth = 192;
  static const double preferredStackedToolWidth = 136;
  static const double preferredSingleColumnToolWidth = 128;
  static const double comparisonEpsilon = 0.000001;

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
    double textScale = 1,
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
      // At enlarged system font scales protect the Submit label's width.
      // This can reduce visible board columns instead of shrinking the text.
      final actionContentWidth = textScale > 1.3
          ? math.max(
              controlWidth,
              MurdokuTokens.enlargedTextCompactToolContentWidth,
            )
          : controlWidth;
      final minimumToolWidth =
          math.max(actionContentWidth, minimumMapWidth) + 2 * panelPadding;
      final chromeHeight =
          controlRows * (minimumCellSize + controlGap) + 2 * panelPadding;
      if (height + comparisonEpsilon < minimumMapHeight + chromeHeight) {
        continue;
      }

      final squareSide = math.min(
        width - minimumClueWidth - minimumToolWidth - separators - boardPadding,
        boardHeightLimit,
      );
      if (squareSide + comparisonEpsilon < minimumCellSize) {
        continue;
      }

      // Settled partial views show a square integer count of complete cells
      final count = math.min(
        math.min(rows, columns),
        (squareSide / minimumCellSize).floor(),
      );
      if (count < 1) {
        continue;
      }

      final candidate = _PartialCandidate(
        arrangement: arrangement,
        minimumToolWidth: minimumToolWidth,
        preferredToolWidth: math.max(minimumToolWidth, switch (arrangement) {
          ToolPanelArrangement.horizontal => preferredHorizontalToolWidth,
          ToolPanelArrangement.stacked => preferredStackedToolWidth,
          ToolPanelArrangement.singleColumn => preferredSingleColumnToolWidth,
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
              candidate.squareSide > best.squareSide + comparisonEpsilon)) {
        best = candidate;
      }
    }
    if (best == null) {
      return null;
    }

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

class _CaseScreenState extends State<CaseScreen> with WidgetsBindingObserver {
  String? selectedCharacterId;
  BoardTool _activeTool = BoardTool.note;
  Offset _boardPan = Offset.zero;
  late GameSession _game;
  late ForegroundCaseClock _clock;
  Timer? _clockTimer;
  bool _hydrating = false;
  Duration _lastCheckpoint = Duration.zero;

  GameProgressStore get _progressStore =>
      widget.progressStore ?? GameProgressStore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _progressStore.addListener(_onStoreChanged);
    _openSession();
  }

  void _onStoreChanged() {
    if (mounted && !_hydrating) setState(() {});
  }

  bool get _isForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  void _openSession() {
    final state = _progressStore.status(widget.caseData.id);
    if (_progressStore.hasPersistence &&
        state != ProgressLoadStatus.ready &&
        state != ProgressLoadStatus.recovered) {
      _hydrating = true;
      _game = GameSession.fromCase(widget.caseData);
      _clock = ForegroundCaseClock();
      unawaited(_hydrate());
    } else {
      _installSession();
    }
  }

  Future<void> _hydrate() async {
    await _progressStore.ensureLoaded(widget.caseData);
    if (!mounted) return;
    if (_progressStore.status(widget.caseData.id) ==
        ProgressLoadStatus.failed) {
      setState(() => _hydrating = false);
      return;
    }
    setState(_installSession);
  }

  void _installSession() {
    _clockTimer?.cancel();
    final saved = _progressStore.read(widget.caseData.id);
    _game = GameSession.fromCase(
      widget.caseData,
      restoredBoard: saved?.board,
      restoredFeedback: saved?.feedbackByCell ?? const {},
      previouslySolved: saved?.isSolved ?? false,
    );
    _clock = ForegroundCaseClock(
      accumulated: saved?.elapsed ?? Duration.zero,
      solved: saved?.isSolved ?? false,
    );
    _lastCheckpoint = _clock.elapsed;
    _hydrating = false;
    if (_isForeground) _resumeClock();
  }

  void _resumeClock() {
    if (_hydrating || _game.isSolved) return;
    _clock.resume();
    if (_progressStore.hasPersistence) {
      _clockTimer?.cancel();
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_clock.elapsed - _lastCheckpoint >= const Duration(seconds: 10)) {
          _checkpointClock();
        }
        setState(() {});
      });
    }
  }

  void _checkpointClock({
    CaseDefinition? caseData,
    GameProgressStore? progressStore,
  }) {
    final activeCase = caseData ?? widget.caseData;
    final store = progressStore ?? _progressStore;
    // In-memory sessions should not create new progress records merely because
    // the screen closes. A clock-only checkpoint is durable-storage work;
    // saves caused by actual board edits still use the in-memory store.
    if (!store.hasPersistence) return;
    final elapsed = _clock.elapsed;
    if (elapsed == Duration.zero) return;
    final previous = store.read(activeCase.id);
    if (previous?.elapsed == elapsed) return;
    _lastCheckpoint = elapsed;
    store.save(
      activeCase.id,
      _game,
      caseData: activeCase,
      elapsed: elapsed,
      attemptStarted: true,
    );
  }

  void _pauseClock({
    CaseDefinition? caseData,
    GameProgressStore? progressStore,
  }) {
    _clockTimer?.cancel();
    _clockTimer = null;
    _clock.pause();
    if (!_hydrating) {
      _checkpointClock(caseData: caseData, progressStore: progressStore);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumeClock();
    } else {
      _pauseClock();
    }
  }

  @override
  void didUpdateWidget(covariant CaseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.caseData.id != widget.caseData.id ||
        oldWidget.progressStore != widget.progressStore) {
      (oldWidget.progressStore ?? GameProgressStore.instance).removeListener(
        _onStoreChanged,
      );
      _pauseClock(
        caseData: oldWidget.caseData,
        progressStore: oldWidget.progressStore ?? GameProgressStore.instance,
      );
      _progressStore.addListener(_onStoreChanged);
      _openSession();
      selectedCharacterId = null;
      _activeTool = BoardTool.note;
      _boardPan = Offset.zero;
    }
  }

  @override
  void dispose() {
    _progressStore.removeListener(_onStoreChanged);
    _pauseClock();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
    _progressStore.save(
      widget.caseData.id,
      _game,
      caseData: widget.caseData,
      elapsed: _clock.elapsed,
    );
    setState(() {});
  }

  // Tool eligibility depends on markable cells, not just board dimensions
  bool get _hasFreeCell {
    for (var row = 0; row < _game.board.rows; row++) {
      for (var column = 0; column < _game.board.columns; column++) {
        final position = (row: row, column: column);
        if (!widget.caseData.canOccupy(position)) continue;
        final cell = _game.board.cellAt(position);
        if (!cell.crossed && cell.characterId == null) {
          return true;
        }
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

  void _paintNote(CellPosition position) {
    final characterId = selectedCharacterId;
    if (_game.isSolved ||
        _activeTool != BoardTool.note ||
        characterId == null ||
        _placedCharacterIds.contains(characterId)) {
      return;
    }
    // Every eligible cell is written and saved as soon as the finger visits it.
    // The game session records a separate Undo snapshot per successful mark.
    _apply(() => _game.addNote(position, characterId));
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
    final wasSolved = _game.isSolved;
    if (wasSolved) {
      _game = GameSession.fromCase(widget.caseData);
      _clock.reset();
    } else {
      _game.clearAll();
    }
    if (_progressStore.hasPersistence) {
      _progressStore.replaceAttempt(
        widget.caseData,
        _game,
        elapsed: wasSolved ? Duration.zero : _clock.elapsed,
        attemptStarted: !wasSolved,
      );
    } else {
      // Preserve the existing in-memory tests' empty/reset semantics.
      _progressStore.clear(widget.caseData.id);
    }
    if (wasSolved && _isForeground) _resumeClock();
    setState(() {
      selectedCharacterId = null;
      _activeTool = BoardTool.note;
    });
  }

  void _submit() {
    if (!_game.canSubmit) return;
    final result = _game.submit();
    if (result.solved) {
      _clock.solve();
      _clockTimer?.cancel();
      _clockTimer = null;
    }
    _progressStore.save(
      widget.caseData.id,
      _game,
      caseData: widget.caseData,
      elapsed: _clock.elapsed,
    );
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

  Future<void> _hydrateRetry() async {
    await _progressStore.retryLoad(widget.caseData);
    if (!mounted) return;
    if (_progressStore.status(widget.caseData.id) ==
        ProgressLoadStatus.failed) {
      setState(() => _hydrating = false);
    } else {
      setState(_installSession);
    }
  }

  Future<void> _archiveAndStartFresh() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a new attempt?'),
        content: const Text(
          'The damaged save will be archived. This will not '
          'restore its marks to the new attempt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive and start'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    try {
      await _progressStore.startFreshAfterFailure(widget.caseData);
      if (mounted) setState(_installSession);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not archive the damaged save.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hydrating) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_progressStore.status(widget.caseData.id) ==
        ProgressLoadStatus.failed) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This case has damaged or incompatible saved progress.',
              ),
              const Text('Your original save has not been deleted.'),
              TextButton(
                onPressed: () => setState(() {
                  _hydrating = true;
                  unawaited(_hydrateRetry());
                }),
                child: const Text('Retry loading'),
              ),
              TextButton(
                onPressed: _archiveAndStartFresh,
                child: const Text('Archive damaged save and start fresh'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Back to cases'),
              ),
            ],
          ),
        ),
      );
    }
    final saveError = _progressStore.saveError(widget.caseData.id);
    return Scaffold(
      // A persistent, actionable warning is preferable to a disappearing toast.
      persistentFooterButtons: saveError == null
          ? null
          : [
              const Text('Progress not saved'),
              TextButton(
                onPressed: () =>
                    unawaited(_progressStore.retrySave(widget.caseData.id)),
                child: const Text('Retry save'),
              ),
            ],
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            // Visual fallback for windows where Android ignores orientation requests
            if (orientation == Orientation.portrait) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(MurdokuTokens.space24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.screen_rotation, size: 48),
                      const SizedBox(height: MurdokuTokens.space16),
                      Text(
                        'Rotate to landscape',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: MurdokuTokens.space8),
                      Text(
                        '${widget.caseData.title} uses a landscape layout',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: MurdokuTokens.space16),
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
                  textScale:
                      MediaQuery.textScalerOf(context)
                          .scale(MurdokuTypography.toolLabelSize) /
                      MurdokuTypography.toolLabelSize,
                );

                if (layout == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(MurdokuTokens.panelInset),
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
                        elapsed: _clock.elapsed,
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
                        onNotePaint: _paintNote,
                        noteCharacterId:
                            !_game.isSolved &&
                                _activeTool == BoardTool.note &&
                                selectedCharacterId != null &&
                                !_placedCharacterIds.contains(
                                  selectedCharacterId,
                                )
                            ? selectedCharacterId
                            : null,
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
