import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/board_state.dart';
import '../../domain/case_definition.dart';
import '../../domain/solution_evaluation.dart';
import '../board/board_scene_painter.dart';
import '../board/board_viewport_geometry.dart';
import '../design/murdoku_assets.dart';
import '../design/murdoku_tokens.dart';
import '../design/murdoku_typography.dart';
import 'murdoku_buttons.dart';

enum BoardTool { note, cross, erase }

enum ToolPanelArrangement { expanded, horizontal, stacked, singleColumn }

class ToolPanelStub extends StatelessWidget {
  const ToolPanelStub({
    super.key,
    required this.caseData,
    required this.showMinimap,
    required this.arrangement,
    required this.minimapWidth,
    required this.minimapHeight,
    this.origin = const (row: 0, column: 0),
    this.visibleRows = 1,
    this.visibleColumns = 1,
    this.boardCellSize = MurdokuTokens.minTouchSize,
    this.boardPan = Offset.zero,
    this.onMinimapNavigate,
    this.boardState,
    this.feedbackByCell = const {},
    this.activeTool = BoardTool.note,
    this.onToolSelected,
    this.onUndo,
    this.onSubmit,
    this.onClearAll,
    this.crossEnabled = true,
    this.noteEnabled = true,
    this.eraseEnabled = true,
    this.isSolved = false,
    this.onReplay,
  });

  final CaseDefinition caseData;
  final bool showMinimap;
  final ToolPanelArrangement arrangement;
  final double minimapWidth;
  final double minimapHeight;
  final BoardOrigin origin;
  final int visibleRows;
  final int visibleColumns;
  final double boardCellSize;
  final Offset boardPan;
  final ValueChanged<BoardOrigin>? onMinimapNavigate;
  final BoardState? boardState;
  final Map<CellPosition, PlacementVerdict> feedbackByCell;
  final BoardTool activeTool;
  final ValueChanged<BoardTool>? onToolSelected;
  final VoidCallback? onUndo;
  final VoidCallback? onSubmit;
  final VoidCallback? onClearAll;
  final bool crossEnabled;
  final bool noteEnabled;
  final bool eraseEnabled;
  final bool isSolved;
  final VoidCallback? onReplay;

