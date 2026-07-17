class Tag {
  final int id;
  final String name;
  final int colorHex;

  const Tag({required this.id, required this.name, required this.colorHex});

  Tag copyWith({int? id, String? name, int? colorHex}) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tag &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          colorHex == other.colorHex;

  @override
  int get hashCode => Object.hash(id, name, colorHex);

  @override
  String toString() => 'Tag{id: $id, name: $name, colorHex: $colorHex}';
}
