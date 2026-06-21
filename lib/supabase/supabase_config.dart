import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase configuration for this project.
///
/// SECURITY:
/// - Uses environment variables only (no secrets in source control).
/// - Fails closed if a service role key is ever bundled into the client build.
class SupabaseConfig {
  /// Base URL where the Control Site is hosted (e.g. https://admin.curavault.com).
  ///
  /// Provided at build time via `--dart-define=CONTROL_SITE_BASE_URL=...`.
  ///
  /// For local/preview Flutter Web builds, Dreamflow may not inject dart-defines.
  /// In that case (debug-mode only), we allow providing the values via URL query
  /// params to unblock preview:
  /// - `?SUPABASE_URL=...&SUPABASE_ANON_KEY=...&CONTROL_SITE_BASE_URL=...`
  static const String controlSiteBaseUrl = String.fromEnvironment('CONTROL_SITE_BASE_URL', defaultValue: '');

  /// The Auth Site URL configured in Supabase.
  ///
  /// This is used for email links (password reset / magic link redirects).
  static String get authSiteUrl => _stripTrailingSlash(_resolveControlSiteBaseUrl());

  /// Redirect URL used for password recovery.
  ///
  /// IMPORTANT (Flutter Web + hash routing): `redirectTo` must be an absolute URL
  /// that includes the SPA hash fragment (/#/...).
  static String get setPasswordRedirectUrl => '${_stripTrailingSlash(_resolveControlSiteBaseUrl())}/#/set-password';

  /// Supabase project URL.
  ///
  /// Provided at build time via:
  /// - `--dart-define=SUPABASE_URL=...`
  ///
  /// For Flutter Web this must be passed at build time; it cannot be supplied at
  /// runtime via server environment variables.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Supabase anon key.
  ///
  /// Provided at build time via:
  /// - `--dart-define=SUPABASE_ANON_KEY=...`
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// This should NEVER be set in a frontend build.
  static const String serviceRoleKey = String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY', defaultValue: '');

  /// Whether a service-role key was bundled into this client build.
  ///
  /// This should always be false for Flutter apps.
  static bool get serviceRoleDetected => serviceRoleKey.isNotEmpty;

  static bool _initialized = false;

  static String? _runtimeSupabaseUrl;
  static String? _runtimeAnonKey;
  static String? _runtimeControlSiteBaseUrl;

  static bool _runtimeJsonLoaded = false;

  /// Whether `SupabaseConfig.initialize()` has successfully initialized the
  /// Supabase client in this process.
  static bool get isInitialized => _initialized;

