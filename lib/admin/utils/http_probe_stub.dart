import 'dart:io';

import 'package:flutter/foundation.dart';

class HttpProbeResult {
  final bool ok;
  final int? statusCode;
  final String? exceptionType;
  final String? message;

  const HttpProbeResult({required this.ok, this.statusCode, this.exceptionType, this.message});
}

/// Minimal HTTP probe for non-web platforms.
Future<HttpProbeResult> httpProbe(Uri url, {String method = 'HEAD', Map<String, String>? headers}) async {
  final client = HttpClient();
  try {
    final req = await client.openUrl(method, url);
    headers?.forEach((k, v) => req.headers.set(k, v));
    final res = await req.close();
    return HttpProbeResult(ok: true, statusCode: res.statusCode);
  } catch (e) {
    debugPrint('httpProbe($method $url) failed: $e');
    return HttpProbeResult(ok: false, exceptionType: e.runtimeType.toString(), message: e.toString());
  } finally {
    client.close(force: true);
  }
}
