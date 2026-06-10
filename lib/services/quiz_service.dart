import 'package:cloud_firestore/cloud_firestore.dart';

class QuizService {
  final CollectionReference _quizzes = FirebaseFirestore.instance.collection('quizzes');
  final CollectionReference _answerKeys = FirebaseFirestore.instance.collection('answer_keys');

  /// ✅ Create a new Quiz (Includes Answer Keys)
  Future<String> createQuiz({
    required String creatorId,
    required String user,
    required String title,
    required String description,
    required String visibility,
    required List<Map<String, dynamic>> questions,
    required List<Map<String, String>> answerKeys,
    required int timeInSeconds,
    List<String>? tags,
  }) async {
    // 1. Create the Quiz document
    final docRef = await _quizzes.add({
      'creatorId': creatorId,
      'user': user,
      'title': title,
      'titleLower': title.toLowerCase(),
      'description': description,
      'tags': tags ?? [],
      'visibility': visibility,
      'time': timeInSeconds,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isRestricted': false,
      'isDeleted': false,
      'data': questions, // Questions embedded per firebase.md
    });

    // 2. Create the Answer Key (Separate collection for security)
    await _answerKeys.doc(docRef.id).set({
      'quizId': docRef.id,
      'answerkeys': answerKeys,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
    /// ✅ Update Answer Keys
  Future<void> updateAnswerKeys({
    required String quizId,
    required List<Map<String, String>> answerKeys,
  }) async {
    await _answerKeys.doc(quizId).set({
      'quizId': quizId,
      'answerkeys': answerKeys,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

  /// ✅ Read all public quizzes
  Stream<List<Map<String, dynamic>>> getPublicQuizzes() {
    return _quizzes
        .where('isDeleted', isEqualTo: false)
        .where('visibility', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return data;
            }).toList());
    /// ✅ Update Answer Keys
  Future<void> updateAnswerKeys({
    required String quizId,
    required List<Map<String, String>> answerKeys,
  }) async {
    await _answerKeys.doc(quizId).set({
      'quizId': quizId,
      'answerkeys': answerKeys,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

  /// ✅ Read quizzes by creator
  Stream<List<Map<String, dynamic>>> getMyQuizzes(String uid) {
    return _quizzes
        .where('creatorId', isEqualTo: uid)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return data;
            }).toList());
    /// ✅ Update Answer Keys
  Future<void> updateAnswerKeys({
    required String quizId,
    required List<Map<String, String>> answerKeys,
  }) async {
    await _answerKeys.doc(quizId).set({
      'quizId': quizId,
      'answerkeys': answerKeys,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

  /// ✅ Get a single quiz
  Future<Map<String, dynamic>?> getQuiz(String quizId) async {
    final doc = await _quizzes.doc(quizId).get();
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return data;
    /// ✅ Update Answer Keys
  Future<void> updateAnswerKeys({
    required String quizId,
    required List<Map<String, String>> answerKeys,
  }) async {
    await _answerKeys.doc(quizId).set({
      'quizId': quizId,
      'answerkeys': answerKeys,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

  /// ✅ Soft delete a quiz
  Future<void> deleteQuiz(String quizId, String userId) async {
    await _quizzes.doc(quizId).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': userId,
    });
    /// ✅ Update Answer Keys
  Future<void> updateAnswerKeys({
    required String quizId,
    required List<Map<String, String>> answerKeys,
  }) async {
    await _answerKeys.doc(quizId).set({
      'quizId': quizId,
      'answerkeys': answerKeys,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

  /// ✅ Update quiz metadata and questions
  Future<void> updateQuiz({
    required String quizId,
    Map<String, dynamic>? updates,
  }) async {
    if (updates == null) return;
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _quizzes.doc(quizId).update(updates);
    /// ✅ Update Answer Keys
  Future<void> updateAnswerKeys({
    required String quizId,
    required List<Map<String, String>> answerKeys,
  }) async {
    await _answerKeys.doc(quizId).set({
      'quizId': quizId,
      'answerkeys': answerKeys,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

  /// ✅ Fetch Answer Keys (Only for validation or creator)
  Future<List<Map<String, dynamic>>?> getAnswerKeys(String quizId) async {
    final doc = await _answerKeys.doc(quizId).get();
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['answerkeys'] ?? []);
    /// ✅ Update Answer Keys
  Future<void> updateAnswerKeys({
    required String quizId,
    required List<Map<String, String>> answerKeys,
  }) async {
    await _answerKeys.doc(quizId).set({
      'quizId': quizId,
      'answerkeys': answerKeys,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
  /// ✅ Update Answer Keys
  Future<void> updateAnswerKeys({
    required String quizId,
    required List<Map<String, String>> answerKeys,
  }) async {
    await _answerKeys.doc(quizId).set({
      'quizId': quizId,
      'answerkeys': answerKeys,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
