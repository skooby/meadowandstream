enum SourceType { asset, url, file }

class ItemSource {
  final String id;
  final String title;
  final String? artist;
  final SourceType sourceType;
  final String source;
  final String? artworkAsset;

  const ItemSource({
    required this.id,
    required this.title,
    this.artist,
    required this.sourceType,
    required this.source,
    this.artworkAsset,
  });
}
