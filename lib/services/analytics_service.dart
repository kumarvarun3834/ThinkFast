import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsService {
  final CollectionReference _quizStats = FirebaseFirestore.instance.collection('quiz_stats');
  final CollectionReference _questionStats = FirebaseFirestore.instance.collection('quiz_question_stats');

  /// ✅ Get stats for a quiz
  Future<Map<String, dynamic>?> getQuizStats(String quizId) async {
    final doc = await _quizStats.doc(quizId).get();
    return doc.data() as Map<String, dynamic>?;
  }

  /// ✅ Stream stats for a quiz
  Stream<Map<String, dynamic>?> streamQuizStats(String quizId) {
    return _quizStats.doc(quizId).snapshots().map((doc) => doc.data() as Map<String, dynamic>?);
  }

  /// ✅ Update question performance stats
  Future<void> updateQuestionStats({
    required String questionId,
    required String quizId,
    required bool isCorrect,
  }) async {
    await _questionStats.doc(questionId).set({
      'quizId': quizId,
      'attempts': FieldValue.increment(1),
      'correct': isCorrect ? FieldValue.increment(1) : FieldValue.increment(0),
      'wrong': isCorrect ? FieldValue.increment(0) : FieldValue.increment(1),
    }, SetOptions(merge: true));
  }
}
