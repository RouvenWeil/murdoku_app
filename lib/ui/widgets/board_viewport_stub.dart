import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/board_state.dart';
import '../../domain/case_definition.dart';
import '../../domain/solution_evaluation.dart';
import '../board/board_scene_painter.dart';
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
                !_suppressTapUntilAllUp &&
                _pointers.length == 1) {
              _holdCommitted = true;
              widget.onPlacementHold?.call(_heldCell!);
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
      _holdController.stop();
      _heldCell = null;
    }
  }

  @override
  void dispose() {
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

  void _cancelPress() {
    _tapPointer = null;
    _tapDownPosition = null;
    _heldCell = null;
    _holdController.stop();
    _holdController.reset();
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
      _heldCell = _geometry.cellAt(
        event.localPosition,
        translation: _paintShift,
      );
      if (_heldCell != null &&
          widget.enablePlacementHold &&
          widget.onPlacementHold != null &&
          widget.caseData.canOccupy(_heldCell!) &&
          widget.boardState?.cellAt(_heldCell!).crossed != true &&
          widget.boardState?.cellAt(_heldCell!).characterId == null) {
        _holdController.forward(from: 0);
      } else {
        _holdController.reset();
      }
    } else {
      // A second touch cancels any pending placement even if it later lifts
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
    if (event.pointer == _tapPointer &&
        _tapDownPosition != null &&
        (event.localPosition - _tapDownPosition!).distance > kTouchSlop) {
      _cancelPress();
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
    if (tapped != null) {
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
    if (board == null) return const [];
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
                builder: (context, child) => CustomPaint(
                  painter: BoardScenePainter(
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
                  ),
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
