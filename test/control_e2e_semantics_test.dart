import 'dart:ui' show SemanticsAction;

import 'package:curavault_admin/admin/auth/admin_auth_store.dart';
import 'package:curavault_admin/admin/pages/admin_shell.dart';
import 'package:curavault_admin/admin/pages/login_page.dart';
import 'package:curavault_admin/admin/state/admin_theme_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _SyntheticAuth extends AdminAuthStore {
  int signOutCalls = 0;

  @override
  Future<void> signOut() async => signOutCalls++;

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    throw AdminAccessDeniedException('Access denied.');
  }
}

void main() {
  testWidgets('identified logout remains an accessible, actionable button',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final semantics = tester.ensureSemantics();
    try {
      final auth = _SyntheticAuth();
      addTearDown(auth.dispose);
      final theme = AdminThemeStore();
      addTearDown(theme.dispose);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AdminAuthStore>.value(value: auth),
          ChangeNotifierProvider<AdminThemeStore>.value(value: theme),
        ],
        child: MaterialApp(
          home: AdminShell(
            currentLocation: '/settings',
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => const Center(child: Text('Synthetic route')),
              ),
            ),
          ),
        ),
      ));
      final button = find.byWidgetPredicate((widget) =>
          widget is Semantics &&
          widget.properties.identifier == 'control-logout');
      final data = tester.getSemantics(button).getSemanticsData();
      expect(data.label, 'Logout');
      expect(data.identifier, 'control-logout');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      await tester.tap(button);
      await tester.pump();
      expect(auth.signOutCalls, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('denied sign-in exposes the actual error through semantics',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final semantics = tester.ensureSemantics();
    try {
      final auth = _SyntheticAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(ChangeNotifierProvider<AdminAuthStore>.value(
        value: auth,
        child: const MaterialApp(home: LoginPage()),
      ));
      await tester.enterText(
          find.byType(TextFormField).at(0), 'control-e2e-unit@example.invalid');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'Synthetic-local-only-123!');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      final error = find.byWidgetPredicate((widget) =>
          widget is Semantics &&
          widget.properties.identifier == 'control-login-error');
      expect(tester.getSemantics(error).getSemanticsData().label,
          'Access denied.');
    } finally {
      semantics.dispose();
    }
  });
}
