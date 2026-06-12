// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

Future<void> saveTextFileWeb({required String filename, required String contents}) async {
  final bytes = const Utf8Encoder().convert(contents);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final a = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.children.add(a);
  a.click();
  a.remove();
  html.Url.revokeObjectUrl(url);
}
