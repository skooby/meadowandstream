import 'package:drift/drift.dart';

@DataClassName('FavoriteCollection')
class FavoritesCollections extends Table {
  TextColumn get collectionId => text()();
  DateTimeColumn get favoritedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {collectionId};
}
