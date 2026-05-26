class SystemTag {
  final String id;
  final String slug;
  final int? nameStringId;
  final String? description;
  final String colorHex;
  final int? parentId;
  final String type;
  final int? mappedStringFolderId;
  final int? sortOrder;

  const SystemTag({
    required this.id,
    required this.slug,
    this.nameStringId,
    this.description,
    this.colorHex = '#FFFFFF',
    this.parentId,
    this.type = 'TAG',
    this.mappedStringFolderId,
    this.sortOrder,
  });

  SystemTag copyWith({
    String? id,
    String? slug,
    int? nameStringId,
    String? description,
    String? colorHex,
    int? parentId,
    String? type,
    int? mappedStringFolderId,
    int? sortOrder,
  }) {
    return SystemTag(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      nameStringId: nameStringId ?? this.nameStringId,
      description: description ?? this.description,
      colorHex: colorHex ?? this.colorHex,
      parentId: parentId ?? this.parentId,
      type: type ?? this.type,
      mappedStringFolderId: mappedStringFolderId ?? this.mappedStringFolderId,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  String toString() {
    return 'SystemTag(id: $id, slug: $slug, nameStringId: $nameStringId, description: $description, colorHex: $colorHex, parentId: $parentId, type: $type, mappedStringFolderId: $mappedStringFolderId, sortOrder: $sortOrder)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SystemTag &&
        other.id == id &&
        other.slug == slug &&
        other.nameStringId == nameStringId &&
        other.description == description &&
        other.colorHex == colorHex &&
        other.parentId == parentId &&
        other.type == type &&
        other.mappedStringFolderId == mappedStringFolderId &&
        other.sortOrder == sortOrder;
  }

  @override
  int get hashCode {
    return Object.hash(id, slug, nameStringId, description, colorHex, parentId, type, mappedStringFolderId, sortOrder);
  }
}
