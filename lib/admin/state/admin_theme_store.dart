import 'dart:async';

import 'package:curavault_admin/admin/auth/admin_auth_store.dart';
import 'package:curavault_admin/admin/data/supabase/supabase_admin_queries.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls the visual theme for the CuraVault Control Site.
///
/// Requirements:
/// - 3 selectable modes: Light / Dark / AI
/// - Persist locally
/// - Best-effort persist to admin profile (when available)
/// - Fail-safe: local preference always wins
class AdminThemeStore extends ChangeNotifier {
  static const _prefsKey = 'curavault_admin_theme_mode_v1';

  AdminThemeMode _mode = AdminThemeMode.light;
  AdminThemeMode get mode => _mode;

  bool _loadedFromPrefs = false;
  bool get hasLoadedFromPrefs => _loadedFromPrefs;

  AdminAuthStore? _auth;
  late final SupabaseAdminQueries _queries;

  AdminThemeStore({SupabaseAdminQueries? queries}) : _queries = queries ?? SupabaseAdminQueries();

  Future<void> bootstrap({required AdminAuthStore auth}) async {
    _auth = auth;
    auth.addListener(_onAuthChanged);
    await _loadLocal();
    unawaited(_tryAdoptRemotePreferenceIfNoLocalOverride());
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    // When an admin becomes authorized, we can attempt to fetch remote preference.
    if (_auth?.isAuthorized == true) {
      unawaited(_tryAdoptRemotePreferenceIfNoLocalOverride());
    }
  }

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      _lastPersistedLocal = raw;
      if (raw != null && raw.trim().isNotEmpty) {
        _mode = AdminThemeMode.parse(raw);
      }
    } catch (e) {
      debugPrint('AdminThemeStore._loadLocal failed: $e');
    } finally {
      _loadedFromPrefs = true;
      notifyListeners();
    }
  }

  bool get _hasLocalOverride {
    // If prefs loaded and a value exists, treat it as local override.
    // We can't reliably differentiate default vs not-set without storing
    // a sentinel, so we use the presence of the pref key.
    // (See _persistLocal for key write.)
    return _loadedFromPrefs && _lastPersistedLocal != null;
  }

  String? _lastPersistedLocal;

  Future<void> _persistLocal(AdminThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
      _lastPersistedLocal = mode.name;
    } catch (e) {
      debugPrint('AdminThemeStore._persistLocal failed: $e');
    }
  }

  Future<void> setMode(AdminThemeMode mode, {bool persist = true}) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    if (persist) {
      await _persistLocal(mode);
      unawaited(_tryPersistRemote(mode));
    }
  }

  Future<void> cycleMode() async {
    final next = switch (_mode) {
      AdminThemeMode.light => AdminThemeMode.dark,
      AdminThemeMode.dark => AdminThemeMode.ai,
      AdminThemeMode.ai => AdminThemeMode.light,
    };
    await setMode(next);
  }

  Future<void> _tryAdoptRemotePreferenceIfNoLocalOverride() async {
    if (_auth?.isAuthorized != true) return;
    if (!_loadedFromPrefs) return;
    if (_hasLocalOverride) return;

    try {
      final admin = await _queries.getCurrentAdminUser();
      final raw = admin.themePreference;
      if (raw == null || raw.trim().isEmpty) return;
      final remote = AdminThemeMode.parse(raw);
      if (_mode != remote) {
        _mode = remote;
        notifyListeners();
      }
    } catch (e) {
      // Best-effort only.
      debugPrint('AdminThemeStore remote adopt failed: $e');
    }
  }

  Future<void> _tryPersistRemote(AdminThemeMode mode) async {
    if (_auth?.isAuthorized != true) return;
    try {
      await _queries.setAdminThemePreference(themePreference: mode.name);
    } catch (e) {
      debugPrint('AdminThemeStore remote persist failed: $e');
    }
  }
}
