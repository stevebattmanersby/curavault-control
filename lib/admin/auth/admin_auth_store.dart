import 'dart:async';

import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/utils/audit_redactor.dart';
import 'package:curavault_admin/admin/utils/client_context.dart';
import 'package:curavault_admin/supabase/supabase_config.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAccessDeniedException implements Exception {
  final String message;
  const AdminAccessDeniedException(this.message);
  @override
  String toString() => 'AdminAccessDeniedException: $message';
}

class AdminAuthNetworkException implements Exception {
  final String message;
  const AdminAuthNetworkException(this.message);
  @override
  String toString() => 'AdminAuthNetworkException: $message';
}

class AdminAuthInvalidCredentialsException implements Exception {
  final String message;
  const AdminAuthInvalidCredentialsException(this.message);
  @override
  String toString() => 'AdminAuthInvalidCredentialsException: $message';
}

class AdminAuthAllowListLookupException implements Exception {
  final String message;
  const AdminAuthAllowListLookupException(this.message);
  @override
  String toString() => 'AdminAuthAllowListLookupException: $message';
}

/// Auth + admin access gate for the CuraVault Control Site.
///
/// Rules enforced:
/// - Must be signed into Supabase Auth (anon key only; no service role)
  /// - Must have a matching row in `public.admin_users` (or `control.admin_users`)
  /// - Must be `is_active = true`
/// - Role must be known (otherwise deny)
class AdminAuthStore extends ChangeNotifier {
  static const supabaseServiceRoleKey = String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY', defaultValue: '');

  /// IMPORTANT (Flutter Web + hash routing): `redirectTo` must be an absolute URL
  /// that includes the SPA hash fragment (/#/...). Do NOT join path segments.
  ///
  /// Keep this as a single hard-coded constant to avoid accidental URL joining
  /// that can produce malformed URLs like `...///set-password`.
  static const String passwordResetRedirectTo =
      'https://xh23x34884agk2qv1p4a.share.dreamflow.app/#/set-password';

  static bool _initialized = false;

  /// Temporary debug output to verify Supabase bootstrap behavior in Dreamflow.
  ///
  /// Prints only true/false flags—never secret values.
  static void debugPrintSupabaseBootstrapStatus({String source = 'AdminAuthStore'}) {
    if (!kDebugMode) return;

    final hasUrlDefine = SupabaseConfig.supabaseUrl.isNotEmpty;
    final hasAnonDefine = SupabaseConfig.anonKey.isNotEmpty;
    final serviceRoleDetected = SupabaseConfig.serviceRoleDetected || supabaseServiceRoleKey.isNotEmpty;

    bool instanceClientAvailable;
    try {
      Supabase.instance.client;
      instanceClientAvailable = true;
    } catch (_) {
      instanceClientAvailable = false;
    }

    debugPrint(
      '[$source] Supabase bootstrap status: '
      'clientAvailable=$instanceClientAvailable '
      'adminAuthStoreInitialized=$_initialized '
      'hasSUPABASE_URL=$hasUrlDefine '
      'hasSUPABASE_ANON_KEY=$hasAnonDefine '
      'serviceRoleDetected=$serviceRoleDetected',
    );
  }

  static SupabaseClient? _tryGetExistingSupabaseClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static Future<void> initializeSupabase() async {
    if (_initialized) return;

    debugPrintSupabaseBootstrapStatus(source: 'AdminAuthStore.initializeSupabase(before)');

    // Fail closed if a service role key was accidentally bundled into the frontend.
    // (This should never be set in a client build.)
    if (supabaseServiceRoleKey.isNotEmpty || SupabaseConfig.serviceRoleDetected) {
      debugPrint('SECURITY: SUPABASE_SERVICE_ROLE_KEY detected in client build. Refusing to initialize Supabase.');
      return;
    }

    try {
      // Prefer a single initialization path (SupabaseConfig provides fallbacks + optional overrides).
      await SupabaseConfig.initialize();
      _initialized = SupabaseConfig.isInitialized || _tryGetExistingSupabaseClient() != null;
      debugPrintSupabaseBootstrapStatus(source: 'AdminAuthStore.initializeSupabase(afterSupabaseConfigInit)');
    } catch (e) {
      debugPrint('Supabase.initialize failed: $e');
    }
  }

