class Collection {
  final int id;
  final int tenantId;
  final String slug;
  final String? artistName;
  final DateTime? releaseDate;
  final String? artworkUrl;
  final String status;
  final int sortOrder;
  final int titleStringId;

  Collection({
    required this.id,
    required this.tenantId,
    required this.slug,
    this.artistName,
    this.releaseDate,
    this.artworkUrl,
    required this.status,
    required this.sortOrder,
    required this.titleStringId,
  });

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'] as int,
      tenantId: json['tenant_id'] as int,
      slug: json['slug'] as String,
      artistName: json['artist_name'] as String?,
      releaseDate: json['release_date'] != null
          ? DateTime.parse(json['release_date'].toString())
          : null,
      artworkUrl: json['artwork_url'] as String?,
      status: json['status'] as String? ?? 'draft',
      sortOrder: json['sort_order'] as int? ?? 0,
      titleStringId: json['title_string_id'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'slug': slug,
      'artist_name': artistName,
      'release_date': releaseDate?.toIso8601String(),
      'artwork_url': artworkUrl,
      'status': status,
      'sort_order': sortOrder,
      'title_string_id': titleStringId,
    };
  }
}
