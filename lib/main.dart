import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:curavault_admin/nav.dart';
import 'package:curavault_admin/theme.dart';
import 'package:curavault_admin/admin/auth/admin_auth_store.dart';
import 'package:curavault_admin/admin/state/admin_store.dart';
import 'package:curavault_admin/admin/state/admin_theme_store.dart';
import 'package:curavault_admin/supabase/supabase_config.dart';

/// Main entry point for the application
///
/// This sets up:
/// - go_router navigation
/// - Material 3 theming with light/dark modes
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure Supabase is initialized BEFORE any stores/widgets attempt to access it.
  // We keep --dart-define overrides for production, but provide safe preview fallbacks.
  SupabaseConfig.debugPrintEnvStatus(source: 'main(beforeSupabaseInitialize)');
  await SupabaseConfig.initialize();
  SupabaseConfig.debugPrintEnvStatus(source: 'main(afterSupabaseInitialize)');

  // Temporary diagnostics (prints only true/false flags).
  AdminAuthStore.debugPrintSupabaseBootstrapStatus(source: 'main(afterSupabaseInitialize)');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AdminAuthStore _auth;
  late final AdminStore _adminStore;
  late final AdminThemeStore _themeStore;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _auth = AdminAuthStore()..bootstrap();
    _adminStore = AdminStore(auth: _auth);
    _themeStore = AdminThemeStore();
    _themeStore.bootstrap(auth: _auth);
    _router = AppRouter.createRouter(_auth);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider.value(value: _adminStore),
        ChangeNotifierProvider.value(value: _themeStore),
      ],
      child: Consumer<AdminThemeStore>(
        builder: (context, themeStore, _) {
          final themeData = switch (themeStore.mode) {
            AdminThemeMode.light => lightTheme,
            AdminThemeMode.dark => darkTheme,
            AdminThemeMode.ai => aiTheme,
          };
          return MaterialApp.router(
            title: 'CuraVault Admin',
            debugShowCheckedModeBanner: false,
            theme: themeData,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
