import 'package:flutter/material.dart';

import '../../domain/case_definition.dart';

class CluePanelStub extends StatelessWidget {
  const CluePanelStub({
    super.key,
    required this.caseData,
    required this.selectedCharacterId,
    required this.onCharacterSelected,
    required this.onBack,
  });

  final CaseDefinition caseData;
  final String? selectedCharacterId;
  final ValueChanged<String> onCharacterSelected;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              tooltip: 'Back to cases',
              icon: const Icon(Icons.arrow_back),
            ),
            const Expanded(
              child: Text(
                'MURDOKU',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  caseData.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              const Text('Timer —'),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            children: [
              if (caseData.generalClues.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Text('General clues'),
                ),
                for (final clue in caseData.generalClues)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(clue),
                    ),
                  ),
              ],
              for (final character in caseData.characters)
                Card(
                  color: selectedCharacterId == character.id
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: InkWell(
                    onTap: () => onCharacterSelected(character.id),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(child: Text(character.id)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  character.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(character.clue),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
