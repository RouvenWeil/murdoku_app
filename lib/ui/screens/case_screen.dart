import 'package:flutter/material.dart';

import '../../domain/case_definition.dart';
import '../widgets/board_viewport_stub.dart';
import '../widgets/clue_panel_stub.dart';
import '../widgets/tool_panel_stub.dart';

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
                final clueWidth = (constraints.maxWidth * 0.39)
                    .clamp(220.0, 390.0).toDouble();
                final toolWidth = (constraints.maxWidth * 0.17)
                    .clamp(112.0, 172.0).toDouble();

                return Row(
                  children: [
                    SizedBox(
                      width: clueWidth,
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
                      child: BoardViewportStub(caseData: widget.caseData),
                    ),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: toolWidth,
                      child: ToolPanelStub(caseData: widget.caseData),
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