  /// Debug-only environment diagnostics (true/false only; never prints values).
  static void debugPrintEnvStatus({String source = 'SupabaseConfig'}) {
    if (!kDebugMode) return;
    final resolvedUrl = _resolveSupabaseUrl();
    final resolvedAnon = _resolveAnonKey();
    final resolvedBaseUrl = _resolveControlSiteBaseUrl();
    final hasUrl = resolvedUrl.isNotEmpty;
    final hasAnon = resolvedAnon.isNotEmpty;
    final hasBaseUrl = resolvedBaseUrl.isNotEmpty;
    final serviceRoleDetected = serviceRoleKey.isNotEmpty;
    bool instanceClientAvailable;
    try {
      // Accessing `Supabase.instance.client` throws if not initialized.
      Supabase.instance.client;
      instanceClientAvailable = true;
    } catch (_) {
      instanceClientAvailable = false;
    }
    debugPrint(
      '[$source] Supabase env status: '
      'clientAvailable=$instanceClientAvailable '
      'supabaseConfigInitialized=$_initialized '
      'hasSUPABASE_URL=$hasUrl '
      'hasSUPABASE_ANON_KEY=$hasAnon '
      'hasCONTROL_SITE_BASE_URL=$hasBaseUrl '
      'serviceRoleDetected=$serviceRoleDetected',
    );
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    debugPrintEnvStatus(source: 'SupabaseConfig.initialize(before)');

    // Resolve runtime config in the required precedence order:
    // 1) dart-defines
    // 2) runtime public JSON (allowed in release)
    // 3) debug web query params only
    await _primeRuntimeConfigFromAssetJsonIfNeeded();
    _primeRuntimeConfigFromQueryParamsIfNeeded();

    final resolvedUrl = _resolveSupabaseUrl();
    final resolvedAnon = _resolveAnonKey();

    if (resolvedUrl.isEmpty || resolvedAnon.isEmpty) {
      debugPrint('Supabase not configured (missing SUPABASE_URL / SUPABASE_ANON_KEY).');
      return;
    }

    // Sanity check: Supabase.initialize expects the project root URL, not /rest/v1.
    if (kDebugMode && resolvedUrl.contains('/rest/v1')) {
      debugPrint('CONFIG WARNING:  contains /rest/v1. It should be the project root like https://xxxx.supabase.co');
    }

    // This should NEVER be set in a frontend build.
    if (serviceRoleKey.isNotEmpty) {
      debugPrint('SECURITY: SUPABASE_SERVICE_ROLE_KEY detected; refusing to initialize Supabase client.');
      return;
    }

    try {
      await Supabase.initialize(url: resolvedUrl, anonKey: resolvedAnon, debug: kDebugMode);
      _initialized = true;
      debugPrintEnvStatus(source: 'SupabaseConfig.initialize(after)');
    } catch (e) {
      debugPrint('Supabase.initialize failed: $e');
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;

  static String _stripTrailingSlash(String input) {
    if (input.isEmpty) return '';
    return input.endsWith('/') ? input.substring(0, input.length - 1) : input;
  }

  // Resolution order (highest → lowest):
  // 1) Dart defines
  // 2) Public runtime JSON asset
  // 3) Debug-only web query params
  // 4) Fail closed
  static String _resolveSupabaseUrl() => supabaseUrl.trim().isNotEmpty ? supabaseUrl : (_runtimeSupabaseUrl ?? '');
  static String _resolveAnonKey() => anonKey.trim().isNotEmpty ? anonKey : (_runtimeAnonKey ?? '');
  static String _resolveControlSiteBaseUrl() =>
      controlSiteBaseUrl.trim().isNotEmpty ? controlSiteBaseUrl : (_runtimeControlSiteBaseUrl ?? '');

  static Future<void> _primeRuntimeConfigFromAssetJsonIfNeeded() async {
    // Asset JSON is a release-safe way to supply public runtime configuration.
    // We only use it if dart-defines are missing (dart-defines always win).
    if (_runtimeJsonLoaded) return;
    _runtimeJsonLoaded = true;

    final needsUrl = supabaseUrl.trim().isEmpty;
    final needsAnon = anonKey.trim().isEmpty;
    final needsBase = controlSiteBaseUrl.trim().isEmpty;
    if (!needsUrl && !needsAnon && !needsBase) return;

    try {
      final raw = await rootBundle.loadString('assets/config/control_site_config.json');
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;

      final url = (decoded['SUPABASE_URL'] as String?)?.trim();
      final anon = (decoded['SUPABASE_ANON_KEY'] as String?)?.trim();
      final base = (decoded['CONTROL_SITE_BASE_URL'] as String?)?.trim();

      if (kDebugMode) {
        debugPrint(
          '[SupabaseConfig] Runtime JSON loaded. '
          'hasUrl=${url != null && url.isNotEmpty} '
          'hasAnon=${anon != null && anon.isNotEmpty && !anon.startsWith('<')} '
          'hasBase=${base != null && base.isNotEmpty}',
        );
      }

      if (needsUrl && url != null && _looksLikeHttpsUrl(url) && _looksLikeSupabaseProjectUrl(url)) {
        _runtimeSupabaseUrl = url;
      }
      // We intentionally require a JWT-like token to avoid accidentally accepting
      // placeholders or other invalid values.
      if (needsAnon && anon != null && anon.isNotEmpty && !anon.startsWith('<') && _looksLikeJwt(anon) && !_looksLikeServiceRoleJwt(anon)) {
        _runtimeAnonKey = anon;
      }
      if (needsBase && base != null && _looksLikeHttpsUrl(base)) {
        _runtimeControlSiteBaseUrl = base;
      }
    } catch (e) {
      // Missing asset or invalid JSON should not crash the app.
      debugPrint('Failed to load assets/config/control_site_config.json: $e');
    }
  }

  static void _primeRuntimeConfigFromQueryParamsIfNeeded() {
    // Debug-only web escape hatch. Lowest priority by design.
    if (!kDebugMode) return;
    if (!kIsWeb) return;

    // Only use query params for any values still missing after dart-defines + asset JSON.
    final needsUrl = _resolveSupabaseUrl().trim().isEmpty;
    final needsAnon = _resolveAnonKey().trim().isEmpty;
    final needsBase = _resolveControlSiteBaseUrl().trim().isEmpty;
    if (!needsUrl && !needsAnon && !needsBase) return;

    try {
      final qp = Uri.base.queryParameters;
      final qpUrl = qp['SUPABASE_URL']?.trim();
      final qpAnon = qp['SUPABASE_ANON_KEY']?.trim();
      final qpBase = qp['CONTROL_SITE_BASE_URL']?.trim();

      if (needsUrl && qpUrl != null && qpUrl.isNotEmpty && _looksLikeHttpsUrl(qpUrl) && _looksLikeSupabaseProjectUrl(qpUrl)) {
        _runtimeSupabaseUrl = qpUrl;
      }
      if (needsAnon && qpAnon != null && qpAnon.isNotEmpty && _looksLikeJwt(qpAnon) && !_looksLikeServiceRoleJwt(qpAnon)) {
        _runtimeAnonKey = qpAnon;
      }
      if (needsBase && qpBase != null && qpBase.isNotEmpty && _looksLikeHttpsUrl(qpBase)) {
        _runtimeControlSiteBaseUrl = qpBase;
      }
    } catch (e) {
      debugPrint('Failed to read runtime Supabase config from URL query params: $e');
    }
  }

  static bool _looksLikeHttpsUrl(String url) {
    try {
      final u = Uri.parse(url);
      return u.hasScheme && u.scheme == 'https' && u.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static bool _looksLikeSupabaseProjectUrl(String url) {
    // Keep this intentionally permissive, but exclude obvious REST endpoints.
    if (url.contains('/rest/v1')) return false;
    return url.contains('.supabase.co');
  }

  static bool _looksLikeJwt(String token) {
    final parts = token.split('.');
    return parts.length == 3 && parts.every((p) => p.isNotEmpty);
  }

  static bool _looksLikeServiceRoleJwt(String token) {
    // Best-effort guardrail: decode payload and detect role=service_role.
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final bytes = base64Url.decode(normalized);
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map) return false;
      final role = json['role'];
      return role == 'service_role';
    } catch (_) {
      return false;
    }
  }
}

/// Generic database service for CRUD operations
class SupabaseService {
  /// Select multiple records from a table
  static Future<List<Map<String, dynamic>>> select(
    String table, {
    String? select,
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = true,
    int? limit,
  }) async {
    try {
      dynamic query = SupabaseConfig.client.from(table).select(select ?? '*');

      // Apply filters
      if (filters != null) {
        for (final entry in filters.entries) {
          query = query.eq(entry.key, entry.value);
        }
      }

      // Apply ordering
      if (orderBy != null) {
        query = query.order(orderBy, ascending: ascending);
      }

      // Apply limit
      if (limit != null) {
        query = query.limit(limit);
      }

      return await query;
    } catch (e) {
      throw _handleDatabaseError('select', table, e);
    }
  }

  /// Select a single record from a table
  static Future<Map<String, dynamic>?> selectSingle(
    String table, {
    String? select,
    required Map<String, dynamic> filters,
  }) async {
    try {
      dynamic query = SupabaseConfig.client.from(table).select(select ?? '*');

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      return await query.maybeSingle();
    } catch (e) {
      throw _handleDatabaseError('selectSingle', table, e);
    }
  }

  /// Insert a record into a table
  static Future<List<Map<String, dynamic>>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    try {
      return await SupabaseConfig.client.from(table).insert(data).select();
    } catch (e) {
      throw _handleDatabaseError('insert', table, e);
    }
  }

  /// Insert multiple records into a table
  static Future<List<Map<String, dynamic>>> insertMultiple(
    String table,
    List<Map<String, dynamic>> data,
  ) async {
    try {
      return await SupabaseConfig.client.from(table).insert(data).select();
    } catch (e) {
      throw _handleDatabaseError('insertMultiple', table, e);
    }
  }

  /// Update records in a table
  static Future<List<Map<String, dynamic>>> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> filters,
  }) async {
    try {
      dynamic query = SupabaseConfig.client.from(table).update(data);

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      return await query.select();
    } catch (e) {
      throw _handleDatabaseError('update', table, e);
    }
  }

  /// Delete records from a table
  static Future<void> delete(
    String table, {
    required Map<String, dynamic> filters,
  }) async {
    try {
      dynamic query = SupabaseConfig.client.from(table).delete();

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      await query;
    } catch (e) {
      throw _handleDatabaseError('delete', table, e);
    }
  }

  /// Get direct table reference for complex queries
  static SupabaseQueryBuilder from(String table) =>
      SupabaseConfig.client.from(table);

  /// Handle database errors
  static Exception _handleDatabaseError(
    String operation,
    String table,
    dynamic error,
  ) {
    if (error is PostgrestException) {
      return Exception('Failed to $operation on $table: ${error.message}');
    }

    return Exception('Failed to $operation on $table: ${error.toString()}');
  }
}
