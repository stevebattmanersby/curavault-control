import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'file_saver_stub.dart' if (dart.library.html) 'file_saver_web.dart';

class AdminFileSaver {
  /// Saves a text file.
  ///
  /// Web: triggers download.
  /// Non-web: copies to clipboard as a fallback.
  static Future<void> saveTextFile({required String filename, required String contents}) async {
    if (kIsWeb) {
      await saveTextFileWeb(filename: filename, contents: contents);
      return;
    }
    await Clipboard.setData(ClipboardData(text: contents));
  }
}
