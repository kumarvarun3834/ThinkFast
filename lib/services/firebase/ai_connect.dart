import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

import '../../utils/global.dart' as global;
import '../admin_service.dart';
import '../settings_service.dart';

/// 🤖 Database Service for AI-Related Operations
class AiDatabaseService {
  final AdminService _adminService = AdminService();
  final SettingsService _settingsService = SettingsService();

  final CollectionReference _generations = FirebaseFirestore.instance
      .collection('ai_generations');
  final CollectionReference _usage = FirebaseFirestore.instance.collection(
    'user_usage',
  );

  Future<void> _ensurePermission(String? flag, {String? userId}) async {
    final flags =
        global.featureFlags ??
        await _settingsService.getFeatureFlags(isAdmin: global.isAdmin);

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
        final actionName = flag
            .replaceFirst('enable_', '')
            .replaceAll('_', ' ');
        throw Exception(
          "Access Denied: '$actionName' is currently disabled by the administrator.",
        );
      }
    }
  }

  /// ✅ Log AI Generation to Firestore
  Future<void> logGeneration({
    required String userId,
    required String prompt,
    required String generatedQuizId,
    Map<String, dynamic>? metadata,
  }) async {
    await _ensurePermission('enable_ai', userId: userId);
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

  /// ✅ Get AI usage count for today from Firestore (with Initial Setup)
  Future<int> getAiUsageToday(String userId) async {
    await _ensurePermission('enable_ai', userId: userId);
    try {
      final doc = await _usage.doc(userId).get();

      if (!doc.exists) {
        // Initial setup for the user usage document to prevent null errors
        final initialData = {
          'aiGenerationsToday': 0,
          'lastReset': FieldValue.serverTimestamp(),
        };
        try {
          await _usage.doc(userId).set(initialData);
        } catch (e) {
          debugPrint("Warning: Could not initialize AI usage document ($e)");
        }
        return 0;
      }

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
      } else {
        // Sync missing field
        await _usage.doc(userId).update({
          'lastReset': FieldValue.serverTimestamp(),
        });
      }

      return data['aiGenerationsToday'] ?? 0;
    } catch (e) {
      debugPrint("Error fetching AI usage: $e");
      return 0;
    }
  }

  /// ✅ Check if user has AI generation quota remaining
  Future<bool> hasAiQuota(String userId) async {
    // 1. Admins with 'bypass_ai_quotas' permission can generate unlimited quizzes
    if (await _adminService.hasPermission(userId, 'bypass_ai_quotas')) {
      return true;
    }

    final bool isAdmin = await _adminService.isAdmin(userId);
    final flags = await _settingsService.getFeatureFlags(isAdmin: isAdmin);

    // 2. Global bypass toggle
    if (flags?['enable_ai_quota_bypass'] == true) return true;

    // 3. Check daily limit
    final int limit = (flags?['ai_daily_generation_limit'] ?? 10).toInt();
    final int usage = await getAiUsageToday(userId);

    return usage < limit;
  }

  Stream<List<Map<String, dynamic>>> getAiGenerationHistory(String userId) {
    if (global.featureFlags?['maintenance_mode'] == true && !global.isAdmin) {
      return Stream.value([]);
    }
    return _generations
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList(),
        );
  }

  Future<Map<String, dynamic>?> getFeatureFlags() =>
      _settingsService.getFeatureFlags(isAdmin: global.isAdmin);
}
