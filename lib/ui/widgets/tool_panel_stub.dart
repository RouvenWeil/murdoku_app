import 'package:flutter/material.dart';

import '../../domain/case_definition.dart';
import '../design/murdoku_typography.dart';
import 'murdoku_buttons.dart';

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
    final typography = MurdokuTypography.forViewport(
      MediaQuery.sizeOf(context).width,
    );
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _tool('Cross', typography, iconOnly: true),
                  _tool('Erase', typography, iconOnly: true),
                  _tool('Undo', typography, iconOnly: true),
                ],
              ),
              const SizedBox(height: 8),
            ] else if (arrangement == ToolPanelArrangement.stacked) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _tool('Cross', typography, iconOnly: true),
                  _tool('Erase', typography, iconOnly: true),
                ],
              ),
              const SizedBox(height: 8),
              _tool('Undo', typography, textOnly: true),
              const SizedBox(height: 8),
            ] else if (arrangement == ToolPanelArrangement.singleColumn) ...[
              _tool('Cross', typography, textOnly: true),
              const SizedBox(height: 8),
              _tool('Erase', typography, textOnly: true),
              const SizedBox(height: 8),
              _tool('Undo', typography, textOnly: true),
              const SizedBox(height: 8),
            ],
            MurdokuSubmitButton(onPressed: null, typography: typography),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Text(
          'Tools',
          style: typography.heading.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _tool('Cross', typography),
        const SizedBox(height: 8),
        _tool('Note', typography),
        const SizedBox(height: 8),
        _tool('Erase', typography),
        const SizedBox(height: 8),
        _tool('Undo', typography),
        const SizedBox(height: 12),
        MurdokuSubmitButton(onPressed: null, typography: typography),
      ],
    );
  }

  Widget _tool(
    String label,
    MurdokuTypography typography, {
    bool iconOnly = false,
    bool textOnly = false,
  }) {
    final svg = switch (label) {
      'Cross' => 'assets/ui/Vector-CrossOut.svg',
      'Erase' => 'assets/ui/Vector-Eraser.svg',
      'Undo' => 'assets/ui/Vector-Undo.svg',
      _ => null,
    };
    return MurdokuToolButton(
      label: label,
      onPressed: null,
      typography: typography,
      iconAsset: textOnly ? null : svg,
      fallbackIcon: label == 'Note' && !textOnly ? Icons.edit_note : null,
      showLabel: !iconOnly,
    );
  }
}
