import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuthService {
  final SupabaseClient _client = SupabaseService.instance.client;

  /// Stream of authentication state changes
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// Get the current session if it exists
  Session? get currentSession => _client.auth.currentSession;

  /// Get the current user if they exist
  User? get currentUser => _client.auth.currentUser;

  /// Sign out the current user
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Sign in with Email and Password
  Future<AuthResponse> signInWithEmailPassword(
      String email, String password) async {
    return await _client.auth
        .signInWithPassword(email: email, password: password);
  }

  // TODO: Implement other sign-in methods (e.g., GitHub OAuth, OTP) as needed.
}
