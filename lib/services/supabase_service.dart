import 'package:supabase_flutter/supabase_flutter.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Supabase Configuration
/// ─────────────────────────────────────────────────────────────────────────────
/// TODO: Replace the two placeholder strings below with your actual project
/// credentials from: Supabase Dashboard → Settings → API
///
///   supabaseUrl   → "Project URL"   e.g. https://xyzabc.supabase.co
///   supabaseAnonKey → "anon public" key (safe to ship in the app)
/// ─────────────────────────────────────────────────────────────────────────────
class SupabaseConfig {
  static const String supabaseUrl = 'https://qjyxdapbuszjtguyrtdk.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFqeXhkYXBidXN6anRndXlydGRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU2NTk2ODYsImV4cCI6MjA5MTIzNTY4Nn0.Xaeg6JEgKKZnawQQ9SJMJ4wPKuhykbpeitCsqdrWDmw';
}

/// Thin wrapper around the Supabase singleton so the rest of the app
/// never imports supabase_flutter directly (makes it easy to swap later).
class SupabaseService {
  /// The underlying Supabase client (use sparingly outside this service).
  static SupabaseClient get client => Supabase.instance.client;

  /// Initialise once in main() before runApp().
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  }

  // ── Auth helpers ─────────────────────────────────────────────────────────
  static User? get currentUser => client.auth.currentUser;
  static Session? get currentSession => client.auth.currentSession;
  static bool get isSignedIn => currentUser != null;
  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // ── Profile helpers ──────────────────────────────────────────────────────
  /// Fetch the current user's profile row (returns null if not found).
  static Future<Map<String, dynamic>?> fetchProfile() async {
    final user = currentUser;
    if (user == null) return null;
    try {
      final data = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      return data as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// Update (merge) the current user's profile.
  static Future<void> updateProfile(Map<String, dynamic> updates) async {
    final user = currentUser;
    if (user == null) return;
    await client
        .from('profiles')
        .upsert({'id': user.id, ...updates, 'updated_at': DateTime.now().toIso8601String()});
  }

  // ── Daily usage helpers ──────────────────────────────────────────────────
  /// Returns today's {scan_count, chat_count} for the current user, or zeros.
  static Future<({int scans, int chats})> fetchTodayUsage() async {
    final user = currentUser;
    if (user == null) return (scans: 0, chats: 0);
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final data = await client
          .from('usage')
          .select('scan_count, chat_count')
          .eq('user_id', user.id)
          .eq('date', today)
          .maybeSingle();
      if (data == null) return (scans: 0, chats: 0);
      return (
        scans: (data['scan_count'] as int? ?? 0),
        chats: (data['chat_count'] as int? ?? 0),
      );
    } catch (_) {
      return (scans: 0, chats: 0);
    }
  }

  // ── Diary cloud sync ────────────────────────────────────────────────────
  /// Fetch today's diary entries from cloud for the current user.
  static Future<List<Map<String, dynamic>>> fetchTodayDiary() async {
    final user = currentUser;
    if (user == null) return [];
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final List<dynamic> data = await client
          .from('diary_entries')
          .select()
          .eq('user_id', user.id)
          .eq('date', today)
          .order('created_at');
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Insert a diary entry into the cloud.
  static Future<void> insertDiaryEntry({
    required String date,
    required String time,
    required String mealName,
    required int calories,
    required int proteinG,
    required int carbsG,
    required int fatG,
    required int fiberG,
  }) async {
    final user = currentUser;
    if (user == null) return;
    await client.from('diary_entries').insert({
      'user_id': user.id,
      'date': date,
      'time': time,
      'meal_name': mealName,
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'fiber_g': fiberG,
    });
  }

  /// Bulk-insert diary entries (used for local → cloud migration).
  static Future<void> bulkInsertDiaryEntries(
    List<Map<String, dynamic>> entries,
  ) async {
    final user = currentUser;
    if (user == null || entries.isEmpty) return;
    await client.from('diary_entries').upsert(
      entries.map((e) => {'user_id': user.id, ...e}).toList(),
    );
  }
}
