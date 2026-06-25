import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves a [PlatformFile] to a readable local [File] (handles Android content URIs).
class PickerFileUtil {
  PickerFileUtil._();

  static Future<File> toLocalFile(
    PlatformFile platformFile, {
    String prefix = 'wie_doc',
  }) async {
    if (platformFile.path != null && platformFile.path!.isNotEmpty) {
      final file = File(platformFile.path!);
      if (await file.exists()) return file;
    }

    if (platformFile.bytes != null && platformFile.bytes!.isNotEmpty) {
      final tempDir = await getTemporaryDirectory();
      final ext = (platformFile.extension ?? 'bin').toLowerCase();
      final tempPath = p.join(
        tempDir.path,
        '${prefix}_${DateTime.now().microsecondsSinceEpoch}.$ext',
      );
      final file = File(tempPath);
      await file.writeAsBytes(platformFile.bytes!);
      return file;
    }

    throw StateError('Could not read selected file');
  }
}
