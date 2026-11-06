import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/case_definition.dart';
import '../../domain/character_definition.dart';
import '../design/murdoku_tokens.dart';
import '../design/murdoku_typography.dart';
import 'clue_cards.dart';
import 'murdoku_brand.dart';

class CluePanelStub extends StatelessWidget {
  const CluePanelStub({
    super.key,
    required this.caseData,
    required this.selectedCharacterId,
    required this.onCharacterSelected,
    required this.pinnedClueId,
    required this.onPinClue,
    required this.onBack,
  });

  final CaseDefinition caseData;
  final String? selectedCharacterId;
  final ValueChanged<String> onCharacterSelected;
  final String? pinnedClueId;
  final ValueChanged<String> onPinClue;
  final VoidCallback onBack;

  static String generalId(int index) => 'general:$index';
  static String characterId(String id) => 'character:$id';

  String? _portraitFor(CharacterDefinition character) {
    if (character.imageAsset != null) return character.imageAsset;
    if (caseData.id == 'car-repair' &&
        const {'A', 'B', 'C', 'D', 'E', 'V'}.contains(character.id)) {
      return 'assets/characters/car-repair/${character.id.toLowerCase()}.png';
    }
    return null;
  }

  Widget _generalCard(int index, MurdokuTypography typography) {
    final id = generalId(index);
    return GeneralClueCard(
      key: ValueKey('clue-$id'),
      clue: caseData.generalClues[index],
      typography: typography,
      isPinned: pinnedClueId == id,
      onPin: () => onPinClue(id),
    );
  }

  Widget _characterCard(
    CharacterDefinition character,
    MurdokuTypography typography,
  ) {
    final id = characterId(character.id);
    return CharacterClueCard(
      key: ValueKey('clue-$id'),
      character: character,
      typography: typography,
      portraitAsset: _portraitFor(character),
      isPinned: pinnedClueId == id,
      isSelected: selectedCharacterId == character.id,
      onSelect: () => onCharacterSelected(character.id),
      onPin: () => onPinClue(id),
    );
  }

  Widget? _pinnedCard(MurdokuTypography typography) {
    final pin = pinnedClueId;
    if (pin == null) return null;
    if (pin.startsWith('general:')) {
      final index = int.tryParse(pin.substring('general:'.length));
      if (index != null && index >= 0 && index < caseData.generalClues.length) {
        return _generalCard(index, typography);
      }
    }
    if (pin.startsWith('character:')) {
      final id = pin.substring('character:'.length);
      for (final character in caseData.characters) {
        if (character.id == id) return _characterCard(character, typography);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final typography = MurdokuTypography.forViewport(
      MediaQuery.sizeOf(context).width,
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                tooltip: 'Back to cases',
                iconSize: 48,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                icon: SvgPicture.asset(
                  'assets/ui/IconButton-Back.svg',
                  width: 48,
                  height: 48,
                  excludeFromSemantics: true,
                ),
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: MurdokuBrand(),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  caseData.title,
                  maxLines: 2,
                  style: typography.heading,
                ),
              ),
              const SizedBox(width: 8),
              Text('Timer —', style: typography.body),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final pinned = _pinnedCard(typography);
              return Column(
                children: [
                  if (pinned != null) ...[
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.55,
                      ),
                      child: SingleChildScrollView(
                        key: const ValueKey('pinned-clue-region'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: MurdokuTokens.panelInset,
                          vertical: 4,
                        ),
                        child: pinned,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsGeometry.symmetric(horizontal: 8),
                      child: const Divider(height: 1),
                    ),
                  ],
                  Expanded(
                    child: ListView(
                      key: const ValueKey('unpinned-clue-list'),
                      padding: const EdgeInsets.all(8),
                      children: [
                        if (caseData.generalClues.isNotEmpty) ...[
                          for (var i = 0; i < caseData.generalClues.length; i++)
                            if (pinnedClueId != generalId(i))
                              _generalCard(i, typography),
                          const SizedBox(height: 8),
                        ],
                        for (final character in caseData.characters)
                          if (pinnedClueId != characterId(character.id))
                            _characterCard(character, typography),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
