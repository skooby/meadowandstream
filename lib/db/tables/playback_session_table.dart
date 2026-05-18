import 'package:drift/drift.dart';

@DataClassName('PlaybackSessionData')
class PlaybackSession extends Table {
  @override
  String get tableName => 'playback_session';
  IntColumn get id => integer()(); // Always 1
  IntColumn get currentIndex => integer().withDefault(const Constant(0))();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  IntColumn get isShuffled => integer().withDefault(const Constant(0))();
  IntColumn get repeatMode => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
