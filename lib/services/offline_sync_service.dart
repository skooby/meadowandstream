import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../db/app_database.dart';
import 'network_service.dart';
import 'supabase_service.dart';
import 'dart:async';
import 'profiler_service.dart';

class OfflineSyncService {
  static final OfflineSyncService instance = OfflineSyncService._internal();
  OfflineSyncService._internal();

  AppDatabase? _db;
  NetworkService? _network;
  StreamSubscription? _connectivitySub;

  void initialize(AppDatabase db, NetworkService network) {
    _db = db;
    _network = network;
    
    _connectivitySub = _network!.onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.wifi) || results.contains(ConnectivityResult.mobile) || results.contains(ConnectivityResult.ethernet)) {
        _processQueue();
      }
    }, onError: (Object error) {
      // Silently ignore Windows NetworkManager StartListen PlatformExceptions
    });
    
    // Initial check
    _processQueue();
  }

  Future<void> queueMutation({required String targetTable, required String operation, required Map<String, dynamic> payload}) async {
    if (_db == null) return;
    await _db!.syncQueueDao.enqueueMutation(targetTable, operation, jsonEncode(payload));
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_db == null) return;
    try {
      final hasConnection = (await _network!.checkConnectivity()).any((r) => r != ConnectivityResult.none);
      if (!hasConnection) return;

      final items = await _db!.syncQueueDao.getAllQueueItems();
      if (items.isEmpty) return;

      for (var item in items) {
        bool success = false;
        final sw = Stopwatch()..start();
        try {
          final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
          if (item.operation == 'INSERT') {
            await SupabaseService.instance.client.from(item.targetTable).insert(payload);
            success = true;
          } else if (item.operation == 'UPDATE') {
            final id = payload['id'];
            if (id != null) {
               await SupabaseService.instance.client.from(item.targetTable).update(payload).eq('id', id);
               success = true;
            }
          } else if (item.operation == 'RPC') {
             await SupabaseService.instance.client.rpc(item.targetTable, params: payload);
             success = true;
          } else if (item.operation == 'DELETE') {
            final id = payload['id'];
            if (id != null) {
               await SupabaseService.instance.client.from(item.targetTable).delete().eq('id', id);
               success = true;
            }
          }
        } catch (e) {
           print('OfflineSyncService Error processing item ${item.id}: $e');
        } finally {
           sw.stop();
           AppProfilerService.instance.recordSyncLatency(sw.elapsedMicroseconds / 1000.0);
        }

        if (success) {
          await _db!.syncQueueDao.removeQueueItem(item.id);
        }
      }
    } catch (e) {
      print('OfflineSyncService Error in queue processing: \$e');
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}
