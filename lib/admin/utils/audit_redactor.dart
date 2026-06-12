import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Best-effort redaction for audit logs.
///
/// Audit logs must never store health content (notes, record values, document
/// names, AI prompts/responses, etc.). This utility:
/// - Truncates very long strings
/// - Redacts values under sensitive keys
/// - Redacts nested maps/lists recursively
class AdminAuditRedactor {
  static const String redacted = '[REDACTED]';

  static const Set<String> _sensitiveKeys = {
    'health',
    'medical',
    'record',
    'records',
    'note',
    'notes',
    'content',
    'text',
    'value',
    'values',
    'prompt',
    'response',
    'messages',
    'document',
    'document_name',
    'file_name',
    'filename',
    'title',
    'body',
    'summary',
  };

  static Map<String, dynamic>? redactMap(Map<String, dynamic>? input) {
    if (input == null) return null;
    try {
      final out = <String, dynamic>{};
      for (final e in input.entries) {
        out[e.key] = _redactAny(e.key, e.value);
      }
      return out;
    } catch (e) {
      debugPrint('AdminAuditRedactor.redactMap failed: $e');
      return {'_redacted': true};
    }
  }

  static dynamic _redactAny(String key, dynamic value) {
    final k = key.toLowerCase();
    if (_sensitiveKeys.contains(k) || k.contains('health') || k.contains('prompt') || k.contains('response')) return redacted;

    if (value == null) return null;
    if (value is num || value is bool) return value;
    if (value is DateTime) return value.toIso8601String();
    if (value is String) return _sanitizeString(value);
    if (value is List) return value.map((v) => _redactAny(key, v)).toList(growable: false);
    if (value is Map) {
      return value.map((k2, v2) => MapEntry(k2.toString(), _redactAny(k2.toString(), v2)));
    }
    return _sanitizeString(value.toString());
  }

  static String _sanitizeString(String v) {
    final s = v.trim();
    if (s.isEmpty) return s;
    // If someone tries to stuff JSON with sensitive keys into a string, redact.
    if (s.length > 1000) return redacted;
    if (s.toLowerCase().contains('diagnosis') || s.toLowerCase().contains('symptom')) return redacted;
    if (s.length > 200) return '${s.substring(0, 200)}…';
    return s;
  }

  static String jsonStringOrNull(Map<String, dynamic>? v) {
    if (v == null) return '';
    try {
      return const JsonEncoder.withIndent('  ').convert(v);
    } catch (_) {
      return v.toString();
    }
  }
}
