

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
}
