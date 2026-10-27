class ObjectDefinition {
  const ObjectDefinition({
    required this.name,
    required this.isOccupiable,
    this.imageAsset,
  });

  final String name;
  final bool isOccupiable;
  final String? imageAsset;

  factory ObjectDefinition.fromJson(Map<String, dynamic> json) {
    return ObjectDefinition(
      name: json['name'] as String,
      isOccupiable: json['isOccupiable'] as bool,
      imageAsset: json['imageAsset'] as String?,
    );
  }
}
