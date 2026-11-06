import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/case_definition.dart';
import '../design/murdoku_tokens.dart';
import '../design/murdoku_typography.dart';
import '../session/game_progress_store.dart';
import 'case_preview.dart';

class CaseCatalogueCard extends StatelessWidget {
  const CaseCatalogueCard({
    super.key,
    required this.caseData,
    required this.status,
    required this.onOpen,
    this.progress,
    this.unsaved = false,
  });

  final CaseDefinition caseData;
  final CaseAttemptStatus status;
  final GameProgress? progress;
  final bool unsaved;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final solved = status == CaseAttemptStatus.solved;
    final saveNote = unsaved ? ', not saved' : '';
    final unavailable = status == CaseAttemptStatus.unavailable;
    final typography = MurdokuTypography.forViewport(
      MediaQuery.sizeOf(context).width,
    );
    final statusText = switch (status) {
      CaseAttemptStatus.notStarted => 'Not started',
      CaseAttemptStatus.inProgress => 'In progress',
      CaseAttemptStatus.solved => 'Solved',
      CaseAttemptStatus.unavailable => 'Progress unavailable',
    };
    final statusIcon = switch (status) {
      CaseAttemptStatus.notStarted => Icons.radio_button_unchecked,
      CaseAttemptStatus.inProgress => Icons.pending_outlined,
      CaseAttemptStatus.solved => Icons.check_circle_outline,
      CaseAttemptStatus.unavailable => Icons.warning_amber_rounded,
    };
    return Card(
      key: ValueKey('case-card-${caseData.id}'),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        label:
            '${caseData.title}, $statusText$saveNote. '
            '${caseData.rows} by ${caseData.columns} cells',
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(MurdokuTokens.space12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // A little board preview is more useful than another line of
                // text, but it must not squeeze the case name/status away.
                final previewWidth = math.min(
                  MurdokuTokens.casePreviewWidth,
                  constraints.maxWidth * 0.38,
                );
                return Row(
                  children: [
                    SizedBox(
                      width: previewWidth,
                      child: Align(
                        alignment: Alignment.center,
                        child: CasePreview(
                          caseData: caseData,
                          boardState: unavailable ? null : progress?.board,
                          feedbackByCell: unavailable
                              ? const {}
                              : progress?.feedbackByCell ?? const {},
                          isSolved: solved,
                        ),
                      ),
                    ),
                    const SizedBox(width: MurdokuTokens.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            caseData.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: typography.catalogTitle,
                          ),
                          const SizedBox(height: MurdokuTokens.space4),
                          Text(
                            '${caseData.rows} × ${caseData.columns}  ·  '
                            '${caseData.difficulty.replaceAll('-', ' ')}',
                            maxLines: 2,
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Icon(
                                statusIcon,
                                size: MurdokuTokens.caseStatusIconSize,
                                color: solved
                                    ? MurdokuTokens.boardCorrect
                                    : null,
                              ),
                              const SizedBox(width: MurdokuTokens.space6),
                              Expanded(
                                child: Text(
                                  statusText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: solved
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                          if (unsaved) ...[
                            const SizedBox(height: MurdokuTokens.space4),
                            const Text(
                              'Not saved',
                              style: TextStyle(
                                color: MurdokuTokens.boardIncorrect,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
