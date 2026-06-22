import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Compresses field/document photos to ~40KB JPEG before upload.
class ImageCompression {
  ImageCompression._();

  static const int targetBytes = 40 * 1024;
  static const int maxDimension = 1280;
  static const int minQuality = 28;

  static bool isImagePath(String path) {
    final ext = p.extension(path).toLowerCase();
    return ext == '.jpg' ||
        ext == '.jpeg' ||
        ext == '.png' ||
        ext == '.heic' ||
        ext == '.heif' ||
        ext == '.webp';
  }

  /// Compress [file] to JPEG near [targetBytes]. Returns original if not an image.
  static Future<File> compressPhotoFile(File file) async {
    if (!await file.exists() || !isImagePath(file.path)) {
      return file;
    }

    try {
      final originalSize = await file.length();
      if (originalSize <= targetBytes) {
        return await _reencodeIfNeeded(file);
      }

      final tempDir = await getTemporaryDirectory();
      var quality = 88;
      var maxDim = maxDimension;
      File? smallest;

      for (var pass = 0; pass < 14; pass++) {
        final outPath = p.join(
          tempDir.path,
          'wie_photo_${DateTime.now().microsecondsSinceEpoch}_$pass.jpg',
        );
        final compressed = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path,
          outPath,
          quality: quality,
          minWidth: maxDim,
          minHeight: maxDim,
          format: CompressFormat.jpeg,
          keepExif: false,
        );
        if (compressed == null) break;

        final out = File(compressed.path);
        final size = await out.length();
        if (smallest == null || size < (await smallest!.length())) {
          smallest = out;
        }
        if (size <= targetBytes) {
          debugPrint(
            'ImageCompression: ${(originalSize / 1024).toStringAsFixed(1)}KB → '
            '${(size / 1024).toStringAsFixed(1)}KB (q=$quality, max=$maxDim)',
          );
          return out;
        }

        if (quality > minQuality) {
          quality -= 8;
        } else if (maxDim > 720) {
          maxDim = (maxDim * 0.75).round();
          quality = 88;
        } else {
          break;
        }
      }

      if (smallest != null) {
        final size = await smallest.length();
        debugPrint(
          'ImageCompression: best effort ${(originalSize / 1024).toStringAsFixed(1)}KB → '
          '${(size / 1024).toStringAsFixed(1)}KB',
        );
        return smallest;
      }
    } catch (e, st) {
      debugPrint('ImageCompression failed: $e\n$st');
    }

    return file;
  }

  static Future<File> compressXFile(XFile xFile) {
    return compressPhotoFile(File(xFile.path));
  }

  /// Multipart file ready for upload (compressed JPEG).
  static Future<http.MultipartFile> multipartPhoto({
    required File file,
    required String field,
    String filename = 'photo.jpg',
  }) async {
    final compressed = await compressPhotoFile(file);
    final bytes = await compressed.readAsBytes();
    return http.MultipartFile.fromBytes(
      field,
      bytes,
      filename: filename,
    );
  }

  static Future<File> _reencodeIfNeeded(File file) async {
    final ext = p.extension(file.path).toLowerCase();
    if (ext == '.jpg' || ext == '.jpeg') {
      return file;
    }
    final tempDir = await getTemporaryDirectory();
    final outPath = p.join(
      tempDir.path,
      'wie_photo_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    final compressed = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      outPath,
      quality: 85,
      minWidth: maxDimension,
      minHeight: maxDimension,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    return compressed != null ? File(compressed.path) : file;
  }
}
