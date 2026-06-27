import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/global.dart' as global;

import '../admin_service.dart';
import '../ai_service.dart';
import '../settings_service.dart';

/// 🤖 Database Service for AI-Related Operations
class AiDatabaseService {
  final AiService _aiService = AiService();
  final AdminService _adminService = AdminService();
  final SettingsService _settingsService = SettingsService();

  Future<void> _ensurePermission(String? flag, {String? userId}) async {
    final flags = global.featureFlags ?? await _settingsService.getFeatureFlags();

    if (flags?['maintenance_mode'] == true) {
      bool isUserAdmin = false;
      if (userId != null) {
        isUserAdmin = await _adminService.isAdmin(userId);
      }
      if (!isUserAdmin) {
        throw Exception(
          "System is currently under maintenance. Please try again later.",
        );
      }
    }

    if (flag != null && flags?[flag] == false) {
      bool isUserAdmin = false;
      if (userId != null) {
        isUserAdmin = await _adminService.isAdmin(userId);
      }
      if (!isUserAdmin) {
        final actionName = flag.replaceFirst('enable_', '').replaceAll('_', ' ');
        throw Exception(
          "Access Denied: '$actionName' is currently disabled by the administrator.",
        );
      }
    }
  }

  Future<String> createAiQuiz({
    required String userId,
    required String userName,
    required String prompt,
    bool isPersonal = false,
  }) async {
    await _ensurePermission('enable_ai', userId: userId);
    return _aiService.createAiQuiz(userId: userId, userName: userName, prompt: prompt, isPersonal: isPersonal);
  }

  Future<int> getAiUsageToday(String userId) => _aiService.getAiUsageToday(userId);

  Future<bool> hasAiQuota(String userId) => _aiService.hasAiQuota(userId);

  Future<void> logGeneration({
    required String userId,
    required String prompt,
    required String generatedQuizId,
    Map<String, dynamic>? metadata,
  }) async {
    return _aiService.logGeneration(userId: userId, prompt: prompt, generatedQuizId: generatedQuizId, metadata: metadata);
  }

  Stream<List<Map<String, dynamic>>> getAiGenerationHistory(String userId) {
    return FirebaseFirestore.instance
        .collection('ai_generations')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  Future<Map<String, dynamic>?> getFeatureFlags() => _settingsService.getFeatureFlags();
}
