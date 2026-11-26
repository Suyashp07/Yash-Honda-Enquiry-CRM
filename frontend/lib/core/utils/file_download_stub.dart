import 'dart:typed_data';

void downloadFileBytes(Uint8List bytes, String filename, String mimeType) {
  // No-op on non-web platforms.
}

Future<bool> downloadTextFile(String content, String filename,
    [String mimeType = 'text/csv;charset=utf-8']) async {
  return false;
}
