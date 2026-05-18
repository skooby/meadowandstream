
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
}
