import 'dart:async';

import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/utils/audit_redactor.dart';
import 'package:curavault_admin/admin/utils/client_context.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Auth + admin access gate for the CuraVault Control Site.
///
/// Rules enforced:
/// - Must be signed into Supabase Auth (anon key only; no service role)
/// - Must have a matching row in `control.admin_users` (or `admin_users`)
/// - Admin status must be `active`
/// - Role must be known (otherwise deny)
class AdminAuthStore extends ChangeNotifier {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const supabaseServiceRoleKey = String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY');

  static bool _initialized = false;

  static Future<void> initializeSupabase() async {
    if (_initialized) return;
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      debugPrint('Supabase not configured (missing SUPABASE_URL / SUPABASE_ANON_KEY).');
      return;
    }

    // Fail closed if a service role key was accidentally bundled into the frontend.
    // (This should never be set in a client build.)
    if (supabaseServiceRoleKey.isNotEmpty) {
      debugPrint('SECURITY: SUPABASE_SERVICE_ROLE_KEY detected in client build. Refusing to initialize Supabase.');
      return;
    }
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      _initialized = true;
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

  String? _adminStatus;
  String? get adminStatus => _adminStatus;

  AdminRole? _role;
  AdminRole? get role => _role;

  String? _accessDeniedReason;
  String? get accessDeniedReason => _accessDeniedReason;

  bool get isSignedIn => _session != null;

  bool get isAuthorized =>
      isSignedIn &&
      (_adminStatus ?? '').toLowerCase() == 'active' &&
      _role != null;

  Future<void> bootstrap() async {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      _fatalConfigError = 'Supabase environment not configured in this build.';
      _isBootstrapping = false;
      notifyListeners();
      return;
    }

    // Ensure initialize was called.
    await initializeSupabase();

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
      await _refreshAdminProfile();

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

      // Best-effort to audit failed login too. If audit logging is misconfigured,
      // we still surface the original auth failure.
      await _writeAudit(
        adminUserId: _client?.auth.currentUser?.id ?? 'unknown',
        actionType: 'failed_admin_login',
        result: 'failure',
        newValue: AdminAuditRedactor.redactMap({'email': email.trim(), 'error': e.toString()}),
      );
      rethrow;
    } finally {
      _isSigningIn = false;
      notifyListeners();
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
      _adminStatus = null;
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
      _adminStatus = null;
      _role = null;
      return;
    }

    try {
      // Prefer schema-qualified access. If your project does not use a dedicated
      // schema, this falls back to public.admin_users.
      Map<String, dynamic>? row;
      try {
        row = await _client!
            .schema('control')
            .from('admin_users')
            .select('email, role, status')
            .eq('auth_user_id', authUser.id)
            .maybeSingle();
      } catch (_) {
        row = await _client!
            .from('admin_users')
            .select('email, role, status')
            .eq('auth_user_id', authUser.id)
            .maybeSingle();
      }

      if (row == null) {
        _adminEmail = authUser.email;
        _adminStatus = 'missing';
        _role = null;
        _accessDeniedReason = 'This account is not on the admin allow-list.';
        return;
      }

      _adminEmail = (row['email'] as String?) ?? authUser.email;
      _adminStatus = (row['status'] as String?) ?? 'unknown';
      _role = parseAdminRole(row['role'] as String?);

      if ((_adminStatus ?? '').toLowerCase() != 'active') {
        _accessDeniedReason = 'Admin status is not active.';
      } else if (_role == null) {
        _accessDeniedReason = 'Unknown admin role. Access denied.';
      }
    } catch (e) {
      debugPrint('AdminAuthStore._refreshAdminProfile failed: $e');
      _adminEmail = authUser.email;
      _adminStatus = 'error';
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
