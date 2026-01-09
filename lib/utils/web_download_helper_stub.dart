import 'dart:typed_data';

void downloadFileWeb(Uint8List bytes, String fileName, String contentType) {
  // No-op on non-web platforms as they should use dart:io
  print('Attempted to use web download on non-web platform');
}
