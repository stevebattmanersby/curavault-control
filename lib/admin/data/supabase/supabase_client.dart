import 'package:curavault_admin/admin/auth/admin_auth_store.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Central access point for the Supabase client used by the Control Site.
///
/// Security properties:
/// - Uses only `SUPABASE_URL` + `SUPABASE_ANON_KEY` (no service role key).
/// - Returns `null` if Supabase isn't initialized or configuration is missing.
class ControlSupabaseClient {
  static SupabaseClient? tryGet() {
    if (AdminAuthStore.supabaseUrl.isEmpty || AdminAuthStore.supabaseAnonKey.isEmpty) return null;

    // Fail closed if a service role key was accidentally bundled.
    if (AdminAuthStore.supabaseServiceRoleKey.isNotEmpty) {
      debugPrint('SECURITY: SUPABASE_SERVICE_ROLE_KEY detected; refusing Supabase client access.');
      return null;
    }

    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}
