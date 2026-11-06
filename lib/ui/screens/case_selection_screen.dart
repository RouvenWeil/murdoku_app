import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/case_loader.dart';
import '../../domain/case_definition.dart';
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
    _cases = Future.wait(_caseIds.map(CaseLoader.load));
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
                    const SizedBox(height: 12),
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
            return LayoutBuilder(
              builder: (context, constraints) {
                // Portrait uses a single list while wider views reuse the same case cards
                final columns = constraints.maxWidth < 600
                    ? 1
                    : constraints.maxWidth < 1000
                    ? 2
                    : 3;
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cases.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 144,
                  ),
                  itemBuilder: (context, index) {
                    final caseData = cases[index];
                    final solved =
                        _progressStore.read(caseData.id)?.isSolved ?? false;
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _openingCase ? null : () => _openCase(caseData),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                caseData.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Spacer(),
                              Text(
                                '${caseData.rows} × ${caseData.columns}  ·  '
                                '${caseData.difficulty.replaceAll('-', ' ')}',
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (solved) ...[
                                    const Icon(
                                      Icons.check_circle_outline,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text('Solved'),
                                  ] else
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
