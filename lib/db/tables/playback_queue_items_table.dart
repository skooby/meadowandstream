import 'package:drift/drift.dart';
import 'playback_session_table.dart';
@DataClassName('PlaybackQueueItem')
class PlaybackQueueItems extends Table {
  @override
  String get tableName => 'playback_queue_items';
  IntColumn get sessionId => integer().references(PlaybackSession, #id, onDelete: KeyAction.cascade)();
  IntColumn get sortIndex => integer()();
  TextColumn get itemId => text()();
  TextColumn get collectionId => text().nullable()();
  TextColumn get title => text().nullable()();

  @override
  Set<Column> get primaryKey => {sessionId, sortIndex};

}
