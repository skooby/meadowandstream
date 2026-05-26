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

  Collection copyWith({
    int? id,
    int? tenantId,
    String? slug,
    String? artistName,
    DateTime? releaseDate,
    String? artworkUrl,
    String? status,
    int? sortOrder,
    int? titleStringId,
  }) {
    return Collection(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      slug: slug ?? this.slug,
      artistName: artistName ?? this.artistName,
      releaseDate: releaseDate ?? this.releaseDate,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      status: status ?? this.status,
      sortOrder: sortOrder ?? this.sortOrder,
      titleStringId: titleStringId ?? this.titleStringId,
    );
  }

  @override
  String toString() {
    return 'Collection(id: $id, tenantId: $tenantId, slug: $slug, artistName: $artistName, releaseDate: $releaseDate, artworkUrl: $artworkUrl, status: $status, sortOrder: $sortOrder, titleStringId: $titleStringId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Collection &&
        other.id == id &&
        other.tenantId == tenantId &&
        other.slug == slug &&
        other.artistName == artistName &&
        other.releaseDate == releaseDate &&
        other.artworkUrl == artworkUrl &&
        other.status == status &&
        other.sortOrder == sortOrder &&
        other.titleStringId == titleStringId;
  }

  @override
  int get hashCode {
    return Object.hash(id, tenantId, slug, artistName, releaseDate, artworkUrl, status, sortOrder, titleStringId);
  }

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
