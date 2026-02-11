import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageHelper {
  /// Compresses an image file to WebP format with ~85% quality.
  /// Returns the compressed file or the original file if compression fails.
  static Future<File> compressImage(File file) async {
    final filePath = file.absolute.path;
    
    // Create output path with .webp extension
    final lastIndex = filePath.lastIndexOf(RegExp(r'.jp|.png|.bmp|.web'));
    final splitName = filePath.substring(0, (lastIndex));
    final outPath = "${splitName}_compressed.webp";

    try {
      var result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        outPath,
        quality: 85,
        format: CompressFormat.webp,
      );

      if (result != null) {
        return File(result.path);
      } else {
        return file;
      }
    } catch (e) {
      // In case of error (e.g. format not supported), return original file
      return file;
    }
  }
}
