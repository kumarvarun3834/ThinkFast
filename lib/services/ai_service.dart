import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_service.dart';
import 'firebase_direct_commands.dart';
import 'quiz_data_processor.dart';
import 'settings_service.dart';

class AiService {
  final CollectionReference _generations = FirebaseFirestore.instance
      .collection('ai_generations');
  final CollectionReference _usage = FirebaseFirestore.instance.collection(
    'user_usage',
  );
  final SettingsService _settings = SettingsService();
  final AdminService _admin = AdminService();

  Future<void> _checkAiEnabled(String userId) async {
    final flags = await _settings.getFeatureFlags();
    if (flags?['enable_ai'] == false) {
      if (!await _admin.isAdmin(userId)) {
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
  }) async {
    await _checkAiEnabled(userId);
    await _generations.add({
      'userId': userId,
      'prompt': prompt,
      'generatedQuizId': generatedQuizId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update usage
    await _usage.doc(userId).set({
      'aiGenerationsToday': FieldValue.increment(1),
      'lastReset': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// ✅ Check if user has AI generation quota remaining
  Future<bool> hasAiQuota(String userId) async {
    // Level 8+ bypasses AI rate limits
    if (await _admin.hasRequiredLevel(userId, 8)) {
      return true;
    } else {
      return false;
    }
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

  /// ✅ Create Quiz directly from AI
  Future<String> createAiQuiz({
    required String userId,
    required String userName,
    required String prompt,
    bool isPersonal = false,
  }) async {
    await _checkAiEnabled(userId);

    // 1. Generate JSON
    final jsonContent = await generateQuizJson(prompt);
    
    // 2. Process Result
    final result = await QuizDataProcessor.processImportData(jsonContent);
    
    // 3. Save to Database
    final db = DatabaseService();
    final quizId = await db.createDatabase(
      creatorId: userId,
      user: userName,
      title: result.title ?? "AI: $prompt",
      description: result.description ?? "Generated based on: $prompt",
      visibility: isPersonal ? "private" : "public",
      data: result.questions,
      time: (result.time ?? 600) ~/ 60,
      markingScheme: {
        'type': result.markingType ?? 'default',
        if (result.markingGlobal != null) 'global': result.markingGlobal,
        if (result.markingPerType != null) 'perQuestionType': result.markingPerType,
        if (result.markingPerQuestion != null) 'perQuestion': result.markingPerQuestion,
      },
      attemptLimits: {
        'type': result.attemptLimitType ?? 'none',
        if (result.globalLimits != null) 'global': result.globalLimits,
        if (result.perModuleLimits != null) 'perModule': result.perModuleLimits,
      },
      isPersonal: isPersonal,
      isAiGenerated: true,
    );

    // 4. Log it
    await logGeneration(
      userId: userId,
      prompt: prompt,
      generatedQuizId: quizId,
    );

    return quizId;
  }

  /// ✅ Mock AI Generation (Should be replaced with actual API call)
  Future<String> generateQuizJson(String prompt) async {
    // In a real app, this would call OpenAI/Gemini
    await Future.delayed(const Duration(seconds: 2));

    // Returning a basic template for testing
    return jsonEncode({
      "title": "AI Generated: $prompt",
      "description": "Automatically generated based on your prompt.",
      "time": 600,
      "markingScheme": {
        "type": "default"
      },
      "questions": [
        {
          "question": "Sample Question from AI?",
          "choices": ["Option A", "Option B", "Option C", "Option D"],
          "answers": ["Option A"],
          "type": "Single Choice",
          "subject": "General",
          "correct": 4,
          "wrong": -1,
        },
      ],
    });
  }
}
