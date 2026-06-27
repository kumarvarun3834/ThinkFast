import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:thinkfast/utils/global.dart' as global;

import 'admin_service.dart';
import 'quiz_data_processor.dart';
import 'settings_service.dart';

class AiService {
  final CollectionReference _generations = FirebaseFirestore.instance
      .collection('ai_generations');
  final CollectionReference _usage = FirebaseFirestore.instance.collection(
    'user_usage',
  );

  Future<void> _checkAiEnabled(String userId) async {
    final flags = await SettingsService().getFeatureFlags();
    if (flags?['enable_ai'] == false) {
      if (!await AdminService().isAdmin(userId)) {
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
    await _generations.add({
      'userId': userId,
      'prompt': prompt,
      'generatedQuizId': generatedQuizId,
      'createdAt': FieldValue.serverTimestamp(),
      'metadata': metadata,
    });

    // Update usage
    await _usage.doc(userId).set({
      'aiGenerationsToday': FieldValue.increment(1),
      'lastReset': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// ✅ Check if user has AI generation quota remaining
  Future<bool> hasAiQuota(String userId) async {
    // 1. Admins with 'bypass_ai_quotas' permission can generate unlimited quizzes
    if (await AdminService().hasPermission(userId, 'bypass_ai_quotas')) {
      return true;
    }

    final flags = await SettingsService().getFeatureFlags();
    
    // 2. Global bypass toggle
    if (flags?['enable_ai_quota_bypass'] == true) return true;

    // 3. Check daily limit
    final int limit = (flags?['ai_daily_generation_limit'] ?? 10).toInt();
    final int usage = await getAiUsageToday(userId);

    return usage < limit;
  }

  /// ✅ Get AI usage count for today
  Future<int> getAiUsageToday(String userId) async {
    final doc = await _usage.doc(userId).get();
    if (!doc.exists) return 0;

    final data = doc.data() as Map<String, dynamic>;
    final Timestamp? lastReset = data['lastReset'];

    if (lastReset != null) {
      final lastDate = lastReset.toDate();
      final now = DateTime.now();
      if (lastDate.day != now.day ||
          lastDate.month != now.month ||
          lastDate.year != now.year) {
        // Reset count if it's a new day
        await _usage.doc(userId).update({
          'aiGenerationsToday': 0,
          'lastReset': FieldValue.serverTimestamp(),
        });
        return 0;
      }
    }

    return data['aiGenerationsToday'] ?? 0;
  }

  /// ✅ Create Quiz directly from AI with Validation and Repair Flow
  Future<String> createAiQuiz({
    required String userId,
    required String userName,
    required String prompt,
    bool isPersonal = false,
  }) async {
    await _checkAiEnabled(userId);

    // 1. Generate JSON with specific "System Prompt" instruction
    final systemPrompt =
        """
      Generate a professional quiz JSON for '$prompt'.
      
      Dynamic Personalization Rules:
      - If Accuracy < 50% → 70% Easy, 25% Medium, 5% Hard.
      - If Accuracy > 80% → 20% Medium, 60% Hard, 20% Challenge.
      - Otherwise → 50% Easy, 50% Medium.
      - Wildcard: Always include 1-2 questions of random difficulty.

      Strict JSON Schema:
      {
        "title": "string",
        "description": "string",
        "questions": [
          {
            "type": "Single Choice" | "Multiple Choice" | "Integer",
            "question": "string",
            "choices": ["string"],
            "answers": ["string"],
            "subject": "string",
            "description": "string" (explanation)
          }
        ]
      }
    """;

    final stopwatch = Stopwatch()..start();
    String jsonContent = await generateQuizJson("$prompt $systemPrompt");

    // 2. Schema Validation & Repair Flow
    try {
      _validateJsonSchema(jsonContent);
    } catch (e) {
      debugPrint("Initial AI response malformed. Attempting repair...");
      jsonContent = await _repairJson(jsonContent, e.toString());
      _validateJsonSchema(jsonContent); // Final check
    }

    // 3. Content Quality Checks
    final result = await QuizDataProcessor.processImportData(jsonContent);
    _performQualityChecks(result);

    // 4. Save to Database
    final quizId = await global.qDb.createDatabase(
      creatorId: userId,
      user: userName,
      title: result.title ?? "AI: $prompt",
      description: result.description ?? "Generated based on: $prompt",
      visibility: isPersonal ? "private" : "public",
      data: result.questions,
      time: (result.time ?? 600) ~/ 60,
      markingScheme: {
        'type': result.markingType ?? 'default',
        'passThreshold': result.markingPassThreshold ?? 40,
        if (result.markingGlobal != null) 'global': result.markingGlobal,
        if (result.markingPerType != null)
          'perQuestionType': result.markingPerType,
        if (result.markingPerQuestion != null)
          'perQuestion': result.markingPerQuestion,
      },
      attemptLimits: {
        'type': result.attemptLimitType ?? 'none',
        if (result.globalLimits != null) 'global': result.globalLimits,
        if (result.perModuleLimits != null) 'perModule': result.perModuleLimits,
      },
      isPersonal: isPersonal,
      isAiGenerated: true,
    );

    stopwatch.stop();

    // 5. Log it with Metadata
    await logGeneration(
      userId: userId,
      prompt: prompt,
      generatedQuizId: quizId,
      metadata: {
        'model': 'ai-engine-v2',
        'generationTimeMs': stopwatch.elapsedMilliseconds,
        'tokenUsage': jsonContent.length ~/ 4, // Rough estimate
      },
    );

    return quizId;
  }

  /// 🛠️ JSON Schema Validator
  void _validateJsonSchema(String rawJson) {
    final Map<String, dynamic> data = jsonDecode(rawJson);
    if (!data.containsKey('title') || data['title'] is! String) {
      throw "Missing 'title'";
    }
    if (!data.containsKey('questions') || data['questions'] is! List) {
      throw "Missing 'questions' list";
    }

    for (var q in data['questions']) {
      if (q['question'] == null || q['type'] == null)
        throw "Malformed question object";
      if (q['type'] != "Integer" &&
          (q['choices'] == null || (q['choices'] as List).isEmpty)) {
        throw "Choices missing for ${q['type']} question";
      }
      if (q['answers'] == null || (q['answers'] as List).isEmpty)
        throw "Answers missing";
    }
  }

  /// 🛠️ Repair Flow
  Future<String> _repairJson(String malformedJson, String error) async {
    final repairPrompt =
        "The following JSON is invalid: $error. Please fix the structure and return ONLY the corrected JSON: $malformedJson";
    return await generateQuizJson(repairPrompt);
  }

  /// 🛠️ Content Quality Checks
  void _performQualityChecks(dynamic result) {
    final questions = result.questions;
    if (questions.isEmpty) throw "AI generated an empty quiz";

    final seenQuestions = <String>{};
    for (var q in questions) {
      final text = q['question'].toString().toLowerCase().trim();
      if (seenQuestions.contains(text))
        throw "Duplicate question detected: $text";
      seenQuestions.add(text);

      if (q['description'] == null ||
          q['description'].toString().trim().isEmpty) {
        throw "Empty explanation detected for question: ${q['question']}";
      }
    }
  }

  /// ✅ Mock AI Generation (Should be replaced with actual API call)
  Future<String> generateQuizJson(String prompt) async {
    // In a real app, this would call OpenAI/Gemini with the prompt
    await Future.delayed(const Duration(seconds: 2));

    // Returning a more diverse template
    return jsonEncode({
      "title": "ThinkFast AI: Topic Exploration",
      "description": "Comprehensive quiz generated for your request.",
      "time": 900,
      "markingScheme": {
        "type": "per_question_type",
        "passThreshold": 50,
        "perQuestionType": {
          "Single Choice": {"correct": 4, "wrong": -1},
          "Multiple Choice": {"correct": 6, "wrong": -2},
          "Integer": {"correct": 10, "wrong": 0},
        },
      },
      "questions": [
        {
          "question": "Which of these are primary colors?",
          "choices": ["Red", "Green", "Blue", "Yellow"],
          "answers": ["Red", "Blue", "Yellow"],
          "type": "Multiple Choice",
          "subject": "Basics",
          "description":
              "Primary colors are those that cannot be created by mixing other colors.",
        },
        {
          "question": "What is 25 * 4?",
          "choices": [],
          "answers": ["100"],
          "type": "Integer",
          "subject": "Arithmetic",
          "description": "25 times 4 equals exactly 100.",
        },
        {
          "question": "What is the capital of France?",
          "choices": ["London", "Berlin", "Paris", "Madrid"],
          "answers": ["Paris"],
          "type": "Single Choice",
          "subject": "Geography",
          "description":
              "Paris is the capital and most populous city of France.",
        },
      ],
    });
  }
}
