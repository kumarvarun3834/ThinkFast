import 'package:cloud_firestore/cloud_firestore.dart';
import 'settings_service.dart';
import 'admin_service.dart';

class AiService {
  final CollectionReference _generations =
      FirebaseFirestore.instance.collection('ai_generations');
  final CollectionReference _usage =
      FirebaseFirestore.instance.collection('user_usage');
  final SettingsService _settings = SettingsService();
  final AdminService _admin = AdminService();

  Future<void> _checkAiEnabled(String userId) async {
    final flags = await _settings.getFeatureFlags();
    if (flags?['enable_ai'] == false) {
      if (!await _admin.isAdmin(userId)) {
        throw Exception("AI features are currently disabled by the administrator.");
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
    if (await _admin.hasRequiredLevel(userId, 8)) return true;

    final used = await getAiUsageToday(userId);
    const int dailyQuota = 5; // Example quota
    return used < dailyQuota;
  }
}
