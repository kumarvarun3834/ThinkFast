import 'package:cloud_firestore/cloud_firestore.dart';

class QuizService {
  final CollectionReference _quizzes = FirebaseFirestore.instance.collection(
    'quizzes',
  );
  final CollectionReference _questions = FirebaseFirestore.instance.collection(
    'quiz_questions',
  );
  final CollectionReference _answerKeys = FirebaseFirestore.instance.collection(
    'answer_keys',
  );

  /// ✅ Create a new Quiz (Metadata, Questions, and Answers stored separately)
  Future<String> createQuiz({
    required String creatorId,
    required String user,
    required String title,
    required String description,
    required String visibility,
    required List<Map<String, dynamic>> questions,
    required List<Map<String, String>> answerKeys,
    required int timeInSeconds,
    Map<String, dynamic>? markingScheme,
    bool allowMultipleAttempts = true,
    List<String>? tags,
  }) async {
    // 1. Create the Quiz Metadata document
    final docRef = await _quizzes.add({
      'creatorId': creatorId,
      'user': user,
      'title': title,
      'titleLower': title.toLowerCase(),
      'description': description,
      'tags': tags ?? [],
      'visibility': visibility,
      'time': timeInSeconds,
      'allowMultipleAttempts': allowMultipleAttempts,
      'markingScheme': markingScheme ?? {'type': 'default'},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isRestricted': false,
      'isDeleted': false,
    });

    final String quizId = docRef.id;

    // 2. Create the Questions document (Separate collection)
    await _questions.doc(quizId).set({
      'quizId': quizId,
      'modules': questions,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 3. Create the Answer Key (Separate collection for maximum security)
    await _answerKeys.doc(quizId).set({
      'quizId': quizId,
      'answerkeys': answerKeys,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return quizId;
  }

  /// ✅ Fetch Questions for a Quiz
  Future<List<Map<String, dynamic>>> getQuizQuestions(String quizId) async {
    final doc = await _questions.doc(quizId).get();
    if (!doc.exists) return [];
    final data = doc.data() as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['modules'] ?? []);
  }

  /// ✅ Update Quiz Metadata
  Future<void> updateQuiz({
    required String quizId,
    Map<String, dynamic>? updates,
  }) async {
    if (updates == null) return;

    // Split updates between metadata and questions if 'modules' is present
    if (updates.containsKey('modules')) {
      final questionsData = updates.remove('modules');
      await _questions.doc(quizId).update({
        'modules': questionsData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    if (updates.isNotEmpty) {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _quizzes.doc(quizId).update(updates);
    }
  }

  /// ✅ Fetch Answer Keys (Only for validation or creator)
  Future<List<Map<String, dynamic>>?> getAnswerKeys(String quizId) async {
    final doc = await _answerKeys.doc(quizId).get();
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['answerkeys'] ?? []);
  }

  /// ✅ Fetch Quiz Metadata
  Future<Map<String, dynamic>?> getQuiz(String quizId) async {
    final doc = await _quizzes.doc(quizId).get();
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return data;
  }

  /// ✅ Fetch Public Quizzes
  Stream<List<Map<String, dynamic>>> getPublicQuizzes() {
    return _quizzes
        .where('visibility', isEqualTo: 'public')
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// ✅ Fetch My Quizzes
  Stream<List<Map<String, dynamic>>> getMyQuizzes(String creatorId) {
    return _quizzes
        .where('creatorId', isEqualTo: creatorId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// ✅ Delete Quiz (Soft Delete)
  Future<void> deleteQuiz(String quizId, String userId) async {
    await _quizzes.doc(quizId).update({
      'isDeleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// ✅ Update Answer Keys
  Future<void> updateAnswerKeys({
    required String quizId,
    required List<Map<String, String>> answerKeys,
  }) async {
    await _answerKeys.doc(quizId).update({
      'answerkeys': answerKeys,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
