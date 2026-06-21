import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_service.dart';

class AttemptService {
  final CollectionReference _responses = FirebaseFirestore.instance.collection(
    'responses',
  );
  final CollectionReference _quizAttempts = FirebaseFirestore.instance
      .collection('quiz_attempts');
  final AdminService _adminService = AdminService();

  /// ✅ Unified submission (Scoring + 2-Way Storage + Metadata) in 1 stream
  Future<String> submitAttempt({
    required String userId,
    required String quizId,
    required String quizTitle,
    required int totalQuestions,
    required Map<String, dynamic> userAnswers,
    required Map<String, List<String>> correctKey,
    required Map<String, dynamic> markingScheme,
    required List<dynamic> quizData,
    List<String>? reviewItems,
    List<String>? questionOrder,
  }) async {
    // 1. Calculate Score
    int score = 0;

    Map<String, int> getMarking(String? type, String qUid) {
      final schemeType = markingScheme['type'] ?? 'default';
      if (schemeType == 'entire_quiz') {
        return {
          'correct': (markingScheme['global']?['correct'] ?? 4).toInt(),
          'wrong': (markingScheme['global']?['wrong'] ?? -1).toInt(),
        };
      } else if (schemeType == 'per_question_type') {
        final pqt = markingScheme['perQuestionType'] as Map? ?? {};
        final config =
            pqt[type] ?? pqt['Single Choice'] ?? {'correct': 4, 'wrong': -1};
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
      final List selected =
          selections is List ? selections : [selections.toString()];

      String? qType;
      try {
        final qDoc = quizData.firstWhere(
          (q) => (q['Q']?['id'] ?? q['uid']) == qUid,
        );
        qType = qDoc['type'];
      } catch (_) {}

      final marking = getMarking(qType, qUid);

      if (qType == "Integer") {
        final String userVal =
            selected.isNotEmpty ? selected.first.toString().trim() : "";
        final String correctVal =
            correct.isNotEmpty ? correct.first.toString().trim() : "";

        if (userVal.isNotEmpty && userVal == correctVal) {
          score += marking['correct']!;
        } else if (userVal.isNotEmpty) {
          score += marking['wrong']!;
        }
      } else if (selected.isNotEmpty &&
          selected.length == correct.length &&
          selected.every((s) => correct.contains(s))) {
        score += marking['correct']!;
      } else if (selected.isNotEmpty) {
        score += marking['wrong']!;
      }
    });

    // 2. Prepare Data
    final attemptData = {
      'userId': userId,
      'quizId': quizId,
      'quizTitle': quizTitle,
      'score': score,
      'totalQuestions': totalQuestions,
      'answers': userAnswers,
      'reviewItems': reviewItems ?? [],
      'questionOrder': questionOrder ?? [],
      'status': 1,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // 3. Batch Write (Unified Stream)
    final batch = FirebaseFirestore.instance.batch();

    // Store in global responses (Primary - for user history)
    final responseRef = _responses.doc();
    batch.set(responseRef, attemptData);

    // Store in quiz-specific attempts (Secondary/Foreign Key - for moderators)
    final quizAttemptRef = _quizAttempts
        .doc(quizId)
        .collection('attempts')
        .doc(responseRef.id);
    batch.set(quizAttemptRef, {
      ...attemptData,
      'responseId': responseRef.id, // Explicit Foreign Key reference
    });

    // User metadata updates
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    batch.set(userRef, {
      'lastActive': FieldValue.serverTimestamp(),
      'attemptCount': FieldValue.increment(1),
    }, SetOptions(merge: true));

    // Session cleanup
    final userPrivateRef = userRef.collection('private').doc('details');
    batch.set(userPrivateRef, {
      'activeQuizId': FieldValue.delete(),
      'activeQuizExpiry': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();

    // Log the successful batch
    await _adminService.logAction(
      actorId: userId,
      action: 'submit_attempt',
      targetId: quizId,
      details: 'Score: $score/$totalQuestions in $quizTitle',
      category: 'quiz',
    );

    return responseRef.id;
  }

  /// ✅ Stream attempts for a specific user (Primary storage)
  Stream<List<Map<String, dynamic>>> getUserAttempts(
    String userId, {
    bool includeDeleted = false,
  }) {
    return _responses
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList();

          if (includeDeleted) return docs;
          return docs.where((doc) => doc['isDeleted'] != true).toList();
        });
  }

  /// ✅ Stream attempts for a specific quiz (Secondary/Moderator view)
  Stream<List<Map<String, dynamic>>> getQuizAttempts(
    String quizId, {
    bool includeDeleted = false,
  }) {
    return _quizAttempts
        .doc(quizId)
        .collection('attempts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList();

          if (includeDeleted) return docs;
          return docs.where((doc) => doc['isDeleted'] != true).toList();
        });
  }
}
