import 'dart:async';
import 'dart:convert';

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
  final String? loginAuditAalClaim;
  final bool? loginAuditHasAal2Claim;
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
    required this.loginAuditAalClaim,
    required this.loginAuditHasAal2Claim,
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
    String? loginAuditAalClaim,
    bool? loginAuditHasAal2Claim,
    String? exceptionType,
    String? exceptionMessage,
  }) {
    return AdminLoginDiagnostics(
      signInAttempted: signInAttempted ?? this.signInAttempted,
      signInSucceeded: signInSucceeded ?? this.signInSucceeded,
      authUid: authUid ?? this.authUid,
      authEmail: authEmail ?? this.authEmail,
      adminUsersLookupAttempted:
          adminUsersLookupAttempted ?? this.adminUsersLookupAttempted,
      adminUsersRowFound: adminUsersRowFound ?? this.adminUsersRowFound,
      adminUsersAdminUserId:
          adminUsersAdminUserId ?? this.adminUsersAdminUserId,
      adminUsersEmail: adminUsersEmail ?? this.adminUsersEmail,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      routeTargetAfterLogin:
          routeTargetAfterLogin ?? this.routeTargetAfterLogin,
      loginAuditAttempted: loginAuditAttempted ?? this.loginAuditAttempted,
      loginAuditSucceeded: loginAuditSucceeded ?? this.loginAuditSucceeded,
      loginAuditTable: loginAuditTable ?? this.loginAuditTable,
      loginAuditActionType: loginAuditActionType ?? this.loginAuditActionType,
      loginAuditExceptionType:
          loginAuditExceptionType ?? this.loginAuditExceptionType,
      loginAuditExceptionMessage:
          loginAuditExceptionMessage ?? this.loginAuditExceptionMessage,
      loginAuditAuthUidPresent:
          loginAuditAuthUidPresent ?? this.loginAuditAuthUidPresent,
      loginAuditRolePresent:
          loginAuditRolePresent ?? this.loginAuditRolePresent,
      loginAuditAalClaim: loginAuditAalClaim ?? this.loginAuditAalClaim,
      loginAuditHasAal2Claim:
          loginAuditHasAal2Claim ?? this.loginAuditHasAal2Claim,
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
        loginAuditAalClaim: null,
        loginAuditHasAal2Claim: null,
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

enum AdminAuthGateState {
  signedOut,
  authConfigError,
  adminLookupError,
  notAdmin,
  inactiveAdmin,
  unknownRole,
  mfaRequired,
  authorized,
}

enum AdminMfaStateStatus {
  loading,
  available,
  unavailable,
}

class AdminMfaEnrollment {
  const AdminMfaEnrollment({
    required this.factorId,
    required this.qrCode,
    required this.secret,
    required this.uri,
  });

  final String factorId;
  final String qrCode;
  final String secret;
  final String uri;
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
  static const String _routeMfa = '/mfa';
  static const supabaseServiceRoleKey =
      String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY', defaultValue: '');

  /// IMPORTANT (Flutter Web + hash routing): `redirectTo` must be an absolute URL
  /// that includes the SPA hash fragment (/#/...). Do NOT join path segments.
  ///
  /// Keep this as a single hard-coded constant to avoid accidental URL joining
  /// that can produce malformed URLs like `...///set-password`.
  static String get passwordResetRedirectTo =>
      SupabaseConfig.setPasswordRedirectUrl;

  static bool _initialized = false;

  /// Debug output to verify Supabase bootstrap behavior in local/preview builds.
  ///
  /// Prints only true/false flags—never secret values.
  static void debugPrintSupabaseBootstrapStatus(
      {String source = 'AdminAuthStore'}) {
    if (!kDebugMode) return;

    final hasResolvedUrl =
        SupabaseConfig.resolvedSupabaseProjectUrl.trim().isNotEmpty;
    final hasResolvedAnon = SupabaseConfig.resolvedAnonKeyPresent;
    final serviceRoleDetected =
        SupabaseConfig.serviceRoleDetected || supabaseServiceRoleKey.isNotEmpty;

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
      'hasSUPABASE_URL=$hasResolvedUrl '
      'hasSUPABASE_ANON_KEY=$hasResolvedAnon '
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

    debugPrintSupabaseBootstrapStatus(
        source: 'AdminAuthStore.initializeSupabase(before)');

    // Fail closed if a service role key was accidentally bundled into the frontend.
    // (This should never be set in a client build.)
    if (supabaseServiceRoleKey.isNotEmpty ||
        SupabaseConfig.serviceRoleDetected) {
      debugPrint(
          'SECURITY: SUPABASE_SERVICE_ROLE_KEY detected in client build. Refusing to initialize Supabase.');
      return;
    }

    try {
      // Prefer a single initialization path (SupabaseConfig provides fallbacks + optional overrides).
      await SupabaseConfig.initialize();
      _initialized = SupabaseConfig.isInitialized ||
          _tryGetExistingSupabaseClient() != null;
      debugPrintSupabaseBootstrapStatus(
          source: 'AdminAuthStore.initializeSupabase(afterSupabaseConfigInit)');
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

  AuthenticatorAssuranceLevels? _currentAal;
  AuthenticatorAssuranceLevels? get currentAal => _currentAal;

  List<Factor> _verifiedTotpFactors = const [];
  List<Factor> get verifiedTotpFactors => _verifiedTotpFactors;

  AdminMfaStateStatus _mfaStateStatus = AdminMfaStateStatus.loading;
  AdminMfaStateStatus get mfaStateStatus => _mfaStateStatus;
  bool get isMfaStateLoading => _mfaStateStatus == AdminMfaStateStatus.loading;
  bool get isMfaStateAvailable =>
      _mfaStateStatus == AdminMfaStateStatus.available;
  bool get isMfaStateUnavailable =>
      _mfaStateStatus == AdminMfaStateStatus.unavailable;

  AdminMfaEnrollment? _mfaEnrollment;
  AdminMfaEnrollment? get mfaEnrollment => _mfaEnrollment;

  bool _isMfaBusy = false;
  bool get isMfaBusy => _isMfaBusy;

  String? _mfaError;
  String? get mfaError => _mfaError;

  String? _loginAuditWrittenForAccessToken;

  Future<void>? _mfaRefreshFuture;
  String? _mfaRefreshTokenInFlight;
  String? _lastSuccessfulMfaRefreshToken;
  int _authEventSequence = 0;

  String? _accessDeniedReason;
  String? get accessDeniedReason => _accessDeniedReason;

  AdminLoginDiagnostics _loginDiagnostics = AdminLoginDiagnostics.empty();
  AdminLoginDiagnostics get loginDiagnostics => _loginDiagnostics;

  void _resetLoginDiagnostics() =>
      _loginDiagnostics = AdminLoginDiagnostics.empty();

  void _recordLoginDiag(AdminLoginDiagnostics next) {
    _loginDiagnostics = next;
    notifyListeners();
  }

  /// Auth user id from Supabase Auth (auth.uid()).
  String? get authUid => _client?.auth.currentUser?.id;

  /// Auth email from Supabase Auth (may be null depending on provider).
  String? get authEmail => _client?.auth.currentUser?.email;

  bool get isSignedIn => _session != null;

  bool get isAllowListedActiveAdmin =>
      isSignedIn && (_isActive == true) && _role != null;

  bool get hasAal2 => _currentAal == AuthenticatorAssuranceLevels.aal2;

  bool get isMfaRequired => isAllowListedActiveAdmin && !hasAal2;

  bool get isAuthorized => isAllowListedActiveAdmin && hasAal2;

  AdminAuthGateState get gateState {
    if (_fatalConfigError != null) return AdminAuthGateState.authConfigError;
    if (!isSignedIn) return AdminAuthGateState.signedOut;
    if (_adminStatus == 'error') return AdminAuthGateState.adminLookupError;
    if (_adminStatus == 'missing') return AdminAuthGateState.notAdmin;
    if (_isActive == false) return AdminAuthGateState.inactiveAdmin;
    if (_isActive == true && _role == null) {
      return AdminAuthGateState.unknownRole;
    }
    if (isMfaRequired) return AdminAuthGateState.mfaRequired;
    if (isAuthorized) return AdminAuthGateState.authorized;
    return AdminAuthGateState.adminLookupError;
  }

  Future<void> bootstrap() async {
    debugPrintSupabaseBootstrapStatus(
        source: 'AdminAuthStore.bootstrap(start)');
    // Ensure initialize was called (main() should do this first, but keep defensive init).
    await initializeSupabase();

    // Explicit security fail-closed if a service role key is present.
    if (supabaseServiceRoleKey.isNotEmpty ||
        SupabaseConfig.serviceRoleDetected) {
      _fatalConfigError =
          'Security error: SUPABASE_SERVICE_ROLE_KEY detected in a client build.\n\n'
          'Remove it from your build configuration and rebuild.';
      debugPrintSupabaseBootstrapStatus(
          source: 'AdminAuthStore.bootstrap(serviceRoleDetected)');
      _isBootstrapping = false;
      notifyListeners();
      return;
    }

    // If we still cannot access a client, THEN fail closed with a clear error.
    if (_tryGetExistingSupabaseClient() == null) {
      _fatalConfigError = 'Supabase failed to initialize in this build.\n\n'
          'This usually means required public configuration is missing.\n\n'
          'Recommended (Control Site Web Deployments):\n'
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
      debugPrintSupabaseBootstrapStatus(
          source: 'AdminAuthStore.bootstrap(fatalConfigError)');
      _isBootstrapping = false;
      notifyListeners();
      return;
    }

    debugPrintSupabaseBootstrapStatus(
        source: 'AdminAuthStore.bootstrap(afterInitializeSupabase)');

    _session = _client?.auth.currentSession;

    _authSub?.cancel();
    _authSub = _client?.auth.onAuthStateChange.listen(
      (event) {
        unawaited(_handleAuthStateChange(event));
      },
      onError: _handleAuthStateError,
    );

    await _refreshAdminProfile();
    await _refreshMfaState();
    _isBootstrapping = false;
    notifyListeners();
  }

  Future<void> _handleAuthStateChange(AuthState event) async {
    final sequence = ++_authEventSequence;
    final eventType = event.event;
    final nextSession = event.session ?? _client?.auth.currentSession;
    final isDestructiveSignOut = eventType == AuthChangeEvent.signedOut ||
        eventType.name == 'userDeleted';

    if (isDestructiveSignOut) {
      _session = null;
      _clearAdminState();
      notifyListeners();
      return;
    }

    if (nextSession == null) {
      _currentAal = null;
      _mfaStateStatus = AdminMfaStateStatus.unavailable;
      if (isAllowListedActiveAdmin) {
        _mfaError = 'MFA status could not be loaded. Try again.';
      }
      notifyListeners();
      return;
    }

    switch (eventType) {
      case AuthChangeEvent.initialSession:
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
      case AuthChangeEvent.userUpdated:
      case AuthChangeEvent.passwordRecovery:
        _session = nextSession;
        await _refreshAdminProfile();
        if (sequence != _authEventSequence) return;
        await _refreshMfaState();
        break;
      case AuthChangeEvent.mfaChallengeVerified:
        _session = nextSession;
        await _refreshAdminProfile();
        if (sequence != _authEventSequence) return;
        await _refreshMfaState(force: true);
        break;
      case AuthChangeEvent.signedOut:
      default:
        return;
    }
    if (sequence != _authEventSequence) return;
    notifyListeners();
  }

  void _handleAuthStateError(Object error, StackTrace stackTrace) {
    debugPrint('AdminAuthStore.onAuthStateChange error: ${error.runtimeType}');
    _currentAal = null;
    if (isAllowListedActiveAdmin) {
      _mfaStateStatus = AdminMfaStateStatus.unavailable;
      _mfaError = 'MFA status could not be loaded. Try again.';
    }
    notifyListeners();
  }

  Future<void> signInWithPassword(
      {required String email, required String password}) async {
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
      final res = await _client!.auth
          .signInWithPassword(email: email.trim(), password: password);
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
        await _refreshMfaState();
      } catch (e) {
        // Auth succeeded, but allow-list lookup failed (network/RLS/table missing).
        throw AdminAuthAllowListLookupException(e.toString());
      }

      // If Supabase auth succeeded but allow-list/role checks failed, treat it
      // as a denied Control Site login. In release, immediately discard that
      // session so allow-list membership is not exposed by lingering state.
      if (!isAllowListedActiveAdmin) {
        final reason = kDebugMode
            ? (_accessDeniedReason ?? 'Not allow-listed.')
            : 'Access denied.';
        _recordLoginDiag(
          loginDiagnostics.copyWith(
            routeTargetAfterLogin: _routeUnauthorized,
            exceptionType: 'AdminAccessDeniedException',
            exceptionMessage: reason,
          ),
        );
        if (kReleaseMode) {
          await _client?.auth.signOut();
          _session = null;
          _clearAdminState();
        }
        throw AdminAccessDeniedException(reason);
      }

      if (isMfaRequired) {
        _recordLoginDiag(
          loginDiagnostics.copyWith(routeTargetAfterLogin: _routeMfa),
        );
        return;
      }

      _recordLoginDiag(
          loginDiagnostics.copyWith(routeTargetAfterLogin: _routeAdminTest));

      if (isAuthorized) {
        await _writeSuccessfulAdminLoginAudit(email: email.trim());
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
          throw const AdminAuthInvalidCredentialsException(
              'Invalid login credentials');
        }
      }

      final s = e.toString().toLowerCase();
      if (e is AuthRetryableFetchException ||
          s.contains('failed to fetch') ||
          s.contains('clientexception: failed to fetch')) {
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
      debugPrint(
          'AdminAuthStore.sendPasswordResetEmail: Supabase client not available.');
      return;
    }
    try {
      // CRITICAL: Do not construct/normalize this with Uri helpers.
      final redirectTo = AdminAuthStore.passwordResetRedirectTo;
      if (kDebugMode) {
        debugPrint(
            'AdminAuthStore.sendPasswordResetEmail: using redirectTo=$redirectTo');
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
      debugPrint(
          'AdminAuthStore.updatePassword: Supabase client not available.');
      return;
    }
    try {
      await c.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      debugPrint('AdminAuthStore.updatePassword failed: $e');
      rethrow;
    }
  }

  Future<void> startTotpEnrollment() async {
    if (!isAllowListedActiveAdmin) {
      throw const AdminAccessDeniedException('Access denied.');
    }
    if (!isMfaStateAvailable) {
      _mfaError = 'MFA status could not be loaded. Try again.';
      notifyListeners();
      throw StateError('MFA state is not available.');
    }
    if (_client == null) return;
    _isMfaBusy = true;
    _mfaError = null;
    notifyListeners();
    try {
      final response = await _client!.auth.mfa.enroll(
        factorType: FactorType.totp,
        issuer: 'CuraVault Control Site',
        friendlyName: 'CuraVault Control Site',
      );
      final totp = response.totp;
      if (totp == null) {
        throw StateError('TOTP enrollment was not returned.');
      }
      _mfaEnrollment = AdminMfaEnrollment(
        factorId: response.id,
        qrCode: totp.qrCode,
        secret: totp.secret,
        uri: totp.uri,
      );
    } catch (e) {
      debugPrint('AdminAuthStore.startTotpEnrollment failed: $e');
      _mfaError = 'Could not start MFA enrollment. Try again.';
      rethrow;
    } finally {
      _isMfaBusy = false;
      notifyListeners();
    }
  }

  Future<void> verifyTotpCode({
    required String code,
    String? factorId,
  }) async {
    if (!isAllowListedActiveAdmin) {
      throw const AdminAccessDeniedException('Access denied.');
    }
    if (_client == null) return;
    final normalizedCode = code.trim().replaceAll(' ', '');
    if (normalizedCode.length < 6) {
      throw const FormatException('Enter the 6-digit code.');
    }

    final selectedFactorId = factorId ?? _mfaEnrollment?.factorId;
    final verifiedFactorId =
        _verifiedTotpFactors.isEmpty ? null : _verifiedTotpFactors.first.id;
    final factorToVerify = selectedFactorId ?? verifiedFactorId;
    if (factorToVerify == null) {
      throw StateError('No TOTP factor is available for verification.');
    }

    _isMfaBusy = true;
    _mfaError = null;
    notifyListeners();
    try {
      await _client!.auth.mfa.challengeAndVerify(
        factorId: factorToVerify,
        code: normalizedCode,
      );
      await _client!.auth.refreshSession();
      _session = _client!.auth.currentSession;
      _mfaEnrollment = null;
      await _refreshAdminProfile();
      await _refreshMfaState(force: true);
      if (isAuthorized) {
        await _writeSuccessfulAdminLoginAudit(email: _adminEmail);
      }
    } catch (e) {
      debugPrint('AdminAuthStore.verifyTotpCode failed: $e');
      _mfaError = 'MFA verification failed. Check the code and try again.';
      rethrow;
    } finally {
      _isMfaBusy = false;
      notifyListeners();
    }
  }

  Future<void> _writeSuccessfulAdminLoginAudit({String? email}) async {
    final actor = _client?.auth.currentUser?.id;
    final token = _client?.auth.currentSession?.accessToken;
    if (actor == null || actor.isEmpty || token == null) return;
    if (_loginAuditWrittenForAccessToken == token) return;
    final aalClaim = _jwtClaim(token, 'aal');
    final hasAal2Claim = aalClaim == 'aal2';

    const actionType = 'admin_login';
    _recordLoginDiag(
      loginDiagnostics.copyWith(
        loginAuditAttempted: true,
        loginAuditSucceeded: false,
        loginAuditTable: 'public.admin_audit_log',
        loginAuditActionType: actionType,
        loginAuditAuthUidPresent: true,
        loginAuditRolePresent: role != null,
        loginAuditAalClaim: aalClaim,
        loginAuditHasAal2Claim: hasAal2Claim,
        loginAuditExceptionType: null,
        loginAuditExceptionMessage: null,
      ),
    );
    try {
      final inserted = await _writeAudit(
        adminUserId: actor,
        actionType: actionType,
        result: 'success',
        newValue: {'email': email ?? _adminEmail ?? ''},
        failClosed: false,
      );
      if (!inserted) {
        throw StateError('admin_login audit insert was not accepted.');
      }
      _loginAuditWrittenForAccessToken = token;
      _recordLoginDiag(loginDiagnostics.copyWith(loginAuditSucceeded: true));
    } catch (e) {
      debugPrint(
          'AdminAuthStore admin_login audit insert failed (best-effort): $e');
      _recordLoginDiag(
        loginDiagnostics.copyWith(
          loginAuditSucceeded: false,
          loginAuditExceptionType: _safeAuditExceptionType(e),
          loginAuditExceptionMessage: _safeAuditExceptionMessage(e),
        ),
      );
    }
  }

  String? _jwtClaim(String token, String claim) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded);
      if (payload is Map<String, dynamic>) return payload[claim]?.toString();
    } catch (_) {}
    return null;
  }

  String _safeAuditExceptionType(Object e) {
    if (e is PostgrestException) {
      final code = e.code;
      return code == null ? 'PostgrestException' : 'PostgrestException:$code';
    }
    return e.runtimeType.toString();
  }

  String _safeAuditExceptionMessage(Object e) {
    if (e is PostgrestException) {
      final code = e.code ?? 'unknown';
      return 'PostgREST insert failed (code $code).';
    }
    return e.toString();
  }

  Future<bool> _writeAudit({
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
      if (failClosed) {
        throw StateError(
            'Supabase client not initialized; cannot write audit log.');
      }
      return false;
    }
    try {
      final row = <String, dynamic>{
        // Matches public.admin_audit_log schema.
        'admin_user_id': adminUserId,
        'admin_email': c.auth.currentUser?.email,
        if (targetUserId != null) 'target_user_id': targetUserId,
        'action_type': actionType,
        'result': result ?? 'success',
        if (previousValue != null)
          'prev': AdminAuditRedactor.redactMap(previousValue),
        if (newValue != null) 'next': AdminAuditRedactor.redactMap(newValue),
        if (reason != null) 'reason': reason,
        if (ticketReference != null) 'ticket_id': ticketReference,
        if (AdminClientContext.ipAddress != null)
          'ip': AdminClientContext.ipAddress,
        if (AdminClientContext.userAgent != null)
          'user_agent': AdminClientContext.userAgent,
        // created_at is NOT NULL; keep explicit for clarity.
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      await c.from('admin_audit_log').insert(row);
      return true;
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
      rethrow;
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
      _clearAdminState();
      _accessDeniedReason = null;
      notifyListeners();
    }
  }

  void _clearAdminState() {
    _adminEmail = null;
    _adminUserId = null;
    _adminDisplayName = null;
    _adminStatus = null;
    _isActive = null;
    _requireStepUp = null;
    _role = null;
    _currentAal = null;
    _verifiedTotpFactors = const [];
    _mfaStateStatus = AdminMfaStateStatus.loading;
    _mfaEnrollment = null;
    _mfaError = null;
    _loginAuditWrittenForAccessToken = null;
    _mfaRefreshFuture = null;
    _mfaRefreshTokenInFlight = null;
    _lastSuccessfulMfaRefreshToken = null;
  }

  Future<void> _refreshAdminProfile(
      {bool recordLoginDiagnostics = false}) async {
    _accessDeniedReason = null;

    if (recordLoginDiagnostics) {
      _recordLoginDiag(
          loginDiagnostics.copyWith(adminUsersLookupAttempted: true));
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
          .select(
              'admin_user_id, email, display_name, role, is_active, require_step_up')
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
      _adminDisplayName =
          (row['display_name'] as String?)?.trim().isEmpty == true
              ? null
              : (row['display_name'] as String?);
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

  Future<void> retryMfaStateRefresh() async {
    await _refreshMfaState(force: true);
    notifyListeners();
  }

  Future<void> _refreshMfaState({bool force = false}) async {
    final session = _client?.auth.currentSession;
    final token = session?.accessToken;
    if (session == null || token == null || token.isEmpty) {
      _currentAal = null;
      _verifiedTotpFactors = const [];
      _mfaStateStatus = AdminMfaStateStatus.loading;
      return;
    }

    if (!force &&
        _lastSuccessfulMfaRefreshToken == token &&
        _mfaStateStatus == AdminMfaStateStatus.available) {
      return;
    }

    if (!force) {
      final aal = _client!.auth.mfa.getAuthenticatorAssuranceLevel();
      _currentAal = aal.currentLevel;
      _verifiedTotpFactors = (session.user.factors ?? const <Factor>[])
          .where((factor) =>
              factor.factorType == FactorType.totp &&
              factor.status == FactorStatus.verified)
          .toList();
      _mfaStateStatus = AdminMfaStateStatus.available;
      _lastSuccessfulMfaRefreshToken = token;
      _mfaError = null;
      return;
    }

    if (_mfaRefreshFuture != null && _mfaRefreshTokenInFlight == token) {
      return _mfaRefreshFuture!;
    }

    _mfaRefreshTokenInFlight = token;
    _mfaStateStatus = AdminMfaStateStatus.loading;
    _mfaError = null;
    final refresh = _refreshMfaStateForToken(token);
    _mfaRefreshFuture = refresh;
    try {
      await refresh;
    } finally {
      if (_mfaRefreshFuture == refresh) {
        _mfaRefreshFuture = null;
        _mfaRefreshTokenInFlight = null;
      }
    }
  }

  Future<void> _refreshMfaStateForToken(String token) async {
    try {
      final aal = _client!.auth.mfa.getAuthenticatorAssuranceLevel();
      final factors = await _client!.auth.mfa.listFactors();
      if (_client?.auth.currentSession?.accessToken != token) return;
      _currentAal = aal.currentLevel;
      _verifiedTotpFactors = factors.totp;
      _mfaStateStatus = AdminMfaStateStatus.available;
      _lastSuccessfulMfaRefreshToken = token;
      _mfaError = null;
    } catch (e) {
      debugPrint('AdminAuthStore._refreshMfaState failed: ${e.runtimeType}');
      _currentAal = null;
      _verifiedTotpFactors = const [];
      _mfaStateStatus = AdminMfaStateStatus.unavailable;
      if (isAllowListedActiveAdmin) {
        _mfaError = 'MFA status could not be loaded. Try again.';
      }
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
