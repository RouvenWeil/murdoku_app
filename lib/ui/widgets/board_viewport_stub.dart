import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/board_state.dart';
import '../../domain/case_definition.dart';
import '../../domain/solution_evaluation.dart';
import '../board/board_scene.dart';
import '../board/board_viewport_geometry.dart';
import '../design/murdoku_assets.dart';
import '../design/murdoku_tokens.dart';

// Gameplay input and navigation use the same row-first coordinate geometry
class BoardViewportStub extends StatefulWidget {
  const BoardViewportStub({
    super.key,
    required this.caseData,
    required this.visibleRows,
    required this.visibleColumns,
    required this.cellSize,
    this.origin = const (row: 0, column: 0),
    this.onOriginChanged,
    this.onPanChanged,
    this.boardState,
    this.feedbackByCell = const {},
    this.onCellTap,
    this.onPlacementHold,
    this.enablePlacementHold = false,
    this.noteCharacterId,
    this.onNotePaint,
  });

  final CaseDefinition caseData;
  final int visibleRows;
  final int visibleColumns;
  final double cellSize;
  final BoardOrigin origin;
  final ValueChanged<BoardOrigin>? onOriginChanged;
  final ValueChanged<Offset>? onPanChanged;
  final BoardState? boardState;
  final Map<CellPosition, PlacementVerdict> feedbackByCell;
  final ValueChanged<CellPosition>? onCellTap;
  final ValueChanged<CellPosition>? onPlacementHold;
  final bool enablePlacementHold;
  // Only supplied for the active Notes tool with a selected, unplaced suspect.
  final String? noteCharacterId;
  final ValueChanged<CellPosition>? onNotePaint;

  @override
  State<BoardViewportStub> createState() => _BoardViewportStubState();
}

