import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/case_definition.dart';
import '../../domain/character_definition.dart';
import '../design/murdoku_assets.dart';
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
    this.placedCharacterIds = const {},
  });

  final CaseDefinition caseData;
  final String? selectedCharacterId;
  final ValueChanged<String> onCharacterSelected;
  final String? pinnedClueId;
  final ValueChanged<String> onPinClue;
  final VoidCallback onBack;
  final Set<String> placedCharacterIds;

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
    final card = CharacterClueCard(
      key: ValueKey('clue-$id'),
      character: character,
      typography: typography,
      portraitAsset: _portraitFor(character),
      isPinned: pinnedClueId == id,
      isSelected: selectedCharacterId == character.id,
      onSelect: () => onCharacterSelected(character.id),
      onPin: () => onPinClue(id),
    );
    return placedCharacterIds.contains(character.id)
        ? Opacity(opacity: MurdokuTokens.placedClueOpacity, child: card)
        : card;
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
          padding: const EdgeInsets.fromLTRB(
            MurdokuTokens.space8,
            MurdokuTokens.space8,
            MurdokuTokens.space8,
            MurdokuTokens.space4,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                tooltip: 'Back to cases',
                iconSize: MurdokuTokens.minTouchSize,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: MurdokuTokens.minTouchSize,
                  height: MurdokuTokens.minTouchSize,
                ),
                icon: SvgPicture.asset(
                  MurdokuAssets.back,
                  width: MurdokuTokens.minTouchSize,
                  height: MurdokuTokens.minTouchSize,
                  excludeFromSemantics: true,
                ),
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MurdokuTokens.space8,
                    vertical: MurdokuTokens.space4,
                  ),
                  child: MurdokuBrand(),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MurdokuTokens.space8,
            MurdokuTokens.space4,
            MurdokuTokens.space8,
            MurdokuTokens.space12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  caseData.title,
                  maxLines: 2,
                  style: typography.heading,
                ),
              ),
              const SizedBox(width: MurdokuTokens.space8),
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
                  if (pinned != null)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.55,
                      ),
                      child: SingleChildScrollView(
                        key: const ValueKey('pinned-clue-region'),
                        padding: const EdgeInsets.fromLTRB(
                          MurdokuTokens.panelInset,
                          MurdokuTokens.space4,
                          MurdokuTokens.panelInset,
                          0,
                        ),
                        child: pinned,
                      ),
                    ),
                  if (pinned != null)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: MurdokuTokens.space8,
                      ),
                      child: Divider(height: 1),
                    ),
                  Expanded(
                    child: ListView(
                      key: const ValueKey('unpinned-clue-list'),
                      padding: const EdgeInsets.fromLTRB(
                        MurdokuTokens.space8,
                        MurdokuTokens.space4,
                        MurdokuTokens.space8,
                        MurdokuTokens.space8,
                      ),
                      children: [
                        if (caseData.generalClues.isNotEmpty) ...[
                          for (var i = 0; i < caseData.generalClues.length; i++)
                            if (pinnedClueId != generalId(i))
                              _generalCard(i, typography),
                          const SizedBox(height: MurdokuTokens.space8),
                        ],
                        for (final character in caseData.characters)
                          if (!placedCharacterIds.contains(character.id) &&
                              pinnedClueId != characterId(character.id))
                            _characterCard(character, typography),
                        for (final character in caseData.characters)
                          if (placedCharacterIds.contains(character.id) &&
                              pinnedClueId != characterId(character.id))
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