  SupabaseClient? get _client {
    if (!_initialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  StreamSubscription<AuthState>? _authSub;

  bool _isBootstrapping = true;
  bool get isBootstrapping => _isBootstrapping;

  bool _isSigningIn = false;
  bool get isSigningIn => _isSigningIn;

  String? _fatalConfigError;
  String? get fatalConfigError => _fatalConfigError;

  Session? _session;
  Session? get session => _session;

  String? _adminEmail;
  String? get adminEmail => _adminEmail;

  String? _adminDisplayName;
  String? get adminDisplayName => _adminDisplayName;

  String? _adminStatus;
  String? get adminStatus => _adminStatus;

  bool? _isActive;
  bool? get isActive => _isActive;

  bool? _requireStepUp;
  bool? get requireStepUp => _requireStepUp;

  AdminRole? _role;
  AdminRole? get role => _role;

  String? _accessDeniedReason;
  String? get accessDeniedReason => _accessDeniedReason;

  bool get isSignedIn => _session != null;

  bool get isAuthorized =>
      isSignedIn &&
      (_isActive == true) &&
      _role != null;

  Future<void> bootstrap() async {
    debugPrintSupabaseBootstrapStatus(source: 'AdminAuthStore.bootstrap(start)');
    // Ensure initialize was called (main() should do this first, but keep defensive init).
    await initializeSupabase();

    // Explicit security fail-closed if a service role key is present.
    if (supabaseServiceRoleKey.isNotEmpty || SupabaseConfig.serviceRoleDetected) {
      _fatalConfigError =
          'Security error: SUPABASE_SERVICE_ROLE_KEY detected in a client build.\n\n'
          'Remove it from your build configuration and rebuild.';
      debugPrintSupabaseBootstrapStatus(source: 'AdminAuthStore.bootstrap(serviceRoleDetected)');
      _isBootstrapping = false;
      notifyListeners();
      return;
    }

    // If we still cannot access a client, THEN fail closed with a clear error.
    if (_tryGetExistingSupabaseClient() == null) {
      _fatalConfigError =
          'Supabase failed to initialize in this build.\n\n'
          'This preview build includes safe fallback values. If you are overriding config in production, compile with:\n'
          '- --dart-define=SUPABASE_URL=...\n'
          '- --dart-define=SUPABASE_ANON_KEY=...\n\n'
          'Do not use the service role key in frontend code.';
      debugPrintSupabaseBootstrapStatus(source: 'AdminAuthStore.bootstrap(fatalConfigError)');
      _isBootstrapping = false;
      notifyListeners();
      return;
    }

    debugPrintSupabaseBootstrapStatus(source: 'AdminAuthStore.bootstrap(afterInitializeSupabase)');

    _session = _client?.auth.currentSession;

    _authSub?.cancel();
    _authSub = _client?.auth.onAuthStateChange.listen((event) {
      _session = event.session;
      // When auth changes, refresh admin record.
      unawaited(_refreshAdminProfile());
      notifyListeners();
    });

    await _refreshAdminProfile();
    _isBootstrapping = false;
    notifyListeners();
  }

  Future<void> signInWithPassword({required String email, required String password}) async {
    if (_client == null) return;
    if (_isSigningIn) return;
    _isSigningIn = true;
    _accessDeniedReason = null;
    notifyListeners();
    try {
      final res = await _client!.auth.signInWithPassword(email: email.trim(), password: password);
      _session = res.session;
      try {
        await _refreshAdminProfile();
      } catch (e) {
        // Auth succeeded, but allow-list lookup failed (network/RLS/table missing).
        try {
          await _client!.auth.signOut();
        } catch (_) {}
        _session = null;
        throw AdminAuthAllowListLookupException(e.toString());
      }

      // If Supabase auth succeeded but allow-list/role checks failed, treat it as
      // a login denial and immediately sign out.
      if (!isAuthorized) {
        final reason = _accessDeniedReason ?? 'Not allow-listed.';
        try {
          await _client!.auth.signOut();
        } catch (_) {}
        _session = null;
        throw AdminAccessDeniedException(reason);
      }

      final actor = _client!.auth.currentUser?.id;
      if (actor != null && actor.isNotEmpty) {
        // Audit log is mandatory; if we cannot write it, deny access.
        await _writeAudit(
          adminUserId: actor,
          actionType: 'admin_login',
          result: 'success',
          newValue: AdminAuditRedactor.redactMap({'email': email.trim()}),
          failClosed: true,
        );
      }
    } catch (e) {
      debugPrint('AdminAuthStore.signInWithPassword failed: $e');

      // TEMPORARY: Do not write audit rows for failed sign-ins.
      // This avoids masking root-cause connectivity failures with a secondary
      // PostgREST/audit error.

      // Normalize error types for the UI.
      if (e is AuthException) {
        final msg = e.message;
        if (msg.toLowerCase().contains('invalid login credentials')) {
          throw const AdminAuthInvalidCredentialsException('Invalid login credentials');
        }
      }

      final s = e.toString().toLowerCase();
      if (e is AuthRetryableFetchException || s.contains('failed to fetch') || s.contains('clientexception: failed to fetch')) {
        throw AdminAuthNetworkException(e.toString());
      }
      rethrow;
    } finally {
      _isSigningIn = false;
      notifyListeners();
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    final c = _client;
    if (c == null) {
      debugPrint('AdminAuthStore.sendPasswordResetEmail: Supabase client not available.');
      return;
    }
    try {
      // CRITICAL: Do not construct/normalize this with Uri helpers.
      const redirectTo = AdminAuthStore.passwordResetRedirectTo;
      if (kDebugMode) {
        debugPrint('AdminAuthStore.sendPasswordResetEmail: using redirectTo=$redirectTo');
      }
      await c.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: redirectTo,
      );
    } catch (e) {
      debugPrint('AdminAuthStore.sendPasswordResetEmail failed: $e');
      rethrow;
    }
  }

  Future<void> updatePassword({required String newPassword}) async {
    final c = _client;
    if (c == null) {
      debugPrint('AdminAuthStore.updatePassword: Supabase client not available.');
      return;
    }
    try {
      await c.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      debugPrint('AdminAuthStore.updatePassword failed: $e');
      rethrow;
    }
  }

  Future<void> _writeAudit({
    required String adminUserId,
    String? targetUserId,
    required String actionType,
    Map<String, dynamic>? previousValue,
    Map<String, dynamic>? newValue,
    String? reason,
    String? ticketReference,
    String? result,
    bool failClosed = false,
  }) async {
    final c = _client;
    if (c == null) {
      if (failClosed) throw StateError('Supabase client not initialized; cannot write audit log.');
      return;
    }
    try {
      final row = {
        'admin_user_id': adminUserId,
        if (targetUserId != null) 'target_user_id': targetUserId,
        'action_type': actionType,
        if (previousValue != null) 'previous_value': AdminAuditRedactor.redactMap(previousValue),
        if (newValue != null) 'new_value': AdminAuditRedactor.redactMap(newValue),
        if (reason != null) 'reason': reason,
        if (ticketReference != null) 'ticket_reference': ticketReference,
        if (AdminClientContext.ipAddress != null) 'ip_address': AdminClientContext.ipAddress,
        if (AdminClientContext.userAgent != null) 'user_agent': AdminClientContext.userAgent,
        'result': result ?? 'success',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      try {
        await c.schema('control').from('admin_audit_log').insert(row);
      } catch (_) {
        await c.from('admin_audit_log').insert(row);
      }
    } catch (e) {
      debugPrint('AdminAuthStore._writeAudit failed: $e');
      if (failClosed) {
        // Fail-closed: if audit logging fails, deny access.
        try {
          await c.auth.signOut();
        } catch (_) {}
        _session = null;
        _adminEmail = null;
        _adminStatus = null;
        _role = null;
        _accessDeniedReason = 'Security control: audit logging unavailable.';
        notifyListeners();
        throw StateError('Audit log write failed (fail-closed).');
      }
    }
  }

  Future<void> signOut() async {
    try {
      await _client?.auth.signOut();
    } catch (e) {
      debugPrint('AdminAuthStore.signOut failed: $e');
    } finally {
      _session = null;
      _adminEmail = null;
      _adminDisplayName = null;
      _adminStatus = null;
      _isActive = null;
      _requireStepUp = null;
      _role = null;
      _accessDeniedReason = null;
      notifyListeners();
    }
  }

  Future<void> _refreshAdminProfile() async {
    _accessDeniedReason = null;

    final authUser = _client?.auth.currentUser;
    if (authUser == null) {
      _adminEmail = null;
      _adminDisplayName = null;
      _adminStatus = null;
      _isActive = null;
      _requireStepUp = null;
      _role = null;
      return;
    }

    try {
      // Your bootstrapped schema uses `public.admin_users.admin_user_id` as the
      // Supabase Auth user id column.
      final row = await _client!
          .from('admin_users')
          // IMPORTANT:
          // - Column is named `role` (type `admin_role`).
          // - Auth user id column is `admin_user_id`.
          .select('email, display_name, role, is_active, require_step_up')
          .eq('admin_user_id', authUser.id)
          .maybeSingle();

      if (row == null) {
        _adminEmail = authUser.email;
        _adminDisplayName = null;
        _adminStatus = 'missing';
        _isActive = false;
        _requireStepUp = null;
        _role = null;
        _accessDeniedReason = 'Authenticated but not allow-listed.';
        return;
      }

      _adminEmail = (row['email'] as String?) ?? authUser.email;
      _adminDisplayName = (row['display_name'] as String?)?.trim().isEmpty == true ? null : (row['display_name'] as String?);
      final isActive = row['is_active'] == true;
      _isActive = isActive;
      _adminStatus = isActive ? 'active' : 'inactive';
      _requireStepUp = row['require_step_up'] == true;
      _role = parseAdminRole(row['role'] as String?);

      if (!isActive) {
        _accessDeniedReason = 'Admin user inactive.';
      } else if (_role == null) {
        _accessDeniedReason = 'Unknown admin role. Access denied.';
      }
    } catch (e) {
      debugPrint('AdminAuthStore._refreshAdminProfile failed: $e');
      _adminEmail = authUser.email;
      _adminDisplayName = null;
      _adminStatus = 'error';
      _isActive = false;
      _requireStepUp = null;
      _role = null;
      _accessDeniedReason = 'Failed to validate admin access. Try again later.';
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
