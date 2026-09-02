import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImageUtils {
  static Future<String> getOutputPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${directory.path}/panorama_360_$timestamp.png';
  }

  static Future<File> savePng({
    required List<int> bytes,
    required String outputPath,
  }) async {
    final file = File(outputPath);
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<img.Image?> decodeImage(File file) async {
    final bytes = await file.readAsBytes();
    return img.decodeImage(bytes);
  }

  static Future<List<int>> encodePng(img.Image image, {int level = 6}) async {
    return img.encodePng(image, level: level);
  }
}