class _BoardViewportStubState extends State<BoardViewportStub>
    with TickerProviderStateMixin {
  static const placementHoldDuration = MurdokuTokens.placementHoldDuration;

  final Map<int, Offset> _pointers = {};
  Offset? _lastCentroid;
  Offset _drag = Offset.zero;
  Offset _snapFrom = Offset.zero;
  Offset _snapTo = Offset.zero;
  BoardOrigin? _pendingOrigin;
  int? _rightDragPointer;
  Offset? _lastRightPosition;
  int? _tapPointer;
  Offset? _tapDownPosition;
  CellPosition? _heldCell;
  bool _holdCommitted = false;
  bool _suppressTapUntilAllUp = false;
  int? _strokePointer;
  Offset? _strokeLastPoint;
  bool _paintingNotes = false;
  // A visited cell is emitted at most once per drag, even if revisited.
  final Set<CellPosition> _strokeCells = {};
  Timer? _holdStartTimer;
  Offset? _holdAnchor;

  late final AnimationController _snapController;
  late final AnimationController _holdController;

  @override
  void initState() {
    super.initState();
    _snapController =
        AnimationController(
            vsync: this,
            duration: MurdokuTokens.boardSnapDuration,
          )
          ..addListener(() {
            if (_pendingOrigin != null) {
              widget.onPanChanged?.call(_paintShift);
            }
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _completeSnap();
            }
          });
    _holdController =
        AnimationController(vsync: this, duration: placementHoldDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed &&
                _heldCell != null &&
                !_holdCommitted &&
                !_suppressTapUntilAllUp &&
                _pointers.length == 1 &&
                widget.enablePlacementHold) {
              final cell = _heldCell!;
              _holdCommitted = true;
              _holdStartTimer?.cancel();
              // A completed placement ends painting for this pointer gesture.
              _paintingNotes = false;
              _strokePointer = null;
              _strokeLastPoint = null;
              _tapPointer = null;
              _tapDownPosition = null;
              widget.onPlacementHold?.call(cell);
            }
          });
  }

  @override
  void didUpdateWidget(covariant BoardViewportStub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.caseData != widget.caseData ||
        oldWidget.visibleRows != widget.visibleRows ||
        oldWidget.visibleColumns != widget.visibleColumns ||
        oldWidget.cellSize != widget.cellSize) {
      _snapController.stop();
      _pendingOrigin = null;
      _pointers.clear();
      _lastCentroid = null;
      _drag = Offset.zero;
      _rightDragPointer = null;
      _suppressTapUntilAllUp = false;
      _cancelPress();
    }
    if (!widget.enablePlacementHold && oldWidget.enablePlacementHold) {
      _cancelHold();
    }
    // Switching tools or moving the viewport ends the active paint gesture.
    if ((oldWidget.noteCharacterId != widget.noteCharacterId ||
            oldWidget.origin != widget.origin) &&
        _paintingNotes) {
      _cancelPress();
    }
  }

  @override
  void dispose() {
    _holdStartTimer?.cancel();
    _snapController.dispose();
    _holdController.dispose();
    super.dispose();
  }

  BoardViewportGeometry get _geometry => BoardViewportGeometry(
    rows: widget.caseData.rows,
    columns: widget.caseData.columns,
    visibleRows: widget.visibleRows,
    visibleColumns: widget.visibleColumns,
    cellSize: widget.cellSize,
    origin: widget.origin,
  );

  Offset get _paintShift {
    if (_pendingOrigin == null) {
      return _drag;
    }
    return Offset.lerp(
      _snapFrom,
      _snapTo,
      Curves.easeOutCubic.transform(_snapController.value),
    )!;
  }

  Offset _centroid() {
    final values = _pointers.values.toList(growable: false);
    return Offset(
      (values[0].dx + values[1].dx) / 2,
      (values[0].dy + values[1].dy) / 2,
    );
  }

  void _cancelHold() {
    _holdStartTimer?.cancel();
    _holdStartTimer = null;
    _holdAnchor = null;
    _heldCell = null;
    _holdController.stop();
    _holdController.reset();
  }

  void _cancelPress() {
    _tapPointer = null;
    _tapDownPosition = null;
    _paintingNotes = false;
    _strokePointer = null;
    _strokeLastPoint = null;
    _strokeCells.clear();
    _cancelHold();
  }

  bool _mayPaint(CellPosition position) {
    final characterId = widget.noteCharacterId;
    if (characterId == null || !widget.caseData.canOccupy(position)) {
      return false;
    }
    final cell = widget.boardState?.cellAt(position);
    return cell != null && !cell.crossed && cell.characterId == null;
  }

  // A single OS move event can cross several cells. Visit the whole segment
  // in order and write each eligible note through the authoritative session.
  void _paintSegment(Offset from, Offset to) {
    final distance = (to - from).distance;
    final stepSize = math.max(widget.cellSize / 4, 1.0);
    final steps = math.max(1, (distance / stepSize).ceil());
    for (var step = 0; step <= steps; step++) {
      final sample = Offset.lerp(from, to, step / steps)!;
      final cell = _geometry.cellAt(sample, translation: _paintShift);
      if (cell != null && _mayPaint(cell) && _strokeCells.add(cell)) {
        widget.onNotePaint?.call(cell);
      }
    }
  }

  bool _mayPlace(CellPosition position) {
    if (_holdCommitted ||
        !widget.enablePlacementHold ||
        widget.onPlacementHold == null ||
        !widget.caseData.canOccupy(position)) {
      return false;
    }
    final cell = widget.boardState?.cellAt(position);
    return cell != null && !cell.crossed && cell.characterId == null;
  }

  // Holding on ANY visited cell, including after a drag, can place a suspect.
  // The small idle delay avoids a distracting placement ring while swiping.
  void _scheduleHold(Offset localPosition) {
    _cancelHold();
    final cell = _geometry.cellAt(localPosition, translation: _paintShift);
    // Keep the tap target even when this tool cannot place a character.
    _heldCell = cell;
    _holdAnchor = localPosition;
    if (cell == null || !_mayPlace(cell)) {
      return;
    }
    _holdStartTimer = Timer(MurdokuTokens.placementHoldStartDelay, () {
      if (!mounted ||
          _holdCommitted ||
          _suppressTapUntilAllUp ||
          _pointers.length != 1 ||
          _heldCell != cell ||
          !_mayPlace(cell)) {
        return;
      }
      _holdController.forward(from: 0);
    });
  }

  void _updateHold(Offset localPosition) {
    final cell = _geometry.cellAt(localPosition, translation: _paintShift);
    if (cell != _heldCell ||
        (_holdAnchor != null &&
            (localPosition - _holdAnchor!).distance > kTouchSlop)) {
      _scheduleHold(localPosition);
    }
  }

  void _onDown(PointerDownEvent event) {
    if (_pendingOrigin != null) {
      _snapController.stop();
      _completeSnap();
    }
    // Debug mouse right-drag mirrors two-finger navigation on emulators
    if (kDebugMode &&
        ((event.buttons & (kSecondaryMouseButton | kMiddleMouseButton)) != 0 ||
            HardwareKeyboard.instance.isShiftPressed ||
            HardwareKeyboard.instance.isLogicalKeyPressed(
              LogicalKeyboardKey.space,
            ))) {
      _cancelPress();
      _rightDragPointer = event.pointer;
      _lastRightPosition = event.localPosition;
      return;
    }
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons & kPrimaryMouseButton == 0) {
      return;
    }
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 1 && !_suppressTapUntilAllUp) {
      _tapPointer = event.pointer;
      _tapDownPosition = event.localPosition;
      _holdCommitted = false;
      _scheduleHold(event.localPosition);
    } else {
      // Switch to two-finger navigation without undoing already painted notes.
      _suppressTapUntilAllUp = true;
      _cancelPress();
      _lastCentroid = _pointers.length == 2 ? _centroid() : null;
    }
  }

  void _onMove(PointerMoveEvent event) {
    if (_rightDragPointer == event.pointer && _lastRightPosition != null) {
      final delta = event.localPosition - _lastRightPosition!;
      _lastRightPosition = event.localPosition;
      _applyDrag(delta);
      return;
    }
    if (!_pointers.containsKey(event.pointer)) {
      return;
    }
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 2 && _lastCentroid != null) {
      final now = _centroid();
      final delta = now - _lastCentroid!;
      _lastCentroid = now;
      _applyDrag(delta);
      return;
    }
    if (_holdCommitted) {
      return;
    }
    if (_paintingNotes &&
        event.pointer == _strokePointer &&
        _strokeLastPoint != null) {
      _paintSegment(_strokeLastPoint!, event.localPosition);
      _strokeLastPoint = event.localPosition;
      _updateHold(event.localPosition);
      return;
    }
    if (event.pointer == _tapPointer && _tapDownPosition != null) {
      if ((event.localPosition - _tapDownPosition!).distance > kTouchSlop) {
        if (widget.noteCharacterId != null &&
            widget.onNotePaint != null &&
            widget.boardState != null &&
            !_suppressTapUntilAllUp) {
          _paintingNotes = true;
          _strokePointer = event.pointer;
          _strokeLastPoint = event.localPosition;
          _paintSegment(_tapDownPosition!, event.localPosition);
          _tapPointer = null;
          _tapDownPosition = null;
          _scheduleHold(event.localPosition);
        } else {
          _cancelPress();
        }
      } else {
        _updateHold(event.localPosition);
      }
    }
  }

  void _applyDrag(Offset delta) {
    setState(() => _drag = _geometry.constrainDrag(_drag + delta));
    widget.onPanChanged?.call(_drag);
  }

  void _onUp(PointerEvent event) {
    if (event.pointer == _rightDragPointer) {
      _rightDragPointer = null;
      _lastRightPosition = null;
      _startSnap();
      return;
    }
    if (!_pointers.containsKey(event.pointer)) {
      return;
    }
    final wasNavigating = _lastCentroid != null;
    final isStroke = _paintingNotes && event.pointer == _strokePointer;
    // The release point may be beyond the final delivered move event.
    if (isStroke && event is PointerUpEvent && _strokeLastPoint != null) {
      _paintSegment(_strokeLastPoint!, event.localPosition);
    }
    final shouldTap =
        event is PointerUpEvent &&
        !_suppressTapUntilAllUp &&
        event.pointer == _tapPointer &&
        !_holdCommitted &&
        _heldCell != null;
    final tapped = shouldTap ? _heldCell : null;
    _pointers.remove(event.pointer);
    _cancelPress();
    if (wasNavigating) {
      _lastCentroid = null;
      _startSnap();
    }
    if (_pointers.isEmpty) {
      _suppressTapUntilAllUp = false;
    }
    if (!isStroke && tapped != null) {
      widget.onCellTap?.call(tapped);
    }
  }

  void _startSnap() {
    final target = _geometry.snappedAfterDrag(_drag);
    _pendingOrigin = target;
    _snapFrom = _drag;
    _snapTo = _geometry.translationTo(target);
    _snapController.forward(from: 0);
  }

  void _completeSnap() {
    final target = _pendingOrigin;
    if (target == null) {
      return;
    }
    _pendingOrigin = null;
    setState(() => _drag = Offset.zero);
    widget.onPanChanged?.call(Offset.zero);
    if (target != _geometry.origin) {
      widget.onOriginChanged?.call(target);
    }
  }

  List<Widget> _crossOverlays(BoardViewportGeometry geometry) {
    final board = widget.boardState;
    if (board == null) {
      return const [];
    }
    final shift = _paintShift;
    final result = <Widget>[];
    // Only build crosses that can intersect the visible board region
    for (var row = 0; row < widget.caseData.rows; row++) {
      final top = (row - geometry.origin.row) * widget.cellSize + shift.dy;
      if (top + widget.cellSize <= 0 || top >= geometry.regionSize.height) {
        continue;
      }
      for (var col = 0; col < widget.caseData.columns; col++) {
        final left =
            (col - geometry.origin.column) * widget.cellSize + shift.dx;
        if (left + widget.cellSize <= 0 || left >= geometry.regionSize.width) {
          continue;
        }
        final position = (row: row, column: col);
        if (!widget.caseData.canOccupy(position) ||
            !board.cellAt(position).crossed) {
          continue;
        }
        result.add(
          Positioned(
            key: ValueKey('board-cross-$row-$col'),
            left: left + MurdokuTokens.boardMarkInset,
            top: top + MurdokuTokens.boardMarkInset,
            width: widget.cellSize - MurdokuTokens.boardMarkDoubleInset,
            height: widget.cellSize - MurdokuTokens.boardMarkDoubleInset,
            child: IgnorePointer(
              child: SvgPicture.asset(
                MurdokuAssets.boardCross,
                fit: BoxFit.fill,
                excludeFromSemantics: true,
              ),
            ),
          ),
        );
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final geometry = _geometry;
    return Padding(
      padding: const EdgeInsets.all(MurdokuTokens.panelInset),
      child: Center(
        child: ClipRect(
          child: SizedBox(
            key: const ValueKey('visible-board-region'),
            width: geometry.regionSize.width,
            height: geometry.regionSize.height,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onDown,
              onPointerMove: _onMove,
              onPointerUp: _onUp,
              onPointerCancel: _onUp,
              child: AnimatedBuilder(
                animation: Listenable.merge([_snapController, _holdController]),
                builder: (context, child) => BoardScene(
                  caseData: widget.caseData,
                  cellSize: widget.cellSize,
                  originRow: geometry.origin.row,
                  originColumn: geometry.origin.column,
                  translation: _paintShift,
                  boardState: widget.boardState,
                  feedbackByCell: widget.feedbackByCell,
                  holdCell: _holdController.isAnimating ? _heldCell : null,
                  holdProgress: _holdController.value,
                  paintCrosses: false,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      const SizedBox.expand(),
                      ..._crossOverlays(geometry),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
