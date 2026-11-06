import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/case_loader.dart';
import '../../domain/case_definition.dart';
import '../design/murdoku_tokens.dart';
import '../design/murdoku_typography.dart';
import '../session/game_progress_store.dart';
import '../widgets/murdoku_brand.dart';
import 'case_screen.dart';

class CaseSelectionScreen extends StatefulWidget {
  const CaseSelectionScreen({super.key, this.progressStore});

  final GameProgressStore? progressStore;

  @override
  State<CaseSelectionScreen> createState() => _CaseSelectionScreenState();
}

class _CaseSelectionScreenState extends State<CaseSelectionScreen> {
  // Case IDs remain the only navigation list while titles and metadata come from JSON
  static const _caseIds = <String>[
    'car-repair',
    'horse-with-no-name',
    'river-crossing',
    'art-museum-heist',
    'golf-course',
  ];

  GameProgressStore get _progressStore =>
      widget.progressStore ?? GameProgressStore.instance;

  late Future<List<CaseDefinition>> _cases;
  bool _openingCase = false;

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  void _loadCases() {
    _cases = () async {
      final cases = await Future.wait(_caseIds.map(CaseLoader.load));
      // Each load failure is isolated to its own case card.
      await Future.wait(cases.map(_progressStore.ensureLoaded));
      return cases;
    }();
  }

  Future<void> _retryCase(CaseDefinition caseData) async {
    await _progressStore.retryLoad(caseData);
    if (mounted) setState(() {});
  }

  Future<void> _archiveAndReset(CaseDefinition caseData) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive damaged progress?'),
        content: const Text(
          'The unreadable save will be preserved in an '
          'archive. This case will start with an empty board.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive and start fresh'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    try {
      await _progressStore.startFreshAfterFailure(caseData);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not archive damaged progress.')),
        );
      }
    }
  }

  Future<void> _showRecovery(CaseDefinition caseData) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Progress unavailable'),
        content: const Text(
          'This case has an unreadable save. Retry without '
          'changing it, or archive it before starting a new attempt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'retry'),
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'archive'),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'retry') {
      await _retryCase(caseData);
    } else if (choice == 'archive') {
      await _archiveAndReset(caseData);
    }
  }

  Future<void> _openCase(CaseDefinition caseData) async {
    if (_openingCase) return;
    setState(() => _openingCase = true);

    try {
      // Orientation restriction applies only during a case route
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              CaseScreen(caseData: caseData, progressStore: _progressStore),
        ),
      );
    } finally {
      // No orientation preference remains when returning to case selection
      await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
      if (mounted) setState(() => _openingCase = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const MurdokuBrand(logoHeight: 28)),
      body: SafeArea(
        child: FutureBuilder<List<CaseDefinition>>(
          future: _cases,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Case files could not be loaded'),
                    const SizedBox(height: MurdokuTokens.space12),
                    OutlinedButton(
                      onPressed: () => setState(_loadCases),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final cases = snapshot.data!;
            final typography = MurdokuTypography.forViewport(
              MediaQuery.sizeOf(context).width,
            );
            final textScaleFactor =
                MediaQuery.textScalerOf(context)
                    .scale(MurdokuTypography.compactBodySize) /
                MurdokuTypography.compactBodySize;
            // Keep the catalogue's metadata and status visible when the user
            // enables larger text; the grid remains scrollable.
            final cardHeight =
                MurdokuTokens.caseCardHeight * math.max(1.0, textScaleFactor);
            return LayoutBuilder(
              builder: (context, constraints) {
                // Portrait uses a single list while wider views reuse the same case cards
                final columns = constraints.maxWidth < 600
                    ? 1
                    : constraints.maxWidth < 1000
                    ? 2
                    : 3;
                return GridView.builder(
                  padding: const EdgeInsets.all(MurdokuTokens.space16),
                  itemCount: cases.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: MurdokuTokens.space12,
                    mainAxisSpacing: MurdokuTokens.space12,
                    mainAxisExtent: cardHeight,
                  ),
                  itemBuilder: (context, index) {
                    final caseData = cases[index];
                    final solved =
                        _progressStore.read(caseData.id)?.isSolved ?? false;
                    final failed =
                        _progressStore.status(caseData.id) ==
                        ProgressLoadStatus.failed;
                    final recovered =
                        _progressStore.status(caseData.id) ==
                        ProgressLoadStatus.recovered;
                    final unsaved =
                        _progressStore.saveError(caseData.id) != null;
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _openingCase
                            ? null
                            : failed
                            ? () => _showRecovery(caseData)
                            : () => _openCase(caseData),
                        child: Padding(
                          padding: const EdgeInsets.all(MurdokuTokens.space16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                caseData.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: typography.catalogTitle,
                              ),
                              const Spacer(),
                              Text(
                                '${caseData.rows} × ${caseData.columns}  ·  '
                                '${caseData.difficulty.replaceAll('-', ' ')}',
                              ),
                              const SizedBox(height: MurdokuTokens.space4),
                              if (failed)
                                const Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, size: 18),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Save unavailable · Tap to recover',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Row(
                                  children: [
                                    if (unsaved)
                                      Text(
                                        solved
                                            ? 'Solved · Not saved'
                                            : 'Not saved · Retry in case',
                                      )
                                    else if (solved) ...[
                                      const Icon(
                                        Icons.check_circle_outline,
                                        size: MurdokuTokens.caseStatusIconSize,
                                      ),
                                      const SizedBox(
                                        width: MurdokuTokens.space6,
                                      ),
                                      const Text('Solved'),
                                    ] else if (recovered)
                                      const Text('Recovered saved progress')
                                    else
                                      const Text('Open case'),
                                    const Spacer(),
                                    const Icon(Icons.arrow_forward_rounded),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
