import 'dart:convert';
import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:thinkfast/services/api_client.dart';
import 'package:thinkfast/utils/global.dart' as global;

import 'admin_service.dart';
import 'local_cache_service.dart';
import 'settings_service.dart';

class AiService {
  final LocalCacheService _cache = LocalCacheService();

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

    try {
      final Map<String, dynamic> inputStatement = _buildJsonInputStatement(
        userId: userId,
        userName: userName,
        userPrompt: prompt,
        config: additionalConfig ?? {},
      );

      final Map<String, dynamic> requestBody = {
        'input': inputStatement,
        'isPersonal': isPersonal,
        'tags': tags,
        'examTag': examTag,
      };

      final Map<String, dynamic> hardenedPayload = await ApiClient.buildSecurityPayload(requestBody);
      developer.log(jsonEncode(hardenedPayload), name: 'AI Generation Payload');

      final url = "${global.aiBackendUrl}/generateQuiz";
      debugPrint("AI Generation: Calling backend -> $url");

      final response = await ApiClient.instance.post(
        url,
        data: hardenedPayload,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        developer.log(jsonEncode(response.data), name: 'AI Generation Response');
        final data = response.data;
        final String quizId = data['quizId'];

        // Update local usage cache after successful generation
        final newUsage = await global.aiConnect.getAiUsageToday(userId);
        await _cache.saveAiUsage(newUsage);

        return {
          'quizId': data['quizId'],
          'status': data['status'] ?? 'completed',
          'message': data['message'] ?? '',
          'traces': data['traces'] ?? [],
          'explanation': data['explanation'] ?? data['reasoning'] ?? '',
        };
      } else {
        developer.log(
          "AI Server Error: ${response.statusCode} - ${response.data}",
          name: 'AI Server Error',
        );
        throw Exception(
          "AI Generation failed on the server. Status: ${response.statusCode}",
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

    try {
      final Map<String, dynamic> inputStatement = _buildJsonInputStatement(
        userId: userId,
        userName: global.currentUserProfile?['name'] ?? 'User',
        userPrompt: "Generate a quiz from the uploaded PDF document: $pdfName",
        config: {'source': 'pdf', 'pdfName': pdfName, 'pdfSize': pdfSize},
      );

      final Map<String, dynamic> requestBody = {
        'pdfName': pdfName,
        'pdfSize': pdfSize,
        'pdfData': pdfData,
        'input': inputStatement,
        'isPersonal': isPersonal,
      };

      final Map<String, dynamic> hardenedPayload = await ApiClient.buildSecurityPayload(requestBody);
      developer.log(jsonEncode(hardenedPayload), name: 'PDF Generation Payload');

      final url = "${global.aiBackendUrl}/generateQuizFromPDF";
      debugPrint("PDF Generation: Calling backend -> $url");

      final response = await ApiClient.instance.post(
        url,
        data: hardenedPayload,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        developer.log(jsonEncode(response.data), name: 'PDF Recognition Response');
        final data = response.data;

        // Update local usage cache after successful generation
        final newUsage = await global.aiConnect.getAiUsageToday(userId);
        await _cache.saveAiUsage(newUsage);

        return data['quizId'];
      } else {
        developer.log(
          "PDF Server Error: ${response.statusCode} - ${response.data}",
          name: 'PDF Server Error',
        );
        throw Exception(
          "PDF Recognition failed on the server. Status: ${response.statusCode}",
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

    try {
      final Map<String, dynamic> requestBody = {
        'quizId': quizId,
        'responseId': responseId,
      };

      final Map<String, dynamic> hardenedPayload = await ApiClient.buildSecurityPayload(requestBody);
      developer.log(jsonEncode(hardenedPayload), name: 'AI Analysis Payload');

      final url = "${global.aiBackendUrl}/api/quiz/analyze";
      debugPrint("AI Analysis: Calling backend -> $url");

      final response = await ApiClient.instance.post(
        url,
        data: hardenedPayload,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        developer.log(jsonEncode(response.data), name: 'AI Analysis Response');
        return response.data as Map<String, dynamic>;
      } else {
        final errorBody = response.data;
        throw Exception(errorBody['error'] ?? "AI Analysis failed. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("AI Analysis Error: $e");
      throw Exception(e.toString());
    }
  }

  /// ✅ Get Quiz Status from API (Checking memory/Firestore)
  Future<Map<String, dynamic>> getQuizStatus(String quizId) async {
    try {
      final url = "${global.aiBackendUrl}/api/quiz-status/$quizId";
      debugPrint("AI Status: Polling -> $url");

      final response = await ApiClient.instance.get(
        url,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception("Failed to fetch status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("AI Status Error: $e");
      throw Exception("An error occurred while checking quiz status: $e");
    }
  }

  /// ✅ Manually Process Quiz Queue (Admin Only)
  Future<Map<String, dynamic>> processQuizQueue() async {
    try {
      final url = "${global.aiBackendUrl}/api/admin/queue/process";
      debugPrint("AI Queue: Triggering manual flush -> $url");

      final Map<String, dynamic> hardenedPayload = await ApiClient.buildSecurityPayload({});
      
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

  /// 🛠️ Helper to build a structured JSON "Input Statement" for the AI
  Map<String, dynamic> _buildJsonInputStatement({
    required String userId,
    required String userName,
    required String userPrompt,
    required Map<String, dynamic> config,
  }) {
    final profile = global.currentUserProfile ?? {};

    final String? subject = config['subject'];
    final String? topic = config['topic'];
    String clearStatement = userPrompt;
    if (subject != null && topic != null) {
      clearStatement = "Generate a quiz for $subject > $topic. $userPrompt";
    }

    final bool isExtendedProfileEnabled = profile['optInAiAnalysis'] == true;
    final bool isPersonalizationRequested =
        config['personalization'] != '❌ Ignore history' ||
        config['difficulty'] == 'Adaptive AI ⭐' ||
        config['coverage'] == 'Previous Mistakes ⭐';

    final Map<String, dynamic> userPayload = {
      "uid": userId,
      "name": userName,
      "email": profile['email'] ?? FirebaseAuth.instance.currentUser?.email,
    };

    if (isExtendedProfileEnabled) {
      // Persona is sent if Extended Profile is active
      userPayload["persona"] = {
        "class": profile['class'],
        "goal": profile['goal'],
        "targetExam": profile['targetExam'],
        "learningStyle": profile['learningStyle'],
        "interests": profile['interests'],
        "language": profile['preferredLanguage'] ?? 'English'
      };

      // Performance is ONLY sent if BOTH Extended Profile is active AND personalization is requested
      if (isPersonalizationRequested) {
        userPayload["performance"] = {
          "attemptCount": profile['attemptCount'],
          "quizCount": profile['quizCount'],
          "avgScore": profile['avgScore'] ?? '0%',
          "timeSpentPerQ": profile['timeSpentPerQ'] ?? 'Auto',
          "commonMistakes": profile['commonMistakes'] ?? [],
          "weakTopics": profile['weakTopics'] ?? [],
          "strongTopics": profile['strongTopics'] ?? [],
          "topicPerformance": profile['topicPerformance'] ?? {},
          "recentlyStudiedTopics": profile['lastQuizTopics'] ?? [],
          "learningStyle": profile['learningStyle'] ?? 'Adaptive',
          "preferredDifficulty": profile['preferredDifficulty'] ?? 'Medium'
        };
      }
    }

    return {
      "system": {
        "role": "Quiz Wiz - Professional Educational Content Developer",
        "project": global.projectContext,
        "instructions": [
          "Generate professional, pedagogical quiz content.",
          "Ensure high personalization based on the provided user profile.",
          "Prioritize weak topics if difficulty is set to 'Adaptive'.",
          "Return ONLY valid JSON matching the requested schema."
        ]
      },
      "user": userPayload,
      "request": {
        "user_input": userPrompt,
        "clear_statement": clearStatement,
        "hierarchy": {
          "subject": subject,
          "topic": topic
        },
        "config": config,
        "output_format": {
          "type": "json",
          "schema": {
            "title": "string",
            "description": "string",
            "questions": [
              {
                "type": "Single Choice | Multiple Choice | Integer",
                "question": "string",
                "choices": ["string"],
                "answers": ["string"],
                "subject": "string",
                "explanation": "string"
              }
            ]
          }
        }
      }
    };
  }
}
