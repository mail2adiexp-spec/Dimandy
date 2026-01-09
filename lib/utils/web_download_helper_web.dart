import 'dart:html' as html;
import 'dart:typed_data';

void downloadFileWeb(Uint8List bytes, String fileName, String contentType) {
  final blob = html.Blob([bytes], contentType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
