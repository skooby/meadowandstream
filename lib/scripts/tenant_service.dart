import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../tenant_active.dart';

class TenantService {
  static const String _tenantIdKey = 'stored_tenant_id';
  static int? currentTenantId;

  /// Load the tenant ID from SharedPreferences on app start.
  /// If missing, look it up automatically using the active tenant string.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    currentTenantId = prefs.getInt(_tenantIdKey);

    if (currentTenantId == null) {
      final fetchedId =
          await lookupTenantByString(TenantActive.currentTenantSlug);
      if (fetchedId != null) {
        await prefs.setInt(_tenantIdKey, fetchedId);
        currentTenantId = fetchedId;
      } else {
        debugPrint(
            'CRITICAL: Could not resolve tenant ID for: ${TenantActive.currentTenantSlug}');
      }
    }
  }

  /// Check if a tenant is currently configured.
  static bool hasTenant() {
    return currentTenantId != null;
  }

  /// Fetch the tenant ID from Supabase using a string lookup (e.g., a slug or code).
  static Future<int?> lookupTenantByString(String appCode) async {
    try {
      final response = await Supabase.instance.client
          .from('tenants')
          .select('id')
          .eq('slug', appCode) // Assumes a 'slug' column. Change if necessary.
          .maybeSingle()
          .timeout(const Duration(milliseconds: 1500));

      if (response != null && response['id'] != null) {
        return int.tryParse(response['id'].toString());
      }
    } catch (e) {
      debugPrint('Tenant lookup failed: $e');
    }
    return null;
  }

  /// Save the tenant ID after a successful lookup.
  static Future<void> setTenantId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_tenantIdKey, id);
    currentTenantId = id;
  }

  /// Clear the tenant ID (e.g., for logging out or switching apps).
  static Future<void> clearTenant() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tenantIdKey);
    currentTenantId = null;
  }
}
