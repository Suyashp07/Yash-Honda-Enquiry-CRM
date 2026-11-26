// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';

void downloadFileBytes(Uint8List bytes, String filename, String mimeType) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

Future<bool> downloadTextFile(String content, String filename,
    [String mimeType = 'text/csv;charset=utf-8']) async {
  downloadFileBytes(Uint8List.fromList(utf8.encode(content)), filename, mimeType);
  return true;
}

void printHtmlDocument(String htmlContent) {
  final blob = html.Blob([htmlContent], 'text/html;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final iframe = html.IFrameElement()
    ..src = url
    ..style.position = 'fixed'
    ..style.right = '0'
    ..style.bottom = '0'
    ..style.width = '0'
    ..style.height = '0'
    ..style.border = 'none';
  html.document.body?.children.add(iframe);
  Future.delayed(const Duration(seconds: 60), () {
    iframe.remove();
    html.Url.revokeObjectUrl(url);
  });
}
