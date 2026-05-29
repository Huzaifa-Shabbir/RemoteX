import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Supabase auth helper.
class SupabaseService {
  static SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // ── Auth ──────────────────────────────────────────────────

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
    String? username,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not initialized.');
    }

    return await client.auth.signUp(
      email: email,
      password: password,
      data: {
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
        if (username  != null && username.isNotEmpty)  'username':  username,
      },
    );
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not initialized.');
    }

    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    final client = _client;
    if (client == null) return;
    await client.auth.signOut();
  }

  // ── Current user helpers ──────────────────────────────────

  static User? get currentUser => _client?.auth.currentUser;
  static String get displayName {
    final user = currentUser;
    if (user == null) return 'User';
    final meta = user.userMetadata ?? {};

    final fullName = meta['full_name']?.toString().trim() ?? '';
    if (fullName.isNotEmpty) return fullName;

    final username = meta['username']?.toString().trim() ?? '';
    if (username.isNotEmpty) return username;

    final email = user.email ?? '';
    if (email.isNotEmpty) return email.split('@').first;

    return 'User';
  }

  /// Returns the signed-in user's email, or empty string if not signed in.
  static String get displayEmail => currentUser?.email ?? '';

  static Stream<AuthState> get authStateChanges =>
      _client?.auth.onAuthStateChange ?? const Stream<AuthState>.empty();
}