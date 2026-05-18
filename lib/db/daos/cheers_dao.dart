import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/cheers_table.dart';
import 'package:uuid/uuid.dart';
import '../../services/offline_sync_service.dart';

part 'cheers_dao.g.dart';

@DriftAccessor(tables: [Cheers])
class CheersDao extends DatabaseAccessor<AppDatabase> with _$CheersDaoMixin {
  CheersDao(super.db);

  Future<void> insertCheer(String userId, String targetId, int amount) async {
    final uuid = const Uuid().v4();
    await into(cheers).insert(
      CheersCompanion.insert(
        id: uuid,
        userId: userId,
        targetId: targetId,
        amount: amount,
      ),
      mode: InsertMode.replace,
    );
    
    // Wire up offline sync to RPC endpoint
    try {
       await OfflineSyncService.instance.queueMutation(
          targetTable: 'add_cheer',
          operation: 'RPC',
          payload: { 'p_target_id': targetId, 'p_amount': amount }
       );
    } catch (_) {}
  }

  Future<List<Cheer>> getCheersForTarget(String targetId) {
    return (select(cheers)..where((c) => c.targetId.equals(targetId))).get();
  }

  Future<void> clearCheers() {
    return delete(cheers).go();
  }
}
