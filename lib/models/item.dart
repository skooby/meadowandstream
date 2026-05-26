class Item {
  final String id;
  final String title;
  final String? artist;
  final int? assetFolderId;
  final int? durationMs;
  final String? collectionTitle;
  final String? collectionId;

  final String audioUrl;
  final String? artworkUrl;

  Item({
    required this.id,
    required this.title,
    required this.audioUrl,
    this.artist,
    this.assetFolderId,
    this.durationMs,
    this.collectionTitle,
    this.collectionId,
    this.artworkUrl,
  });

  Item copyWith({
    String? id,
    String? title,
    String? artist,
    int? assetFolderId,
    int? durationMs,
    String? collectionTitle,
    String? collectionId,
    String? audioUrl,
    String? artworkUrl,
  }) {
    return Item(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      assetFolderId: assetFolderId ?? this.assetFolderId,
      durationMs: durationMs ?? this.durationMs,
      collectionTitle: collectionTitle ?? this.collectionTitle,
      collectionId: collectionId ?? this.collectionId,
      audioUrl: audioUrl ?? this.audioUrl,
      artworkUrl: artworkUrl ?? this.artworkUrl,
    );
  }

  @override
  String toString() {
    return 'Item(id: $id, title: $title, artist: $artist, assetFolderId: $assetFolderId, durationMs: $durationMs, collectionTitle: $collectionTitle, collectionId: $collectionId, audioUrl: $audioUrl, artworkUrl: $artworkUrl)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Item &&
        other.id == id &&
        other.title == title &&
        other.artist == artist &&
        other.assetFolderId == assetFolderId &&
        other.durationMs == durationMs &&
        other.collectionTitle == collectionTitle &&
        other.collectionId == collectionId &&
        other.audioUrl == audioUrl &&
        other.artworkUrl == artworkUrl;
  }

  @override
  int get hashCode {
    return Object.hash(id, title, artist, assetFolderId, durationMs, collectionTitle, collectionId, audioUrl, artworkUrl);
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: (map['id'] ?? map['item_id'])?.toString() ?? '',
      title: map['item_title']?.toString() ?? 'Unknown Title',
      artist: (map['artist'] ?? map['artist_name'] ?? map['collection_artist'])?.toString(),
      assetFolderId: map['asset_folder_id'] as int?,
      durationMs: map['duration_seconds'] != null
          ? (int.tryParse(map['duration_seconds'].toString()) ?? 0) * 1000
          : null,
      collectionTitle: map['collection_title']?.toString(),
      audioUrl: '',
    );
  }

  bool get isValid => id.isNotEmpty && assetFolderId != null;
}

class LocalCollection {
  final String id;
  final String title;
  final String? artist;
  final String? artworkUrl;

  LocalCollection({
    required this.id,
    required this.title,
    this.artist,
    this.artworkUrl,
  });

  LocalCollection copyWith({
    String? id,
    String? title,
    String? artist,
    String? artworkUrl,
  }) {
    return LocalCollection(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      artworkUrl: artworkUrl ?? this.artworkUrl,
    );
  }

  @override
  String toString() {
    return 'LocalCollection(id: $id, title: $title, artist: $artist, artworkUrl: $artworkUrl)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocalCollection &&
        other.id == id &&
        other.title == title &&
        other.artist == artist &&
        other.artworkUrl == artworkUrl;
  }

  @override
  int get hashCode {
    return Object.hash(id, title, artist, artworkUrl);
  }
}
