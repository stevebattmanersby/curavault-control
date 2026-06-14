String formatBytes(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  const tb = gb * 1024;
  if (bytes >= tb) return '${(bytes / tb).toStringAsFixed(1)} TB';
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
  return '$bytes B';
}

String formatCompactInt(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  return value.toString();
}

String formatDateTimeShort(DateTime? dt) {
  if (dt == null) return '—';
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}

String formatDateShort(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

class AdminFormatters {
  static String bytes(int bytes) => formatBytes(bytes);
  static String compactInt(int value) => formatCompactInt(value);
  static String date(DateTime dt) => formatDateShort(dt);
  static String dateTime(DateTime? dt) => formatDateTimeShort(dt);

  static String usd(double amount) {
    if (amount == 0) return '—';
    final s = amount.toStringAsFixed(2);
    return '\$$s';
  }

  static String relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 14) return '${diff.inDays}d ago';
    return date(dt);
  }
}

/// Formats an exception into a short, privacy-safe message suitable for admin UI.
///
/// This intentionally avoids printing secrets (keys, bearer tokens) and truncates
/// long messages.
String formatAdminSafeError(Object error, {int maxLen = 240}) {
  var s = error.toString();

  // Redact obvious secret/token-like substrings.
  s = s.replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9\-\._=]+', caseSensitive: false), 'Bearer ***');
  s = s.replaceAll(RegExp(r'(?<=apikey=)[^&\s]+', caseSensitive: false), '***');
  s = s.replaceAll(RegExp(r'sb_[A-Za-z0-9_\-]{12,}', caseSensitive: false), 'sb_***');
  s = s.replaceAll(RegExp(r'eyJ[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}'), 'jwt_***');

  s = s.trim();
  if (s.length > maxLen) s = '${s.substring(0, maxLen)}…';
  return s;
}
