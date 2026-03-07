import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';

class StorageService {
  final http.Client _client;

  StorageService({http.Client? client}) : _client = client ?? http.Client();

  /// Uploads an issue photo to ImgBB and returns the direct image URL.
  Future<String> uploadIssuePhoto(File file) async {
    File fileToUpload = file;

    try {
      final compressed = await _compressImage(file);
      if (compressed != null) {
        fileToUpload = compressed;
      }
    } catch (e) {
      // Ignore compression errors and continue with the original file
    }

    final bytes = await fileToUpload.readAsBytes();
    final base64Image = base64Encode(bytes);

    final uri = Uri.parse('https://api.imgbb.com/1/upload');
    final response = await _client.post(
      uri,
      body: {'key': AppConfig.imgBbApiKey, 'image': base64Image},
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded['data']['url'] as String;
    } else {
      throw Exception(
        'Failed to upload image to ImgBB: ${response.statusCode} - ${response.body}',
      );
    }
  }

  Future<File?> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = p.join(
      tempDir.path,
      '${const Uuid().v4()}_compressed.jpg',
    );

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70,
    );

    if (result == null) return null;
    return File(result.path);
  }
}
