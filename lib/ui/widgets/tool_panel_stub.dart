import 'package:flutter/material.dart';

import '../../domain/case_definition.dart';

enum ToolPanelArrangement { expanded, horizontal, stacked, singleColumn }

class ToolPanelStub extends StatelessWidget {
  const ToolPanelStub({
    super.key,
    required this.caseData,
    required this.showMinimap,
    required this.arrangement,
    required this.minimapWidth,
    required this.minimapHeight,
  });

  final CaseDefinition caseData;
  final bool showMinimap;
  final ToolPanelArrangement arrangement;
  final double minimapWidth;
  final double minimapHeight;

  @override
  Widget build(BuildContext context) {
    if (showMinimap) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            SizedBox(
              key: const ValueKey('case-minimap'),
              width: minimapWidth,
              height: minimapHeight,
              child: Semantics(
                label: 'Board overview minimap',
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: const Center(child: Icon(Icons.map_outlined)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (arrangement == ToolPanelArrangement.horizontal) ...[
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CompactToolPlaceholder(icon: Icons.close, tooltip: 'Cross'),
                  _CompactToolPlaceholder(
                    icon: Icons.auto_fix_off,
                    tooltip: 'Erase',
                  ),
                  _CompactToolPlaceholder(icon: Icons.undo, tooltip: 'Undo'),
                ],
              ),
              const SizedBox(height: 8),
            ] else if (arrangement == ToolPanelArrangement.stacked) ...[
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CompactToolPlaceholder(icon: Icons.close, tooltip: 'Cross'),
                  _CompactToolPlaceholder(
                    icon: Icons.auto_fix_off,
                    tooltip: 'Erase',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const _CompactTextToolPlaceholder(label: 'Undo'),
              const SizedBox(height: 8),
            ] else if (arrangement == ToolPanelArrangement.singleColumn) ...[
              const _CompactTextToolPlaceholder(label: 'Cross'),
              const SizedBox(height: 8),
              const _CompactTextToolPlaceholder(label: 'Erase'),
              const SizedBox(height: 8),
              const _CompactTextToolPlaceholder(label: 'Undo'),
              const SizedBox(height: 8),
            ],
            const SizedBox(
              height: 48,
              width: double.infinity,
              child: FilledButton(onPressed: null, child: Text('Submit')),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: const [
        Text('Tools', style: TextStyle(fontWeight: FontWeight.w600)),
        SizedBox(height: 8),
        _ToolPlaceholder(icon: Icons.close, label: 'Cross'),
        _ToolPlaceholder(icon: Icons.edit_note, label: 'Note'),
        _ToolPlaceholder(icon: Icons.auto_fix_off, label: 'Erase'),
        _ToolPlaceholder(icon: Icons.undo, label: 'Undo'),
        SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: FilledButton(onPressed: null, child: Text('Submit')),
        ),
      ],
    );
  }
}

class _CompactToolPlaceholder extends StatelessWidget {
  const _CompactToolPlaceholder({required this.icon, required this.tooltip});

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 48,
        child: OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(48, 48),
          ),
          child: Icon(icon),
        ),
      ),
    );
  }
}

class _CompactTextToolPlaceholder extends StatelessWidget {
  const _CompactTextToolPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _ToolPlaceholder extends StatelessWidget {
  const _ToolPlaceholder({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: null,
          icon: Icon(icon),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
