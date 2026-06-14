import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase configuration for this project.
///
/// SECURITY:
/// - Uses environment variables only (no secrets in source control).
/// - Fails closed if a service role key is ever bundled into the client build.
class SupabaseConfig {
  /// The Auth Site URL configured in Supabase.
  ///
  /// This is used for email links (password reset / magic link redirects).
  static const String authSiteUrl = 'https://xh23x34884agk2qv1p4a.share.dreamflow.app';

  /// Redirect URL used for password recovery.
  ///
  /// IMPORTANT (Flutter Web + hash routing): We use `/#/reset-password` to land
  /// inside the SPA and then parse the recovery session details from the URL.
  ///
  /// NOTE: For this control site we unify invite + recovery into a single
  /// password setup screen.
  static const String setPasswordRedirectUrl = 'https://xh23x34884agk2qv1p4a.share.dreamflow.app/#/set-password';

  /// Supabase project URL.
  ///
  /// Provided at build time via:
  /// - `--dart-define==...`
  ///
  /// For Flutter Web this must be passed at build time; it cannot be supplied at
  /// runtime via server environment variables.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    // Preview fallback (can be overridden by --dart-define in production)
    defaultValue: 'https://rzqgxtizragjhenmjykq.supabase.co',
  );

  /// Supabase anon key.
  ///
  /// Provided at build time via:
  /// - `--dart-define==...`
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    // Preview fallback (public publishable anon key). Override with --dart-define in production.
    defaultValue: 'sb_publishable_YwSkLV_EOM2DlvosS8GChQ_OMnzR-GD',
  );

  /// This should NEVER be set in a frontend build.
  static const String serviceRoleKey = String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY', defaultValue: '');

  /// Whether a service-role key was bundled into this client build.
  ///
  /// This should always be false for Flutter apps.
  static bool get serviceRoleDetected => serviceRoleKey.isNotEmpty;

  static bool _initialized = false;

  /// Whether `SupabaseConfig.initialize()` has successfully initialized the
  /// Supabase client in this process.
  static bool get isInitialized => _initialized;

  /// Debug-only environment diagnostics (true/false only; never prints values).
  static void debugPrintEnvStatus({String source = 'SupabaseConfig'}) {
    if (!kDebugMode) return;
    final hasUrl = supabaseUrl.isNotEmpty;
    final hasAnon = anonKey.isNotEmpty;
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
      'has=$hasUrl '
      'has=$hasAnon '
      'serviceRoleDetected=$serviceRoleDetected',
    );
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    debugPrintEnvStatus(source: 'SupabaseConfig.initialize(before)');

    if (supabaseUrl.isEmpty || anonKey.isEmpty) {
      debugPrint('Supabase not configured (missing  / ).');
      return;
    }

    // Sanity check: Supabase.initialize expects the project root URL, not /rest/v1.
    if (kDebugMode && supabaseUrl.contains('/rest/v1')) {
      debugPrint('CONFIG WARNING:  contains /rest/v1. It should be the project root like https://xxxx.supabase.co');
    }

    // This should NEVER be set in a frontend build.
    if (serviceRoleKey.isNotEmpty) {
      debugPrint('SECURITY: SUPABASE_SERVICE_ROLE_KEY detected; refusing to initialize Supabase client.');
      return;
    }

    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: anonKey, debug: kDebugMode);
      _initialized = true;
      debugPrintEnvStatus(source: 'SupabaseConfig.initialize(after)');
    } catch (e) {
      debugPrint('Supabase.initialize failed: $e');
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
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
