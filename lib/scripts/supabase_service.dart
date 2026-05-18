import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/item.dart';

/// A service to handle Supabase interactions.
class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  final _storage = const FlutterSecureStorage();

  static const _keyEmail = 'user_email';
  static const _keyPassword = 'user_password';

  /// Retrives the current session if it exists.
  Session? get currentSession => _client.auth.currentSession;

  /// Stream of auth state changes.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign in with email and password.
  Future<AuthResponse> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    // Save credentials if login is successful
    if (response.session != null) {
      await _storage.write(key: _keyEmail, value: email);
      await _storage.write(key: _keyPassword, value: password);
    }

    return response;
  }

  /// Get saved credentials from secure storage.
  Future<Map<String, String?>> getSavedCredentials() async {
    final email = await _storage.read(key: _keyEmail);
    final password = await _storage.read(key: _keyPassword);
    return {'email': email, 'password': password};
  }

  /// Clear saved credentials.
  Future<void> clearSavedCredentials() async {
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyPassword);
  }

  /// Sign in with Magic Link (OTP).
  Future<void> signInWithMagicLink(String email) async {
    await _client.auth.signInWithOtp(
      email: email,
      emailRedirectTo:
          'io.supabase.musicapp://login-callback', // Example redirect
    );
  }

  /// Sign in with GitHub.
  Future<void> signInWithGitHub() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.github,
      redirectTo: kIsWeb
          ? null
          : 'io.supabase.musicapp://login-callback', // Matches your scheme
    );
  }

  /// Sign out.
  Future<void> signOut() async {
    await _client.auth.signOut();
    await clearSavedCredentials();
  }

  /// Stream the first 10 rows from public.items in real-time.
  Stream<List<Item>> streamItems() {
    debugPrint(
        'SupabaseService: Starting real-time stream for items table...');

    return _client
        .from(
            'items') // Streaming base table instead of view for better real-time support
        .stream(primaryKey: ['id'])
        .limit(10)
        .order('id', ascending: true) // Ensure consistent ordering
        .map((maps) {
          debugPrint(
              'SupabaseService: Stream received update with ${maps.length} records.');
          return maps.map((map) => Item.fromMap(map)).toList();
        });
  }
}
