import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalCacheService {
  static const String _keyRecentActivity =
      'recent_quizzes'; // Keeping the same key for migration compatibility
  static const String _keyAiUsage = 'ai_usage_today';
  static const String _keyAiUsageDate = 'ai_usage_date';
  static const String _keySplitRatio = 'split_ratio';

  /// Cache AI Usage for the day
  Future<void> saveAiUsage(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAiUsage, count);
    await prefs.setString(_keyAiUsageDate, DateTime.now().toIso8601String());
  }

  /// Get cached AI Usage
  Future<int?> getAiUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString(_keyAiUsageDate);
    if (dateStr == null) return null;
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      if (date.day != now.day ||
          date.month != now.month ||
          date.year != now.year) {
        return null;
      }
      return prefs.getInt(_keyAiUsage);
    } catch (e) {
      return null;
    }
  }

  /// Save activity (Quiz View or Attempt) to the "Recent" list
  Future<void> saveRecentActivity({
    required String id,
    required String title,
    String? attemptId,
    String? user,
    String? examTag,
    required String activityType, // 'quiz' or 'result'
  }) async {
    final prefs = await SharedPreferences.getInstance();

    List<String> recentJson = prefs.getStringList(_keyRecentActivity) ?? [];
    List<Map<String, dynamic>> recentList = recentJson
        .map((item) => jsonDecode(item) as Map<String, dynamic>)
        .toList();

    // Remove if already exists (match by ID and Type to allow same quiz and its result to coexist if needed,
    // or just match by ID to move the quiz to top regardless of why it was viewed)
    // Preference: Match by ID to keep the list clean.
    recentList.removeWhere((item) => item['id'] == id);

    final Map<String, dynamic> activityData = {
      'id': id,
      'title': title,
      'attemptId': attemptId,
      'user': user,
      'examTag': examTag,
      'activityType': activityType,
      'timestamp': DateTime.now().toIso8601String(),
    };

    recentList.insert(0, activityData);

    if (recentList.length > 12) {
      recentList = recentList.sublist(0, 12);
    }

    await prefs.setStringList(
      _keyRecentActivity,
      recentList.map((item) => jsonEncode(item)).toList(),
    );
  }

  /// Legacy wrapper (for compatibility)
  Future<void> saveRecentQuiz(Map<String, dynamic> quizData) async {
    await saveRecentActivity(
      id: quizData['id'],
      title: quizData['title'] ?? 'Untitled',
      user: quizData['user'],
      examTag: quizData['examTag'],
      activityType: 'quiz',
    );
  }

  /// Retrieve recent activity
  Future<List<Map<String, dynamic>>> getRecentQuizzes() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> recentJson = prefs.getStringList(_keyRecentActivity) ?? [];
    return recentJson
        .map((item) => jsonDecode(item) as Map<String, dynamic>)
        .toList();
  }

  /// Clear recent activity
  Future<void> clearRecentQuizzes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRecentActivity);
  }

  /// Save Split Ratio for Web/Desktop
  Future<void> saveSplitRatio(double ratio) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySplitRatio, ratio);
  }

  /// Retrieve Split Ratio
  Future<double?> getSplitRatio() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keySplitRatio);
  }
}
