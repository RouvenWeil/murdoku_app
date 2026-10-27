import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/case_definition.dart';
import '../domain/object_definition.dart';

class CaseLoader {
  const CaseLoader._();

  static Future<CaseDefinition> load(String caseId) async {
    // Shared object metadata resolved at the loading boundary case files contain only object references and scene placement
    final catalogSource = await rootBundle.loadString(
      'assets/object-catalog.json',
    );
    final rawCatalog = jsonDecode(catalogSource) as Map<String, dynamic>;
    final objectCatalog = {
      for (final entry in rawCatalog.entries)
        entry.key: ObjectDefinition.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        ),
    };

    final caseSource = await rootBundle.loadString('assets/cases/$caseId.json');
    final caseJson = jsonDecode(caseSource) as Map<String, dynamic>;

    return CaseDefinition.fromJson(caseJson, objectCatalog: objectCatalog);
  }
}
