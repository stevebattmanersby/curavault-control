// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

import 'package:curavault_admin/admin/utils/http_probe_stub.dart';
import 'package:flutter/foundation.dart';

/// Minimal HTTP probe for Flutter Web.
///
/// Uses `dart:html` directly to avoid adding dependencies.
Future<HttpProbeResult> httpProbe(Uri url, {String method = 'HEAD'}) async {
  try {
    final res = await html.HttpRequest.request(
      url.toString(),
      method: method,
      // Don't send cookies. Supabase APIs are bearer-token based.
      withCredentials: false,
    );
    return HttpProbeResult(ok: true, statusCode: res.status);
  } catch (e) {
    // Common in sandboxed/blocked contexts: "ClientException: Failed to fetch".
    debugPrint('httpProbe($method $url) failed: $e');
    return HttpProbeResult(ok: false, exceptionType: e.runtimeType.toString(), message: e.toString());
  }
}
