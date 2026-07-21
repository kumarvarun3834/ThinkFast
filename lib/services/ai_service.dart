import 'dart:convert';
import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
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
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();

      final Map<String, dynamic> inputStatement = _buildJsonInputStatement(
        userId: userId,
        userName: userName,
        userPrompt: prompt,
        config: additionalConfig ?? {},
      );

      final String effectiveUuid = userId.isNotEmpty ? userId : (user?.uid ?? '');

      final Map<String, dynamic> body = {
        'uuid': effectiveUuid,
        'email': global.currentUserProfile?['email'] ?? user?.email,
        'name': userName,
        'prompt': prompt, // Include prompt at root as per docs
        'input': inputStatement,
        'isPersonal': isPersonal,
        'tags': tags,
        'examTag': examTag,
      };
      developer.log(jsonEncode(body), name: 'AI Generation Payload');

      final response = await http.post(
        Uri.parse("${global.aiBackendUrl}/generateQuiz"),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      debugPrint("AI Generation: Calling backend -> ${global.aiBackendUrl}/generateQuiz");

      if (response.statusCode == 200) {
        developer.log(response.body, name: 'AI Generation Response');
        final data = jsonDecode(response.body);
        final String quizId = data['quizId'];

        // Update local usage cache after successful generation
        final newUsage = await global.aiConnect.getAiUsageToday(userId);
        await _cache.saveAiUsage(newUsage);

        return {
          'quizId': quizId,
          'explanation': data['explanation'] ?? data['reasoning'] ?? '',
        };
      } else {
        developer.log(
          "AI Server Error: ${response.statusCode} - ${response.body}",
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
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();

      final Map<String, dynamic> inputStatement = _buildJsonInputStatement(
        userId: userId,
        userName: global.currentUserProfile?['name'] ?? 'User',
        userPrompt: "Generate a quiz from the uploaded PDF document: $pdfName",
        config: {'source': 'pdf', 'pdfName': pdfName, 'pdfSize': pdfSize},
      );

      final String effectiveUuid = userId.isNotEmpty ? userId : (user?.uid ?? '');

      final Map<String, dynamic> body = {
        'uuid': effectiveUuid,
        'email': global.currentUserProfile?['email'] ?? user?.email,
        'name': global.currentUserProfile?['name'] ?? 'User',
        'pdfName': pdfName,
        'pdfSize': pdfSize,
        'pdfData': pdfData,
        'input': inputStatement,
        'isPersonal': isPersonal,
      };
      developer.log(jsonEncode(body), name: 'PDF Generation Payload');

      final response = await http.post(
        Uri.parse("${global.aiBackendUrl}/generateQuizFromPDF"),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      debugPrint("PDF Generation: Calling backend -> ${global.aiBackendUrl}/generateQuizFromPDF");

      if (response.statusCode == 200) {
        developer.log(response.body, name: 'PDF Recognition Response');
        final data = jsonDecode(response.body);

        // Update local usage cache after successful generation
        final newUsage = await global.aiConnect.getAiUsageToday(userId);
        await _cache.saveAiUsage(newUsage);

        return data['quizId'];
      } else {
        developer.log(
          "PDF Server Error: ${response.statusCode} - ${response.body}",
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
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final url = "${global.aiBackendUrl}/api/quiz/analyze";
      debugPrint("AI Analysis: Calling backend -> $url");

      final Map<String, dynamic> body = {
        'uuid': userId,
        'email': userEmail,
        'name': userName,
        'quizId': quizId,
        'responseId': responseId,
      };
      developer.log(jsonEncode(body), name: 'AI Analysis Payload');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        developer.log(response.body, name: 'AI Analysis Response');
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? "AI Analysis failed. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("AI Analysis Error: $e");
      throw Exception(e.toString());
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
