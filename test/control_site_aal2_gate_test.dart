import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Control Site AAL2 gate', () {
    late final String authStore;
    late final String nav;
    late final String setPasswordPage;
    late final String mfaPage;

    setUpAll(() {
      authStore =
          File('lib/admin/auth/admin_auth_store.dart').readAsStringSync();
      nav = File('lib/nav.dart').readAsStringSync();
      setPasswordPage =
          File('lib/admin/pages/set_password_page.dart').readAsStringSync();
      mfaPage = File('lib/admin/pages/mfa_page.dart').readAsStringSync();
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
  });
}
