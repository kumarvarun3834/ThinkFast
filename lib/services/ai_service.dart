import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:thinkfast/services/api_client.dart';
import 'package:thinkfast/utils/global.dart' as global;

import 'admin_service.dart';
import 'local_cache_service.dart';
import 'settings_service.dart';

class AiService {
  final LocalCacheService _cache = LocalCacheService();

  // Client-side Debouncing
  static DateTime? _lastGenerationTime;
  static const Duration _generationCooldown = Duration(seconds: 10);

  Future<void> _checkAiEnabled(String userId) async {
    final bool isAdmin = await AdminService().isAdmin(userId);
    final flags = await SettingsService().getFeatureFlags(isAdmin: isAdmin);
    if (flags?['enable_ai'] == false) {
      if (!isAdmin) {
        throw Exception(
          "AI features are currently disabled by the administrator.",
        );
      }
    }
  }

  /// ✅ Log AI Generation
  Future<void> logGeneration({
    required String userId,
    required String prompt,
    required String generatedQuizId,
    Map<String, dynamic>? metadata,
  }) async {
    await _checkAiEnabled(userId);

    // Call database service
    await global.aiConnect.logGeneration(
      userId: userId,
      prompt: prompt,
      generatedQuizId: generatedQuizId,
      metadata: metadata,
    );

    // Update local cache: fetch fresh or increment
    final newUsage = await global.aiConnect.getAiUsageToday(userId);
    await _cache.saveAiUsage(newUsage);
  }

  /// ✅ Check if user has AI generation quota remaining
  Future<bool> hasAiQuota(String userId) async {
    // 1. Admins with 'bypass_ai_quotas' permission can generate unlimited quizzes
    if (await AdminService().hasPermission(userId, 'bypass_ai_quotas')) {
      return true;
    }

    final bool isAdmin = await AdminService().isAdmin(userId);
    final flags = await SettingsService().getFeatureFlags(isAdmin: isAdmin);

    // 2. Global bypass toggle
    if (flags?['enable_ai_quota_bypass'] == true) return true;

    // 3. Check daily limit
    final int limit = (flags?['ai_daily_generation_limit'] ?? 10).toInt();
    final int usage = await getAiUsageToday(userId);

    return usage < limit;
  }

  /// ✅ Get AI usage count for today (with Local Cache support)
  Future<int> getAiUsageToday(String userId) async {
    // 1. Try Local Cache first
    final cached = await _cache.getAiUsage();
    if (cached != null) return cached;

    // 2. Fallback to Firestore
    final usage = await global.aiConnect.getAiUsageToday(userId);

    // 3. Update Cache
    await _cache.saveAiUsage(usage);

    return usage;
  }

  /// ✅ Create Quiz using Dedicated AI Server
  Future<Map<String, dynamic>> createAiQuiz({
    required String userId,
    required String userName,
    required String prompt,
    bool isPersonal = false,
    List<String>? tags,
    String? examTag,
    Map<String, dynamic>? additionalConfig,
  }) async {
    await _checkAiEnabled(userId);

    // Debounce check
    final now = DateTime.now();
    if (_lastGenerationTime != null &&
        now.difference(_lastGenerationTime!) < _generationCooldown) {
      final waitSeconds =
          _generationCooldown.inSeconds -
          now.difference(_lastGenerationTime!).inSeconds;
      throw Exception("Too many requests. Please wait $waitSeconds seconds.");
    }
    _lastGenerationTime = now;

    try {
      final Map<String, dynamic> requestBody = {
        'type': isPersonal ? 'wizard' : 'ai_text',
        'config': {...additionalConfig ?? {}, 'tags': tags, 'examTag': examTag},
        'input': prompt,
      };

      final Map<String, dynamic> hardenedPayload =
          await ApiClient.buildSecurityPayload(requestBody);
      developer.log(jsonEncode(hardenedPayload), name: 'AI Generation Payload');

      final url =
          "${global.aiBackendUrl.replaceAll(RegExp(r'/+$'), '')}/api/generate-quiz";
      debugPrint("AI Generation: Calling backend -> $url");

      final response = await ApiClient.instance.post(
        url,
        data: hardenedPayload,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        developer.log(
          jsonEncode(response.data),
          name: 'AI Generation Response',
        );
        final data = response.data;

        // Update local usage cache after successful generation
        final newUsage = await global.aiConnect.getAiUsageToday(userId);
        await _cache.saveAiUsage(newUsage);

        return {
          'quizId': data['quizId'],
          'queueId': data['queueId'], // Support new queue tracking
          'status': data['status'] ?? 'completed',
          'message': data['message'] ?? '',
          'traces': data['traces'] ?? [],
          'explanation': data['explanation'] ?? data['reasoning'] ?? '',
        };
      } else {
        developer.log(
          "AI Server Error [${response.statusCode}]: ${jsonEncode(response.data)}",
          name: 'AI Server Error',
        );
        throw Exception(
          "AI Generation failed: ${response.data?['error'] ?? 'Server returned ${response.statusCode}'}",
        );
      }
    } catch (e) {
      debugPrint("AI Service Error: $e");
      throw Exception("An unexpected error occurred during AI generation: $e");
    }
  }

