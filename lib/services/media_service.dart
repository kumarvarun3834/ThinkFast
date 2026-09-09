import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:thinkfast/services/api_client.dart';
import 'package:thinkfast/utils/global.dart' as global;

class MediaService {
  static final MediaService _instance = MediaService._internal();

  factory MediaService() => _instance;

  MediaService._internal();

  /// Upload Media via Backend (GitHub Storage Strategy)
  Future<String?> uploadMedia({
    required String fileName,
    required String fileType,
    required Uint8List bytes,
    required String quizId,
  }) async {
    try {
      final String base64Data = base64Encode(bytes);

      final Map<String, dynamic> requestData = {
        'fileName': fileName,
        'fileType': fileType,
        'base64Data': base64Data,
        'quizId': quizId,
      };

      final Map<String, dynamic> hardenedPayload =
          await ApiClient.buildSecurityPayload(requestData);

      final url = "${global.aiBackendUrl}/api/v1/media/upload";
      debugPrint("Media Upload: Calling backend -> $url");

      final response = await ApiClient.instance.post(
        url,
        data: hardenedPayload,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == 'success') {
          return data['url'] as String;
        } else {
          throw Exception(
            data['error'] ?? "Upload failed without error message",
          );
        }
      } else {
        throw Exception("Server returned ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Media Upload Error: $e");
      return null;
    }
  }

  /// ✅ Get Storage Repository Status (Admin Only)
  Future<Map<String, dynamic>?> getStorageStatus() async {
    try {
      final url = "${global.aiBackendUrl}/api/v1/media/repo/status";
      final response = await ApiClient.instance.get(
        url,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status! < 500,
        ),
      );
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Storage Status Error: $e");
    }
    return null;
  }

  /// 🔄 Manually Trigger Repo Rotation (Admin Only)
  Future<Map<String, dynamic>> rotateStorageRepo() async {
    try {
      final url = "${global.aiBackendUrl}/api/v1/media/repo/provision";
      final response = await ApiClient.instance.post(
        url,
        data: {"forceRotate": true},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status! < 500,
        ),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'error': e.toString()};
    }
  }
}