  @override
  Widget build(BuildContext context) {
    final typography = MurdokuTypography.forViewport(
      MediaQuery.sizeOf(context).width,
    );
    if (showMinimap) {
      final geometry = BoardViewportGeometry(
        rows: caseData.rows,
        columns: caseData.columns,
        visibleRows: visibleRows,
        visibleColumns: visibleColumns,
        cellSize: boardCellSize,
        origin: origin,
      );
      final mapSize = Size(minimapWidth, minimapHeight);
      void navigate(Offset point) =>
          onMinimapNavigate?.call(geometry.centerOnMinimap(point, mapSize));
      return Padding(
        padding: const EdgeInsets.all(MurdokuTokens.panelInset),
        child: Column(
          children: [
            SizedBox(
              key: const ValueKey('case-minimap'),
              width: minimapWidth,
              height: minimapHeight,
              child: Semantics(
                label: 'Board overview minimap',
                hint: 'Tap or drag to navigate the board',
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: onMinimapNavigate == null
                      ? null
                      : (details) => navigate(details.localPosition),
                  onPanUpdate: onMinimapNavigate == null
                      ? null
                      : (details) => navigate(details.localPosition),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: CustomPaint(
                      painter: BoardScenePainter(
                        caseData: caseData,
                        cellSize: minimapWidth / caseData.columns,
                        boardState: boardState,
                        feedbackByCell: feedbackByCell,
                        viewportOutline: geometry.viewportOnMinimap(
                          mapSize,
                          drag: boardPan,
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: MurdokuTokens.space8),
            if (arrangement == ToolPanelArrangement.horizontal) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _tool('Cross', typography, iconOnly: true),
                  _tool('Erase', typography, iconOnly: true),
                  _tool('Undo', typography, iconOnly: true),
                ],
              ),
              const SizedBox(height: MurdokuTokens.space8),
            ] else if (arrangement == ToolPanelArrangement.stacked) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _tool('Cross', typography, iconOnly: true),
                  _tool('Erase', typography, iconOnly: true),
                ],
              ),
              const SizedBox(height: MurdokuTokens.space8),
              _tool('Undo', typography, textOnly: true),
              const SizedBox(height: MurdokuTokens.space8),
            ] else if (arrangement == ToolPanelArrangement.singleColumn) ...[
              _tool('Cross', typography, textOnly: true),
              const SizedBox(height: MurdokuTokens.space8),
              _tool('Erase', typography, textOnly: true),
              const SizedBox(height: MurdokuTokens.space8),
              _tool('Undo', typography, textOnly: true),
              const SizedBox(height: MurdokuTokens.space8),
            ],
            MurdokuSubmitButton(
              onPressed: isSolved ? onReplay : onSubmit,
              typography: typography,
              isSolved: isSolved,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(MurdokuTokens.panelInset),
      children: [
        Text('Tools', style: typography.toolHeading),
        const SizedBox(height: MurdokuTokens.space8),
        _tool('Cross', typography),
        const SizedBox(height: MurdokuTokens.space8),
        _tool('Note', typography),
        const SizedBox(height: MurdokuTokens.space8),
        _tool('Erase', typography),
        const SizedBox(height: MurdokuTokens.space8),
        _tool('Undo', typography),
        const SizedBox(height: MurdokuTokens.space12),
        MurdokuSubmitButton(
          onPressed: isSolved ? onReplay : onSubmit,
          typography: typography,
          isSolved: isSolved,
        ),
      ],
    );
  }

  Widget _tool(
    String kind,
    MurdokuTypography typography, {
    bool iconOnly = false,
    bool textOnly = false,
  }) {
    final label = switch (kind) {
      'Cross' => 'Place\nCross',
      'Note' => 'Notes',
      'Erase' => 'Erase Cell',
      'Undo' => 'UNDO',
      _ => kind,
    };
    final subtitle = kind == 'Erase' ? 'hold to reset Progress' : null;
    final svg = switch (kind) {
      'Cross' => MurdokuAssets.crossTool,
      'Erase' => MurdokuAssets.eraseTool,
      'Undo' => MurdokuAssets.undoTool,
      _ => null,
    };
    final tool = switch (kind) {
      'Cross' => BoardTool.cross,
      'Erase' => BoardTool.erase,
      'Note' => BoardTool.note,
      _ => null,
    };
    final available = switch (kind) {
      'Cross' => crossEnabled,
      'Note' => noteEnabled,
      'Erase' => eraseEnabled,
      _ => true,
    };
    final onPressed = !available
        ? null
        : kind == 'Undo'
        ? onUndo
        : tool == null || onToolSelected == null
        ? null
        : () => onToolSelected!(tool);

    MurdokuToolButton buildButton(VoidCallback? shortPress) =>
        MurdokuToolButton(
          key: ValueKey('tool-${kind.toLowerCase()}'),
          label: label,
          subtitle: subtitle,
          onPressed: shortPress,
          typography: typography,
          iconAsset: textOnly ? null : svg,
          fallbackIcon: kind == 'Note' && !textOnly ? Icons.edit_note : null,
          showLabel: !iconOnly,
          selected: tool != null && activeTool == tool,
        );

    if (kind != 'Erase' || onClearAll == null || !eraseEnabled) {
      return buildButton(onPressed);
    }
    return _HoldToClearButton(
      key: const ValueKey('hold-clear-button'),
      onClearAll: onClearAll!,
      childBuilder: buildButton,
      onShortPress: onPressed,
    );
  }
}

// A destructive hold must complete before clearing; short tap selects Erase
class _HoldToClearButton extends StatefulWidget {
  const _HoldToClearButton({
    super.key,
    required this.onClearAll,
    required this.childBuilder,
    this.onShortPress,
  });

  final VoidCallback onClearAll;
  final VoidCallback? onShortPress;
  final Widget Function(VoidCallback? onPressed) childBuilder;

  @override
  State<_HoldToClearButton> createState() => _HoldToClearButtonState();
}

class _HoldToClearButtonState extends State<_HoldToClearButton>
    with SingleTickerProviderStateMixin {
  static const holdDuration = MurdokuTokens.resetHoldDuration;
  late final AnimationController _hold =
      AnimationController(vsync: this, duration: holdDuration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed &&
              _pointer != null &&
              !_moved) {
            _completed = true;
            widget.onClearAll();
          }
        });

  int? _pointer;
  Offset? _start;
  bool _moved = false;
  bool _completed = false;

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null) {
      // A second touch cancels destructive clear progress
      _moved = true;
      _hold.stop();
      _hold.reset();
      return;
    }
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons & kPrimaryMouseButton == 0) {
      return;
    }
    _pointer = event.pointer;
    _start = event.localPosition;
    _moved = false;
    _completed = false;
    _hold.forward(from: 0);
  }

  void _move(PointerMoveEvent event) {
    if (_pointer != event.pointer || _start == null) {
      return;
    }
    if ((event.localPosition - _start!).distance > kTouchSlop) {
      _moved = true;
      _hold.stop();
      _hold.reset();
    }
  }

  void _up(PointerEvent event) {
    if (!mounted || _pointer != event.pointer) {
      return;
    }

    _pointer = null;
    _start = null;
    _hold.stop();
    _hold.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: AnimatedBuilder(
        animation: _hold,
        builder: (context, child) => CustomPaint(
          foregroundPainter: _ClearProgressPainter(_hold.value),
          child: child,
        ),
        child: widget.childBuilder(
          widget.onShortPress == null
              ? null
              : () {
                  if (!_completed) {
                    widget.onShortPress!();
                  }
                },
        ),
      ),
    );
  }
}

class _ClearProgressPainter extends CustomPainter {
  const _ClearProgressPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) {
      return;
    }
    final radius = (size.shortestSide / 2 - MurdokuTokens.space4)
        .clamp(2.0, 1000.0)
        .toDouble();
    canvas.drawArc(
      Rect.fromCircle(center: size.center(Offset.zero), radius: radius),
      -1.5707963267948966,
      progress * 6.283185307179586,
      false,
      Paint()
        ..color = MurdokuTokens.selected
        ..strokeWidth = MurdokuTokens.paintStrokeWidth
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_ClearProgressPainter old) => old.progress != progress;
}
