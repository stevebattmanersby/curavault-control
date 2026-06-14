import 'dart:async';

import 'package:curavault_admin/supabase/supabase_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Privacy-safe usage instrumentation.
///
/// Writes best-effort usage events to `public.usage_events`.
///
/// IMPORTANT PRIVACY GUARANTEES
/// - Never store user health content or free-form user text.
/// - Only store coarse, operational metadata.
/// - Any event write failure must never break user flows.
class UsageEventService {
  UsageEventService._();

  static final UsageEventService instance = UsageEventService._();

  static const String _table = 'usage_events';

  /// Explicit denylist of keys that must never appear in `properties`.
  ///
  /// Note: We deny exact keys, plus common variants (case-insensitive), and also
  /// deny any key that contains these tokens as a substring.
  static const List<String> _unsafeKeyTokens = [
    'title',
    'name',
    'notes',
    'file_name',
    'filename',
    'file_path',
    'filepath',
    'medication_name',
    'vaccine_name',
    'blood_pressure_value',
    'bloodpressure',
    'prompt',
    'response',
    'query',
  ];

  /// Tracks a screen view.
  Future<void> trackScreenView(String screenName, {String? featureArea}) async {
    await trackFeatureEvent(
      eventName: 'screen_viewed',
      featureArea: featureArea ?? 'navigation',
      result: 'success',
      properties: {'screen_name': screenName},
    );
  }

  /// Tracks a non-AI feature event.
  Future<void> trackFeatureEvent({
    required String eventName,
    required String featureArea,
    required String result,
    String? errorCode,
    int? durationMs,
    String? country,
    Map<String, Object?>? properties,
  }) async {
    await _writeEvent(
      eventName: eventName,
      featureArea: featureArea,
      result: result,
      errorCode: errorCode,
      durationMs: durationMs,
      country: country,
      properties: properties,
    );
  }

  /// Tracks AI usage without storing prompts/responses.
  Future<void> trackAiUsage({
    required String featureArea,
    required String model,
    int? inputTokens,
    int? outputTokens,
    int? totalTokens,
    double? estimatedCost,
    required String result,
    String? errorCode,
    int? durationMs,
    String? country,
  }) async {
    await _writeEvent(
      eventName: switch (result) {
        'success' => 'ai_request_completed',
        'failure' => 'ai_request_failed',
        _ => 'ai_request_completed',
      },
      featureArea: featureArea,
      result: result,
      errorCode: errorCode,
      durationMs: durationMs,
      country: country,
      properties: {
        'model': model,
        if (inputTokens != null) 'input_tokens': inputTokens,
        if (outputTokens != null) 'output_tokens': outputTokens,
        if (totalTokens != null) 'total_tokens': totalTokens,
        if (estimatedCost != null) 'estimated_cost': estimatedCost,
      },
    );
  }

  /// Primary write method.
  ///
  /// Best-effort: any error is caught and logged (debug only) and never thrown.
  Future<void> _writeEvent({
    required String eventName,
    required String featureArea,
    required String result,
    String? errorCode,
    int? durationMs,
    String? country,
    Map<String, Object?>? properties,
  }) async {
    // Never block flows: do work asynchronously.
    unawaited(_writeEventImpl(
      eventName: eventName,
      featureArea: featureArea,
      result: result,
      errorCode: errorCode,
      durationMs: durationMs,
      country: country,
      properties: properties,
    ));
  }

