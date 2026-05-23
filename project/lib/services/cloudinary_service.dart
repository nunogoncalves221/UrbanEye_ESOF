// Cloudinary Service
//
// Handles image uploads to Cloudinary using signed requests.
// Provides secure upload and delete operations for report photos.

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../config/cloudinary_config.dart';

abstract class CloudinaryServiceBase {
  const CloudinaryServiceBase();
  Future<String?> uploadPhoto(File photo, String reportId);
  Future<void> deletePhoto(String publicId);
}

class CloudinaryService extends CloudinaryServiceBase {
  const CloudinaryService();

  // ─── Signature Generation ───────────────────────────────────

  String generateSignature(Map<String, String> params) {
    final sortedParams = params.keys.toList()..sort();
    final toSign = sortedParams.map((k) => '$k=${params[k]}').join('&');
    final signature = sha1.convert(utf8.encode(toSign + CloudinaryConfig.apiSecret));
    return signature.toString();
  }

  String getTimestamp() {
    return DateTime.now().toUtc().millisecondsSinceEpoch.toString();
  }

  // ─── Upload ──────────────────────────────────────────────────

  @override
  Future<String?> uploadPhoto(File photo, String reportId) async {
    try {
      if (!await photo.exists()) {
        throw Exception('Photo file does not exist');
      }

      final timestamp = getTimestamp();
      final params = {
        'folder': 'reports/$reportId',
        'timestamp': timestamp,
      };

      final signature = generateSignature(params);

      final request = http.MultipartRequest('POST', Uri.parse(CloudinaryConfig.uploadUrl));
      request.fields['timestamp'] = timestamp;
      request.fields['api_key'] = CloudinaryConfig.apiKey;
      request.fields['signature'] = signature;
      request.fields['folder'] = 'reports/$reportId';
      request.files.add(await http.MultipartFile.fromPath('file', photo.path));

      print('Uploading photo to Cloudinary for report: $reportId');
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Upload timed out. Check your connection.'),
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final secureUrl = data['secure_url'] as String?;
        print('Photo uploaded successfully: $secureUrl');
        return secureUrl;
      } else {
        print('Cloudinary upload failed: ${response.body}');
        throw Exception('Upload failed with status ${response.statusCode}');
      }
    } catch (e) {
      print('Photo upload error: $e');
      print('Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  // ─── Delete ─────────────────────────────────────────────────

  @override
  Future<void> deletePhoto(String publicId) async {
    try {
      final timestamp = getTimestamp();
      final params = {
        'public_id': publicId,
        'timestamp': timestamp,
      };

      final signature = generateSignature(params);

      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/destroy',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'timestamp': timestamp,
          'api_key': CloudinaryConfig.apiKey,
          'signature': signature,
          'public_id': publicId,
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Delete timed out.'),
      );

      if (response.statusCode == 200) {
        print('Photo deleted from Cloudinary: $publicId');
      } else {
        print('Cloudinary delete failed: ${response.body}');
      }
    } catch (e) {
      print('Photo delete error: $e');
    }
  }

  // ─── Helpers ────────────────────────────────────────────────

  static String extractPublicIdFromUrl(String url) {
    final withoutQuery = url.split('?').first;
    final regex = RegExp(r'/upload/(?:v\d+/)?(.+)$');
    final match = regex.firstMatch(withoutQuery);
    return match?.group(1) ?? '';
  }
}