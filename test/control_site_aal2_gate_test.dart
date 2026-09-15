import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Control Site AAL2 gate', () {
    late final String authStore;
    late final String nav;
    late final String setPasswordPage;
    late final String mfaPage;
    late final String topBar;

    setUpAll(() {
      authStore =
          File('lib/admin/auth/admin_auth_store.dart').readAsStringSync();
      nav = File('lib/nav.dart').readAsStringSync();
      setPasswordPage =
          File('lib/admin/pages/set_password_page.dart').readAsStringSync();
      mfaPage = File('lib/admin/pages/mfa_page.dart').readAsStringSync();
      topBar =
          File('lib/admin/pages/widgets/admin_top_bar.dart').readAsStringSync();
    });

    test(
        'requires active allow-listed admins to reach AAL2 before authorization',
        () {
      expect(
        authStore,
        contains(
          'bool get isAuthorized => isAllowListedActiveAdmin && hasAal2;',
        ),
      );
      expect(
        authStore,
        contains(
            'bool get isMfaRequired => isAllowListedActiveAdmin && !hasAal2;'),
      );
      expect(
        authStore,
        contains(
          'bool get hasAal2 => _currentAal == AuthenticatorAssuranceLevels.aal2;',
        ),
      );
    });

    test('uses Supabase TOTP MFA APIs and writes login audit only after AAL2',
        () {
      expect(authStore, contains('FactorType.totp'));
      expect(authStore, contains('mfa.enroll'));
      expect(authStore, contains('mfa.challengeAndVerify'));
      expect(authStore, contains('mfa.getAuthenticatorAssuranceLevel'));

      final mfaRequiredIndex = authStore.indexOf('if (isMfaRequired)');
      final auditIndex = authStore.indexOf('_writeSuccessfulAdminLoginAudit');
      expect(mfaRequiredIndex, greaterThanOrEqualTo(0));
      expect(auditIndex, greaterThan(mfaRequiredIndex));
    });

    test('only marks admin_login audit written after insert success', () {
      expect(authStore, contains('Future<bool> _writeAudit'));
      expect(
        authStore,
        contains(
            "throw StateError('admin_login audit insert was not accepted.')"),
      );
      final insertIndex = authStore.indexOf(
        'final inserted = await _writeAudit(',
      );
      final guardIndex = authStore.indexOf('if (!inserted) {');
      final successIndex =
          authStore.indexOf('_loginAuditWrittenForAccessToken = token;');
      expect(insertIndex, greaterThanOrEqualTo(0));
      expect(guardIndex, greaterThan(insertIndex));
      expect(successIndex, greaterThan(insertIndex));
      expect(successIndex, greaterThan(guardIndex));
    });

    test('routes AAL1 active admins to the protected MFA gate', () {
      expect(nav, contains("static const String mfa = '/mfa';"));
      expect(nav, contains('path: AppRoutes.mfa'));
      expect(nav, contains('MfaPage'));
      expect(nav, contains('auth.isMfaRequired'));
      expect(nav, contains('matched == AppRoutes.mfa'));
      expect(nav, isNot(contains('normalized == AppRoutes.mfa')));
    });

    test('password setup sends allow-listed admins to MFA before the shell',
        () {
      expect(setPasswordPage, contains('context.go(AppRoutes.mfa);'));
      expect(
          setPasswordPage, isNot(contains('context.go(AppRoutes.dashboard);')));
    });

    test('MFA page supports enrollment, verification, and explicit sign-out',
        () {
      expect(mfaPage, contains('startTotpEnrollment'));
      expect(mfaPage, contains('verifyTotpCode'));
      expect(mfaPage, contains('Manual setup key'));
      expect(mfaPage, contains('auth.signOut'));
    });

    test('auth listener handles stream errors without destructive sign-out',
        () {
      expect(authStore, contains('onError: _handleAuthStateError'));
      expect(authStore, contains('void _handleAuthStateError'));
      expect(authStore, contains('AdminMfaStateStatus.unavailable'));
      expect(
        authStore,
        contains("'MFA status could not be loaded. Try again.'"),
      );
      expect(
        authStore,
        isNot(contains('event.session == null) {\n      _clearAdminState')),
      );
    });

    test('auth event handling distinguishes sign-out from refresh events', () {
      expect(authStore, contains('switch (eventType)'));
      expect(authStore, contains('AuthChangeEvent.initialSession'));
      expect(authStore, contains('AuthChangeEvent.signedIn'));
      expect(authStore, contains('AuthChangeEvent.signedOut'));
      expect(authStore, contains('AuthChangeEvent.tokenRefreshed'));
      expect(authStore, contains('AuthChangeEvent.userUpdated'));
      expect(authStore, contains("eventType.name == 'userDeleted'"));
      expect(authStore, contains('AuthChangeEvent.passwordRecovery'));
      expect(authStore, contains('AuthChangeEvent.mfaChallengeVerified'));
      expect(authStore, contains('final sequence = ++_authEventSequence'));
      expect(authStore, contains('if (sequence != _authEventSequence) return'));
    });

    test('MFA factor refresh is coalesced by access token', () {
      expect(authStore, contains('Future<void>? _mfaRefreshFuture'));
      expect(authStore, contains('String? _mfaRefreshTokenInFlight'));
      expect(authStore, contains('String? _lastSuccessfulMfaRefreshToken'));
      expect(
        authStore,
        contains('_lastSuccessfulMfaRefreshToken == token'),
      );
      expect(
        authStore,
        contains(
          'if (_mfaRefreshFuture != null && _mfaRefreshTokenInFlight == token)',
        ),
      );
      expect(authStore, contains('_refreshMfaState(force: true)'));
    });

    test('transient MFA refresh errors fail closed without enrollment UI', () {
      expect(authStore, contains('enum AdminMfaStateStatus'));
      expect(authStore, contains('bool get isMfaStateUnavailable'));
      expect(authStore, contains('Future<void> retryMfaStateRefresh()'));
      expect(mfaPage, contains('final mfaUnavailable'));
      expect(mfaPage, contains('final mfaLoading'));
      expect(mfaPage, contains("'MFA status unavailable'"));
      expect(mfaPage, contains("'MFA status could not be loaded. Try again.'"));
      expect(mfaPage, contains("'Retry'"));
      expect(
        mfaPage,
        contains('auth.isMfaStateAvailable && !hasVerifiedTotp'),
      );
    });

    test('environment badge does not default missing config to LIVE', () {
      expect(topBar, contains("'CONTROL_SITE_ENV_LABEL'"));
      expect(topBar, contains("defaultValue: 'DEV'"));
      expect(topBar, isNot(contains("defaultValue: 'LIVE'")));
    });
  });
}
