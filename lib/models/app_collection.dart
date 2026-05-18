enum AppCollectionType {
  music,
  information,
  inspiration,
  uiElement,
  other
}

class AppCollection {
  final String id;
  final String title;
  final AppCollectionType type;
  final String? description;

  const AppCollection({
    required this.id,
    required this.title,
    required this.type,
    this.description,
  });
}