  /// ✅ Generate Quiz from PDF using Dedicated AI Server (Base64)
  Future<String> generateQuizFromPDF({
    required String userId,
    required String pdfName,
    required int pdfSize,
    required String pdfData,
    bool isPersonal = false,
  }) async {
    await _checkAiEnabled(userId);

    // Debounce check
    final now = DateTime.now();
    if (_lastGenerationTime != null &&
        now.difference(_lastGenerationTime!) < _generationCooldown) {
      final waitSeconds =
          _generationCooldown.inSeconds -
          now.difference(_lastGenerationTime!).inSeconds;
      throw Exception("Too many requests. Please wait $waitSeconds seconds.");
    }
    _lastGenerationTime = now;

    try {
      final Map<String, dynamic> requestBody = {
        'type': 'ai_pdf',
        'config': {
          'pdfName': pdfName,
          'pdfSize': pdfSize,
          'isPersonal': isPersonal,
        },
        'input': pdfData, // Base64
      };

      final Map<String, dynamic> hardenedPayload =
          await ApiClient.buildSecurityPayload(requestBody);
      developer.log(
        jsonEncode(hardenedPayload),
        name: 'PDF Generation Payload',
      );

      final url =
          "${global.aiBackendUrl.replaceAll(RegExp(r'/+$'), '')}/api/generate-quiz-pdf";
      debugPrint("PDF Generation: Calling backend -> $url");

      final response = await ApiClient.instance.post(
        url,
        data: hardenedPayload,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        developer.log(
          jsonEncode(response.data),
          name: 'PDF Recognition Response',
        );
        final data = response.data;

        // Update local usage cache after successful generation
        final newUsage = await global.aiConnect.getAiUsageToday(userId);
        await _cache.saveAiUsage(newUsage);

        return data['queueId'] ?? data['quizId'];
      } else {
        developer.log(
          "PDF Server Error [${response.statusCode}]: ${jsonEncode(response.data)}",
          name: 'PDF Server Error',
        );
        throw Exception(
          "PDF Recognition failed: ${response.data?['error'] ?? 'Server returned ${response.statusCode}'}",
        );
      }
    } catch (e) {
      debugPrint("PDF Service Error: $e");
      throw Exception("An error occurred during PDF processing: $e");
    }
  }

