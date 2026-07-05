import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCacheService {
  static const String _keyRecentQuizzes = 'recent_quizzes';

  /// ✅ Save a quiz to the "Recently Viewed" list (Limited to last 10)
  Future<void> saveRecentQuiz(Map<String, dynamic> quizData) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing list
    List<String> recentJson = prefs.getStringList(_keyRecentQuizzes) ?? [];
    List<Map<String, dynamic>> recentList = recentJson
        .map((item) => jsonDecode(item) as Map<String, dynamic>)
        .toList();

    // Remove if already exists (to move to top)
    recentList.removeWhere((item) => item['id'] == quizData['id']);

    // Create a compact version of the data to save space
    final Map<String, dynamic> compactData = {
      'id': quizData['id'],
      'title': quizData['title'],
      'description': quizData['description'],
      'visibility': quizData['visibility'],
      'examTag': quizData['examTag'],
      'user': quizData['user'],
      'totalQuestions': quizData['totalQuestions'],
      'time': quizData['time'],
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Insert at start
    recentList.insert(0, compactData);

    // Trim to 10
    if (recentList.length > 10) {
      recentList = recentList.sublist(0, 10);
    }

    // Save back
    await prefs.setStringList(
      _keyRecentQuizzes,
      recentList.map((item) => jsonEncode(item)).toList(),
    );
  }

  /// ✅ Retrieve the last 10 recent quizzes
  Future<List<Map<String, dynamic>>> getRecentQuizzes() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> recentJson = prefs.getStringList(_keyRecentQuizzes) ?? [];
    return recentJson
        .map((item) => jsonDecode(item) as Map<String, dynamic>)
        .toList();
  }

  /// ✅ Clear recent quizzes
  Future<void> clearRecentQuizzes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRecentQuizzes);
  }
}