  Future<void> _writeEventImpl({
    required String eventName,
    required String featureArea,
    required String result,
    String? errorCode,
    int? durationMs,
    String? country,
    Map<String, Object?>? properties,
  }) async {
    try {
      if (!SupabaseConfig.isInitialized) return;
      final client = SupabaseConfig.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) return;

      final safeProps = sanitizeProperties(properties ?? const {});
      if (!validateSafeProperties(safeProps)) {
        debugPrint('[usage_events] blocked unsafe properties for event=$eventName');
        return;
      }

      final payload = <String, Object?>{
        'user_id': userId,
        'event_name': eventName,
        'feature_area': featureArea,
        'platform': _platformLabel,
        'app_version': _appVersionLabel,
        if (country != null && country.trim().isNotEmpty) 'country': country.trim(),
        'result': result,
        if (errorCode != null && errorCode.trim().isNotEmpty) 'error_code': errorCode.trim(),
        if (durationMs != null) 'duration_ms': durationMs,
        'properties': safeProps,
        // created_at should be generated server-side, but we allow the column to
        // default if present. We intentionally do not set it here.
      };

      await client.from(_table).insert(payload);
    } catch (e) {
      // Never throw; do not log payloads.
      if (kDebugMode) debugPrint('[usage_events] write failed: $e');
    }
  }

  static String get _platformLabel {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      _ => 'unknown',
    };
  }

  static String get _appVersionLabel {
    // No extra dependency: allow CI/build to provide this.
    const fromEnv = String.fromEnvironment('APP_VERSION', defaultValue: '');
    if (fromEnv.trim().isNotEmpty) return fromEnv.trim();
    // Fallback: pubspec version is not available at runtime without a package.
    return 'unknown';
  }

  /// Removes nulls and enforces JSON-encodable primitive-ish types.
  ///
  /// NOTE: We intentionally do NOT accept nested structures besides simple maps/lists.
  /// If a nested value is complex, it is dropped.
  @visibleForTesting
  static Map<String, Object?> sanitizeProperties(Map<String, Object?> input) {
    final out = <String, Object?>{};
    for (final entry in input.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;
      final value = entry.value;
      if (value == null) continue;

      if (value is String || value is num || value is bool) {
        out[key] = value;
      } else if (value is List) {
        final safe = value.where((e) => e == null || e is String || e is num || e is bool).toList(growable: false);
        out[key] = safe;
      } else if (value is Map) {
        // Allow one-level map of primitives only.
        final safeMap = <String, Object?>{};
        for (final e in value.entries) {
          if (e.key is! String) continue;
          final k = (e.key as String).trim();
          final v = e.value;
          if (k.isEmpty || v == null) continue;
          if (v is String || v is num || v is bool) safeMap[k] = v;
        }
        out[key] = safeMap;
      }
    }
    return out;
  }

  @visibleForTesting
  static bool validateSafeProperties(Map<String, Object?> properties) {
    for (final key in properties.keys) {
      final k = key.toLowerCase();
      for (final token in _unsafeKeyTokens) {
        if (k == token || k.contains(token)) {
          assert(() {
            throw FlutterError(
              'Unsafe usage_event properties key detected: "$key". '
              'Do not send PHI / user health content in usage events.',
            );
          }());
          return false;
        }
      }
    }

    // Basic value-based guard for common leakage patterns: if someone tries to put
    // huge text blobs in a "safe" key.
    for (final entry in properties.entries) {
      final v = entry.value;
      if (v is String && v.length > 500) {
        assert(() {
          throw FlutterError(
            'Usage event property "${entry.key}" is too large (${v.length} chars). '
            'Do not include free-form user text.',
          );
        }());
        return false;
      }
    }
    return true;
  }
}

/// Navigator observer that emits `screen_viewed` events.
///
/// Designed for go_router: pass this in `GoRouter(observers: [...])`.
class UsageNavigationObserver extends NavigatorObserver {
  UsageNavigationObserver({UsageEventService? service}) : _service = service ?? UsageEventService.instance;

  final UsageEventService _service;

  void _emit(Route<dynamic>? route) {
    if (route == null) return;
    final name = route.settings.name;
    final args = route.settings.arguments;
    final label = (name != null && name.trim().isNotEmpty)
        ? name
        : (args is String && args.trim().isNotEmpty)
            ? args
            : route.runtimeType.toString();
    _service.trackScreenView(label);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _emit(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _emit(newRoute);
  }
}