  /// ✅ Analyze Quiz Attempt for Reasoning and Improvements
  Future<Map<String, dynamic>> analyzeAttempt({
    required String userId,
    required String userName,
    required String userEmail,
    required String quizId,
    required String responseId,
  }) async {
    await _checkAiEnabled(userId);

    // Add a small delay to ensure Firestore write for response is synced
    await Future.delayed(const Duration(seconds: 2));

    int retryCount = 0;
    const int maxRetries = 2;

    while (retryCount <= maxRetries) {
      try {
        final Map<String, dynamic> requestBody = {
          'action': 'analyze',
          'data': {'quizId': quizId, 'responseId': responseId},
        };

        final Map<String, dynamic> hardenedPayload =
            await ApiClient.buildSecurityPayload(requestBody);
        developer.log(jsonEncode(hardenedPayload), name: 'AI Analysis Payload');

        final url =
            "${global.aiBackendUrl.replaceAll(RegExp(r'/+$'), '')}/api/quizzes/$quizId/actions";
        debugPrint("AI Analysis: Calling backend -> $url (Retry: $retryCount)");

        final response = await ApiClient.instance.post(
          url,
          data: hardenedPayload,
          options: Options(headers: {'Content-Type': 'application/json'}),
        );

        if (response.statusCode == 200) {
          developer.log(
            jsonEncode(response.data),
            name: 'AI Analysis Response',
          );
          return response.data as Map<String, dynamic>;
        } else {
          final errorBody = response.data;
          // If response not found, retry after a short delay
          if (response.statusCode == 404 && retryCount < maxRetries) {
            retryCount++;
            await Future.delayed(const Duration(seconds: 3));
            continue;
          }
          throw Exception(
            errorBody['error'] ??
                "AI Analysis failed. Status: ${response.statusCode}",
          );
        }
      } catch (e) {
        if (retryCount < maxRetries) {
          retryCount++;
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }
        debugPrint("AI Analysis Error: $e");
        throw Exception(e.toString());
      }
    }
    throw Exception("AI Analysis timed out or failed after retries.");
  }

  /// ✅ Get Quiz Status from API (Polling for async generation)
  Future<Map<String, dynamic>> getQuizStatus(String quizId) async {
    try {
      final baseUrl = global.aiBackendUrl.replaceAll(RegExp(r'/+$'), '');
      final url = "$baseUrl/api/quiz/status/$quizId";
      debugPrint("AI Status Polling: Calling backend -> $url");

      final response = await ApiClient.instance.get(
        url,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        // Retry with an alias if the primary status isn't found
        final altUrl = "$baseUrl/api/quiz/progress/$quizId";
        final altResponse = await ApiClient.instance.get(
          altUrl,
          options: Options(
            headers: {'Content-Type': 'application/json'},
            validateStatus: (status) => status! < 500,
          ),
        );
        if (altResponse.statusCode == 200) return altResponse.data;
      }

      throw Exception("Failed to fetch status: ${response.statusCode}");
    } catch (e) {
      debugPrint("AI Status Error: $e");
      throw Exception("Polling error: $e");
    }
  }

  /// ✅ Get Queue Status from API (Polling for async generation)
  Future<Map<String, dynamic>> getQueueStatus(String queueId) async {
    try {
      final baseUrl = global.aiBackendUrl.replaceAll(RegExp(r'/+$'), '');
      final url = "$baseUrl/api/quiz_queue/$queueId";
      debugPrint("AI Queue Status Polling: Calling backend -> $url");

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
      throw Exception("Failed to fetch queue status: ${response.statusCode}");
    } catch (e) {
      debugPrint("AI Queue Status Error: $e");
      throw Exception("Queue polling error: $e");
    }
  }

  /// ✅ Manually Process Quiz Queue (Admin Only)
  Future<Map<String, dynamic>> processQuizQueue() async {
    try {
      final url =
          "${global.aiBackendUrl.replaceAll(RegExp(r'/+$'), '')}/api/admin/tasks";
      debugPrint("AI Queue: Triggering manual flush -> $url");

      final Map<String, dynamic> requestData = {'task': 'flush_queue'};
      final Map<String, dynamic> hardenedPayload =
          await ApiClient.buildSecurityPayload(requestData);

      final response = await ApiClient.instance.post(
        url,
        data: hardenedPayload,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception("Queue processing failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("AI Queue Error: $e");
      throw Exception("An error occurred during queue processing: $e");
    }
  }
}
