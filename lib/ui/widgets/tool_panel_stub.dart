import 'package:flutter/material.dart';

import '../../domain/case_definition.dart';

class ToolPanelStub extends StatelessWidget {
  const ToolPanelStub({super.key, required this.caseData});

  final CaseDefinition caseData;

  @override
  Widget build(BuildContext context) {
    final showOverview = caseData.rows > 9 || caseData.columns > 9;
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        if (showOverview) ...[
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              alignment: Alignment.center,
              child: const Text('Minimap\nslot', textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const Text('Tools', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const _ToolPlaceholder(icon: Icons.close, label: 'Cross'),
        const _ToolPlaceholder(icon: Icons.edit_note, label: 'Note'),
        const _ToolPlaceholder(icon: Icons.auto_fix_off, label: 'Erase'),
        const _ToolPlaceholder(icon: Icons.undo, label: 'Undo'),
        const SizedBox(height: 12),
        const FilledButton(onPressed: null, child: Text('Submit')),
      ],
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
      child: OutlinedButton.icon(
        onPressed: null,
        icon: Icon(icon),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
