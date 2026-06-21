import 'dart:async';

import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/utils/audit_redactor.dart';
import 'package:curavault_admin/admin/utils/client_context.dart';
import 'package:curavault_admin/services/usage_event_service.dart';
import 'package:curavault_admin/supabase/supabase_config.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminLoginDiagnostics {
  final bool signInAttempted;
  final bool signInSucceeded;
  final String? authUid;
  final String? authEmail;
  final bool adminUsersLookupAttempted;
  final bool adminUsersRowFound;
  final String? adminUsersAdminUserId;
  final String? adminUsersEmail;
  final String? role;
  final bool? isActive;
  final String? routeTargetAfterLogin;
  final bool loginAuditAttempted;
  final bool loginAuditSucceeded;
  final String? loginAuditTable;
  final String? loginAuditActionType;
  final String? loginAuditExceptionType;
  final String? loginAuditExceptionMessage;
  final bool? loginAuditAuthUidPresent;
  final bool? loginAuditRolePresent;
  final String? exceptionType;
  final String? exceptionMessage;

  const AdminLoginDiagnostics({
    required this.signInAttempted,
    required this.signInSucceeded,
    required this.authUid,
    required this.authEmail,
    required this.adminUsersLookupAttempted,
    required this.adminUsersRowFound,
    required this.adminUsersAdminUserId,
    required this.adminUsersEmail,
    required this.role,
    required this.isActive,
    required this.routeTargetAfterLogin,
    required this.loginAuditAttempted,
    required this.loginAuditSucceeded,
    required this.loginAuditTable,
    required this.loginAuditActionType,
    required this.loginAuditExceptionType,
    required this.loginAuditExceptionMessage,
    required this.loginAuditAuthUidPresent,
    required this.loginAuditRolePresent,
    required this.exceptionType,
    required this.exceptionMessage,
  });

  AdminLoginDiagnostics copyWith({
    bool? signInAttempted,
    bool? signInSucceeded,
    String? authUid,
    String? authEmail,
    bool? adminUsersLookupAttempted,
    bool? adminUsersRowFound,
    String? adminUsersAdminUserId,
    String? adminUsersEmail,
    String? role,
    bool? isActive,
    String? routeTargetAfterLogin,
    bool? loginAuditAttempted,
    bool? loginAuditSucceeded,
    String? loginAuditTable,
    String? loginAuditActionType,
    String? loginAuditExceptionType,
    String? loginAuditExceptionMessage,
    bool? loginAuditAuthUidPresent,
    bool? loginAuditRolePresent,
    String? exceptionType,
    String? exceptionMessage,
  }) {
    return AdminLoginDiagnostics(
      signInAttempted: signInAttempted ?? this.signInAttempted,
      signInSucceeded: signInSucceeded ?? this.signInSucceeded,
      authUid: authUid ?? this.authUid,
      authEmail: authEmail ?? this.authEmail,
      adminUsersLookupAttempted: adminUsersLookupAttempted ?? this.adminUsersLookupAttempted,
      adminUsersRowFound: adminUsersRowFound ?? this.adminUsersRowFound,
      adminUsersAdminUserId: adminUsersAdminUserId ?? this.adminUsersAdminUserId,
      adminUsersEmail: adminUsersEmail ?? this.adminUsersEmail,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      routeTargetAfterLogin: routeTargetAfterLogin ?? this.routeTargetAfterLogin,
      loginAuditAttempted: loginAuditAttempted ?? this.loginAuditAttempted,
      loginAuditSucceeded: loginAuditSucceeded ?? this.loginAuditSucceeded,
      loginAuditTable: loginAuditTable ?? this.loginAuditTable,
      loginAuditActionType: loginAuditActionType ?? this.loginAuditActionType,
      loginAuditExceptionType: loginAuditExceptionType ?? this.loginAuditExceptionType,
      loginAuditExceptionMessage: loginAuditExceptionMessage ?? this.loginAuditExceptionMessage,
      loginAuditAuthUidPresent: loginAuditAuthUidPresent ?? this.loginAuditAuthUidPresent,
      loginAuditRolePresent: loginAuditRolePresent ?? this.loginAuditRolePresent,
      exceptionType: exceptionType ?? this.exceptionType,
      exceptionMessage: exceptionMessage ?? this.exceptionMessage,
    );
  }

  static AdminLoginDiagnostics empty() => const AdminLoginDiagnostics(
        signInAttempted: false,
        signInSucceeded: false,
        authUid: null,
        authEmail: null,
        adminUsersLookupAttempted: false,
        adminUsersRowFound: false,
        adminUsersAdminUserId: null,
        adminUsersEmail: null,
        role: null,
        isActive: null,
        routeTargetAfterLogin: null,
        loginAuditAttempted: false,
        loginAuditSucceeded: false,
        loginAuditTable: null,
        loginAuditActionType: null,
        loginAuditExceptionType: null,
        loginAuditExceptionMessage: null,
        loginAuditAuthUidPresent: null,
        loginAuditRolePresent: null,
        exceptionType: null,
        exceptionMessage: null,
      );
}

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
  // Keep route strings here to avoid circular imports with nav.dart.
  static const String _routeUnauthorized = '/unauthorized';
  static const String _routeAdminTest = '/admin-test';
  static const supabaseServiceRoleKey = String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY', defaultValue: '');

  /// IMPORTANT (Flutter Web + hash routing): `redirectTo` must be an absolute URL
  /// that includes the SPA hash fragment (/#/...). Do NOT join path segments.
  ///
  /// Keep this as a single hard-coded constant to avoid accidental URL joining
  /// that can produce malformed URLs like `...///set-password`.
  static String get passwordResetRedirectTo => SupabaseConfig.setPasswordRedirectUrl;

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

  String? _adminUserId;
  String? get adminUserId => _adminUserId;

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

  AdminLoginDiagnostics _loginDiagnostics = AdminLoginDiagnostics.empty();
  AdminLoginDiagnostics get loginDiagnostics => _loginDiagnostics;

  void _resetLoginDiagnostics() => _loginDiagnostics = AdminLoginDiagnostics.empty();

  void _recordLoginDiag(AdminLoginDiagnostics next) {
    _loginDiagnostics = next;
    notifyListeners();
  }

  /// Auth user id from Supabase Auth (auth.uid()).
  String? get authUid => _client?.auth.currentUser?.id;

  /// Auth email from Supabase Auth (may be null depending on provider).
  String? get authEmail => _client?.auth.currentUser?.email;

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
          'This usually means required public configuration is missing.\n\n'
          'Recommended (Dreamflow Web Deployments):\n'
          '- Edit assets/config/control_site_config.json and set:\n'
          '  • SUPABASE_URL\n'
          '  • SUPABASE_ANON_KEY (publishable/anon key only)\n'
          '  • CONTROL_SITE_BASE_URL\n\n'
          'Alternative (local builds / CI): provide build-time Dart defines:\n'
          '- --dart-define=SUPABASE_URL=...\n'
          '- --dart-define=SUPABASE_ANON_KEY=...\n'
          '- --dart-define=CONTROL_SITE_BASE_URL=... (recommended for auth redirects)\n\n'
          'Security notes:\n'
          '- Never use the service role key in frontend code.\n'
          '- Do not expose database passwords or service_role JWTs.';
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
    _resetLoginDiagnostics();
    _recordLoginDiag(
      loginDiagnostics.copyWith(
        signInAttempted: true,
        exceptionType: null,
        exceptionMessage: null,
        routeTargetAfterLogin: null,
      ),
    );
    notifyListeners();
    try {
      final res = await _client!.auth.signInWithPassword(email: email.trim(), password: password);
      _session = res.session;

      // Best-effort usage instrumentation (no PHI).
      UsageEventService.instance.trackFeatureEvent(
        eventName: 'login_succeeded',
        featureArea: 'auth',
        result: _session != null ? 'success' : 'failure',
      );

      final authUser = _client!.auth.currentUser;
      _recordLoginDiag(
        loginDiagnostics.copyWith(
          signInSucceeded: _session != null,
          authUid: authUser?.id,
          authEmail: authUser?.email,
        ),
      );

      try {
        await _refreshAdminProfile(recordLoginDiagnostics: true);
      } catch (e) {
        // Auth succeeded, but allow-list lookup failed (network/RLS/table missing).
        throw AdminAuthAllowListLookupException(e.toString());
      }

      // If Supabase auth succeeded but allow-list/role checks failed, treat it as
      // a login denial.
      //
      // IMPORTANT: For the normal login flow we MUST NOT sign out automatically.
      // The connectivity test page may sign out after probing, but the real login
      // flow keeps the session so we can debug allow-list/RLS issues.
      if (!isAuthorized) {
        final reason = _accessDeniedReason ?? 'Not allow-listed.';
        _recordLoginDiag(
          loginDiagnostics.copyWith(
            routeTargetAfterLogin: _routeUnauthorized,
            exceptionType: 'AdminAccessDeniedException',
            exceptionMessage: reason,
          ),
        );
        throw AdminAccessDeniedException(reason);
      }

      _recordLoginDiag(loginDiagnostics.copyWith(routeTargetAfterLogin: _routeAdminTest));

      final actor = _client!.auth.currentUser?.id;
      if (actor != null && actor.isNotEmpty) {
        const actionType = 'admin_login';
        _recordLoginDiag(
          loginDiagnostics.copyWith(
            loginAuditAttempted: true,
            loginAuditSucceeded: false,
            loginAuditTable: 'public.admin_audit_log',
            loginAuditActionType: actionType,
            loginAuditAuthUidPresent: true,
            loginAuditRolePresent: role != null,
            loginAuditExceptionType: null,
            loginAuditExceptionMessage: null,
          ),
        );
        try {
          // LOGIN audit is best-effort: never block a successful login.
          await _writeAudit(
            adminUserId: actor,
            actionType: actionType,
            result: 'success',
            newValue: {'email': email.trim()},
            failClosed: false,
          );
          _recordLoginDiag(loginDiagnostics.copyWith(loginAuditSucceeded: true));
        } catch (e) {
          debugPrint('AdminAuthStore.signInWithPassword login audit insert failed (best-effort): $e');
          _recordLoginDiag(
            loginDiagnostics.copyWith(
              loginAuditSucceeded: false,
              loginAuditExceptionType: e.runtimeType.toString(),
              loginAuditExceptionMessage: e.toString(),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('AdminAuthStore.signInWithPassword failed: $e');

      UsageEventService.instance.trackFeatureEvent(
        eventName: 'login_failed',
        featureArea: 'auth',
        result: 'failure',
        errorCode: e.runtimeType.toString(),
      );

      _recordLoginDiag(
        loginDiagnostics.copyWith(
          exceptionType: e.runtimeType.toString(),
          exceptionMessage: e.toString(),
        ),
      );

      // TEMPORARY: Do not write audit rows for failed sign-ins.
      // This avoids masking root-cause connectivity failures with a secondary
      // PostgREST/audit error.

      // Normalize error types for the UI.
      if (e is AuthException) {
        final msg = e.message;
        if (msg.toLowerCase().contains('invalid login credentials')) {
          _recordLoginDiag(
            loginDiagnostics.copyWith(
              routeTargetAfterLogin: '/login',
              exceptionType: 'AdminAuthInvalidCredentialsException',
              exceptionMessage: 'Invalid email or password.',
            ),
          );
          throw const AdminAuthInvalidCredentialsException('Invalid login credentials');
        }
      }

      final s = e.toString().toLowerCase();
      if (e is AuthRetryableFetchException || s.contains('failed to fetch') || s.contains('clientexception: failed to fetch')) {
        _recordLoginDiag(
          loginDiagnostics.copyWith(
            routeTargetAfterLogin: '/login',
            exceptionType: 'AdminAuthNetworkException',
            exceptionMessage: e.toString(),
          ),
        );
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
      final redirectTo = AdminAuthStore.passwordResetRedirectTo;
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
      final row = <String, dynamic>{
        // Matches public.admin_audit_log schema.
        'admin_user_id': adminUserId,
        'admin_email': c.auth.currentUser?.email,
        if (targetUserId != null) 'target_user_id': targetUserId,
        'action_type': actionType,
        'result': result ?? 'success',
        if (previousValue != null) 'prev': AdminAuditRedactor.redactMap(previousValue),
        if (newValue != null) 'next': AdminAuditRedactor.redactMap(newValue),
        if (reason != null) 'reason': reason,
        if (ticketReference != null) 'ticket_id': ticketReference,
        if (AdminClientContext.ipAddress != null) 'ip': AdminClientContext.ipAddress,
        if (AdminClientContext.userAgent != null) 'user_agent': AdminClientContext.userAgent,
        // created_at is NOT NULL; keep explicit for clarity.
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      await c.from('admin_audit_log').insert(row);
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
      UsageEventService.instance.trackFeatureEvent(
        eventName: 'logout',
        featureArea: 'auth',
        result: 'success',
      );
      await _client?.auth.signOut();
    } catch (e) {
      debugPrint('AdminAuthStore.signOut failed: $e');

      UsageEventService.instance.trackFeatureEvent(
        eventName: 'logout',
        featureArea: 'auth',
        result: 'failure',
        errorCode: e.runtimeType.toString(),
      );
    } finally {
      _session = null;
      _adminEmail = null;
      _adminUserId = null;
      _adminDisplayName = null;
      _adminStatus = null;
      _isActive = null;
      _requireStepUp = null;
      _role = null;
      _accessDeniedReason = null;
      notifyListeners();
    }
  }

  Future<void> _refreshAdminProfile({bool recordLoginDiagnostics = false}) async {
    _accessDeniedReason = null;

    if (recordLoginDiagnostics) {
      _recordLoginDiag(loginDiagnostics.copyWith(adminUsersLookupAttempted: true));
    }

    final authUser = _client?.auth.currentUser;
    if (authUser == null) {
      _adminEmail = null;
      _adminUserId = null;
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
          .select('admin_user_id, email, display_name, role, is_active, require_step_up')
          .eq('admin_user_id', authUser.id)
          .maybeSingle();

      if (row == null) {
        _adminEmail = authUser.email;
        _adminUserId = null;
        _adminDisplayName = null;
        _adminStatus = 'missing';
        _isActive = false;
        _requireStepUp = null;
        _role = null;
        _accessDeniedReason = 'Authenticated but not allow-listed.';
        if (recordLoginDiagnostics) {
          _recordLoginDiag(
            loginDiagnostics.copyWith(
              adminUsersRowFound: false,
              adminUsersAdminUserId: null,
              adminUsersEmail: null,
              role: null,
              isActive: false,
            ),
          );
        }
        return;
      }

      _adminUserId = (row['admin_user_id'] as String?) ?? authUser.id;
      _adminEmail = (row['email'] as String?) ?? authUser.email;
      _adminDisplayName = (row['display_name'] as String?)?.trim().isEmpty == true ? null : (row['display_name'] as String?);
      final isActive = row['is_active'] == true;
      _isActive = isActive;
      _adminStatus = isActive ? 'active' : 'inactive';
      _requireStepUp = row['require_step_up'] == true;
      _role = parseAdminRole(row['role'] as String?);

      if (recordLoginDiagnostics) {
        _recordLoginDiag(
          loginDiagnostics.copyWith(
            adminUsersRowFound: true,
            adminUsersAdminUserId: _adminUserId,
            adminUsersEmail: _adminEmail,
            role: row['role']?.toString(),
            isActive: _isActive,
          ),
        );
      }

      if (!isActive) {
        _accessDeniedReason = 'Admin user inactive.';
      } else if (_role == null) {
        _accessDeniedReason = 'Unknown admin role. Access denied.';
      }
    } catch (e) {
      debugPrint('AdminAuthStore._refreshAdminProfile failed: $e');
      _adminEmail = authUser.email;
      _adminUserId = null;
      _adminDisplayName = null;
      _adminStatus = 'error';
      _isActive = false;
      _requireStepUp = null;
      _role = null;
      _accessDeniedReason = 'Failed to validate admin access. Try again later.';

      if (recordLoginDiagnostics) {
        _recordLoginDiag(
          loginDiagnostics.copyWith(
            adminUsersRowFound: false,
            exceptionType: e.runtimeType.toString(),
            exceptionMessage: e.toString(),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
