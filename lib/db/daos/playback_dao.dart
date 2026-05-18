import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/playback_session_table.dart';
import '../tables/playback_queue_items_table.dart';

part 'playback_dao.g.dart';

class PlaybackStateData {
  final PlaybackSessionData session;
  final List<PlaybackQueueItem> queue;

  PlaybackStateData(this.session, this.queue);
}

@DriftAccessor(tables: [PlaybackSession, PlaybackQueueItems])
class PlaybackDao extends DatabaseAccessor<AppDatabase>
    with _$PlaybackDaoMixin {
  PlaybackDao(AppDatabase db) : super(db);

  Future<void> saveQueue(List<String> itemIds,
      {int currentIndex = 0, int positionMs = 0}) async {
    await transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // 1. Upsert singleton session
      await into(playbackSession).insertOnConflictUpdate(
        PlaybackSessionData(
          id: 1,
          currentIndex: currentIndex,
          positionMs: positionMs,
          isShuffled: 0,
          repeatMode: 0,
          updatedAt: now,
        ),
      );

      // 2. Clear old queue
      await (delete(playbackQueueItems)..where((q) => q.sessionId.equals(1)))
          .go();

      // 3. Insert new queue
      final queueInsertions = <PlaybackQueueItemsCompanion>[];
      for (int i = 0; i < itemIds.length; i++) {
        queueInsertions.add(PlaybackQueueItemsCompanion.insert(
          sessionId: 1,
          sortIndex: i,
          itemId: itemIds[i],
        ));
      }
      await batch((batch) {
        batch.insertAll(playbackQueueItems, queueInsertions);
      });
    });
  }

  Stream<PlaybackSessionData?> watchSession() {
    return (select(playbackSession)..where((s) => s.id.equals(1)))
        .watchSingleOrNull();
  }

  Future<PlaybackStateData?> loadState() async {
    final session = await (select(playbackSession)
          ..where((s) => s.id.equals(1)))
        .getSingleOrNull();
    if (session == null) return null;

    final queue = await (select(playbackQueueItems)
          ..where((q) => q.sessionId.equals(1))
          ..orderBy([(q) => OrderingTerm(expression: q.sortIndex)]))
        .get();

    return PlaybackStateData(session, queue);
  }

  Future<void> updatePosition(int ms) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(playbackSession)..where((s) => s.id.equals(1))).write(
      PlaybackSessionCompanion(
        positionMs: Value(ms),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> updateIndex(int index) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(playbackSession)..where((s) => s.id.equals(1))).write(
      PlaybackSessionCompanion(
        currentIndex: Value(index),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> updateShuffleMode(int isShuffled) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(playbackSession)..where((s) => s.id.equals(1))).write(
      PlaybackSessionCompanion(
        isShuffled: Value(isShuffled),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> updateRepeatMode(int mode) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(playbackSession)..where((s) => s.id.equals(1))).write(
      PlaybackSessionCompanion(
        repeatMode: Value(mode),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> updateQueueOrder(List<String> itemIds) async {
    await transaction(() async {
      await (delete(playbackQueueItems)..where((q) => q.sessionId.equals(1)))
          .go();

      final queueInsertions = <PlaybackQueueItemsCompanion>[];
      for (int i = 0; i < itemIds.length; i++) {
        queueInsertions.add(PlaybackQueueItemsCompanion.insert(
          sessionId: 1,
          sortIndex: i,
          itemId: itemIds[i],
        ));
      }
      await batch((batch) {
        batch.insertAll(playbackQueueItems, queueInsertions);
      });
    });
  }

  Future<void> clear() async {
    await transaction(() async {
      await (delete(playbackQueueItems)..where((q) => q.sessionId.equals(1)))
          .go();
      await (delete(playbackSession)..where((t) => t.id.equals(1))).go();
    });
  }
}
