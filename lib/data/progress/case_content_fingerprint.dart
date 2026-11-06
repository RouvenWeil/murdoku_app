import 'dart:convert';

import '../../domain/case_definition.dart';

/// A deterministic content identity, not a security hash. Art-file paths and
/// unrelated catalog entries are excluded so replacing illustrations won't
/// invalidate correct progress. Room geometry, objects, clues and solutions
/// are included to detect authored-case changes.
abstract final class CaseContentFingerprint {
  static String forCase(CaseDefinition c) {
    final usedObjects = <String>{
      for (final row in c.objectGrid)
        for (final id in row) ?id,
    }.toList()..sort();
    final roomIds = c.roomNames.keys.toList()..sort();
    final characters = [...c.characters]..sort((a, b) => a.id.compareTo(b.id));
    final canonical = jsonEncode([
      c.id,
      c.rows,
      c.columns,
      c.roomGrid,
      c.objectGrid,
      [
        for (final id in roomIds) [id, c.roomNames[id]],
      ],
      [
        for (final id in usedObjects)
          [id, c.objects[id]!.name, c.objects[id]!.isOccupiable],
      ],
      c.generalClues,
      [
        for (final person in characters)
          [
            person.id,
            person.name,
            person.clue,
            person.solution.row,
            person.solution.column,
          ],
      ],
      c.murderId,
    ]);
    // Two independent FNV-1a 32-bit accumulators yield a portable 16-digit
    // accidental-change marker without adding dependencies to pubspec.yaml.
    var a = 0x811c9dc5;
    var b = 0x6c62272e;
    for (final byte in utf8.encode(canonical)) {
      a = ((a ^ byte) * 0x01000193) & 0xffffffff;
      b = ((b ^ byte) * 0x01000193) & 0xffffffff;
    }
    return '${a.toRadixString(16).padLeft(8, '0')}${b.toRadixString(16).padLeft(8, '0')}';
  }
}
