import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/sync_queue_table.dart';

part 'sync_queue_dao.g.dart';

@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase> with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  Stream<List<SyncQueueData>> watchAllQueueItems() => select(syncQueue).watch();
  
  Future<List<SyncQueueData>> getAllQueueItems() => select(syncQueue).get();

  Future<int> enqueueMutation(String targetTable, String operation, String payloadJson) {
    return into(syncQueue).insert(
      SyncQueueCompanion(
        targetTable: Value(targetTable),
        operation: Value(operation),
        payloadJson: Value(payloadJson),
      )
    );
  }

  Future<void> removeQueueItem(int id) {
    return (delete(syncQueue)..where((tbl) => tbl.id.equals(id))).go();
  }
}
