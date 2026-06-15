import 'package:cloud_firestore/cloud_firestore.dart';

class AttemptService {
  final CollectionReference _responses = FirebaseFirestore.instance.collection('responses');
  final CollectionReference _allAttempts = FirebaseFirestore.instance.collection('all_attempts');
  final CollectionReference _quizAttempts = FirebaseFirestore.instance.collection('quiz_attempts');

  /// ✅ Calculate score and submit attempt
  Future<String> submitScoredAttempt({
    required String userId,
    required String quizId,
    required String quizTitle,
    required int totalQuestions,
    required Map<String, dynamic> userAnswers,
    required Map<String, List<String>> correctKey,
    required Map<String, dynamic> markingScheme,
    required List<dynamic> quizData,
  }) async {
    int score = 0;

    // Helper to get marking for a question
    Map<String, int> getMarking(String? type, String qUid) {
      final schemeType = markingScheme['type'] ?? 'default';
      if (schemeType == 'entire_quiz') {
        return {
          'correct': (markingScheme['global']?['correct'] ?? 4).toInt(),
          'wrong': (markingScheme['global']?['wrong'] ?? -1).toInt(),
        };
      } else if (schemeType == 'per_question_type') {
        final pqt = markingScheme['perQuestionType'] as Map? ?? {};
        final config = pqt[type] ?? pqt['Single Choice'] ?? {'correct': 4, 'wrong': -1};
        return {
          'correct': (config['correct'] ?? 4).toInt(),
          'wrong': (config['wrong'] ?? -1).toInt(),
        };
      } else if (schemeType == 'per_question') {
        final pq = markingScheme['perQuestion'] as Map? ?? {};
        final config = pq[qUid] ?? {'correct': 4, 'wrong': -1};
        return {
          'correct': (config['correct'] ?? 4).toInt(),
          'wrong': (config['wrong'] ?? -1).toInt(),
        };
      }
      return {'correct': 4, 'wrong': -1};
    }

    userAnswers.forEach((qUid, selections) {
      final correct = correctKey[qUid] ?? [];
      final List selected = selections is List ? selections : [selections.toString()];

      // Find question type
      String? qType;
      try {
        final qDoc = quizData.firstWhere((q) => (q['Q']?['id'] ?? q['uid']) == qUid);
        qType = qDoc['type'];
      } catch (_) {}

      final marking = getMarking(qType, qUid);

      if (selected.isNotEmpty &&
          selected.length == correct.length &&
          selected.every((s) => correct.contains(s))) {
        score += marking['correct']!; // Correct
      } else if (selected.isNotEmpty) {
        score += marking['wrong']!; // Wrong
      }
    });

    return await submitAttempt(
      userId: userId,
      quizId: quizId,
      quizTitle: quizTitle,
      score: score,
      totalQuestions: totalQuestions,
      answers: userAnswers,
    );
  }

  /// ✅ Submit a new quiz attempt

  Future<String> submitAttempt({
    required String userId,
    required String quizId,
    required String quizTitle,
    required int score,
    required int totalQuestions,
    required Map<String, dynamic> answers,
  }) async {
    final attemptData = {
      'userId': userId,
      'quizId': quizId,
      'quizTitle': quizTitle,
      'score': score,
      'totalQuestions': totalQuestions,
      'answers': answers,
      'status': 1, // Completed
      'timestamp': FieldValue.serverTimestamp(),
    };

    final batch = FirebaseFirestore.instance.batch();

    // 1. Save to 'responses' (Personal/Global reporting)
    final responseRef = _responses.doc();
    batch.set(responseRef, attemptData);

    // 2. Save to 'all_attempts' (Global Log)
    final allAttemptRef = _allAttempts.doc(responseRef.id);
    batch.set(allAttemptRef, attemptData);

    // 3. Save to 'quiz_attempts' (Creator Dashboard)
    final quizAttemptRef = _quizAttempts
        .doc(quizId)
        .collection('attempts')
        .doc(responseRef.id);
    batch.set(quizAttemptRef, attemptData);

    // 4. Update user last active and attempt count, and clear activeQuizId
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    batch.set(userRef, {
      'lastActive': FieldValue.serverTimestamp(),
      'attemptCount': FieldValue.increment(1),
    }, SetOptions(merge: true));

    final userPrivateRef = userRef.collection('private').doc('details');
    batch.set(userPrivateRef, {
      'activeQuizId': FieldValue.delete(),
      'activeQuizExpiry': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
    return responseRef.id;
  }

  /// ✅ Stream attempts for a specific user
  Stream<List<Map<String, dynamic>>> getUserAttempts(String userId) {
    return _responses
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// ✅ Stream attempts for a specific quiz (for Creators)
  Stream<List<Map<String, dynamic>>> getQuizAttempts(String quizId) {
    return _quizAttempts
        .doc(quizId)
        .collection('attempts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }
}
