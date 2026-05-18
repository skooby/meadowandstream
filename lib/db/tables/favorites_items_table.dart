import 'package:drift/drift.dart';

@DataClassName('FavoriteItem')
class FavoritesItems extends Table {
  TextColumn get itemId => text()();
  DateTimeColumn get favoritedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {itemId};
}
