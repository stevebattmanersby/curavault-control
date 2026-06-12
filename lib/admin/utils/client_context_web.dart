// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

String? getClientIpAddress() {
  // Browsers don't expose the real client IP to JS/Flutter.
  // If you need it, set it server-side (edge function / reverse proxy).
  return null;
}

String? getClientUserAgent() => html.window.navigator.userAgent;
