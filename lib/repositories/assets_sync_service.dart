import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../db/daos/assets_dao.dart';
import '../db/app_database.dart';
import '../scripts/tenant_service.dart';

class AssetsSyncService extends ChangeNotifier {
  final AssetsDao _dao;
  final SupabaseClient _supabase;
  Timer? _pollingTimer;

  AssetsSyncService(this._dao) : _supabase = Supabase.instance.client;

  int get _tenantId => TenantService.currentTenantId ?? 0;

  Future<void> sync() async {
    try {
      final response = await _supabase
          .from('assets')
          .select()
          .eq('tenant_id', _tenantId);

      final List<Asset> fetchedAssets = response.map((json) {
        return Asset(
          id: json['id'] as int,
          tenantId: json['tenant_id'] as int,
          parentId: json['parent_id'] as int?,
          type: json['type'] as String,
          mimeType: json['mime_type'] as String?,
          name: json['name'] as String,
          storagePath: json['storage_path'] as String?,
          sizeBytes: json['size_bytes'] as int?,
          mappedStringFolderId: json['mapped_string_folder_id'] as int?,
          description: json['description'] as String?,
          createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()).millisecondsSinceEpoch : null,
          updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'].toString()).millisecondsSinceEpoch : null,
          sortOrder: json['sort_order'] as int?,
          titleStringId: json['title_string_id'] as int?,
          collectionType: json['collection_type'] as String?,
          searchKeywords: json['search_keywords'] as String?
        );
      }).toList();

      await _dao.replaceAllAssets(fetchedAssets);
      notifyListeners();
    } catch (e) {
      debugPrint('AssetsSyncService sync error: $e');
    }
  }

  void startPolling({Duration interval = const Duration(minutes: 5)}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) => sync());
    sync();
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }
}
