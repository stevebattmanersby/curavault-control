import 'package:flutter/foundation.dart';

import 'client_context_stub.dart'
    if (dart.library.html) 'client_context_web.dart';

/// Lightweight client context for audit logging.
///
/// - On web: best-effort IP (may be null) + user agent.
/// - On mobile: user agent is null (unless you add a package).
class AdminClientContext {
  static String? get ipAddress => getClientIpAddress();
  static String? get userAgent => getClientUserAgent();

  static Map<String, dynamic> asJson() => {
    if (ipAddress != null) 'ip_address': ipAddress,
    if (userAgent != null) 'user_agent': userAgent,
    'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
  };
}
