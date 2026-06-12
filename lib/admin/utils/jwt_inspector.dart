import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Tiny helper for inspecting JWT payloads in a privacy-safe way.
///
/// Used only for defensive checks (e.g., ensure a Supabase key isn't a service role).
class JwtInspector {
  static Map<String, dynamic>? tryDecodePayload(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length < 2) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final bytes = base64Url.decode(normalized);
      final jsonStr = utf8.decode(bytes);
      final decoded = json.decode(jsonStr);
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return null;
    } catch (e) {
      debugPrint('JwtInspector.tryDecodePayload failed: $e');
      return null;
    }
  }

  /// Returns the `role` claim if present.
  static String? tryGetRoleClaim(String jwt) {
    final payload = tryDecodePayload(jwt);
    final role = payload?['role'];
    if (role is String && role.isNotEmpty) return role;
    return null;
  }
}
