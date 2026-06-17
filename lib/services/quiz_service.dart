import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_service.dart';
import 'settings_service.dart';

class QuizService {
  final CollectionReference _quizzes = FirebaseFirestore.instance.collection('quizzes');
  final CollectionReference _questions = FirebaseFirestore.instance.collection('quiz_questions');
  final CollectionReference _answerKeys = FirebaseFirestore.instance.collection('answer_keys');
  final CollectionReference _users = FirebaseFirestore.instance.collection('users');
  final AdminService _adminService = AdminService();
  final SettingsService _settingsService = SettingsService();

  /// ✅ Create a new Quiz with Idempotency and Configurable Rate Limiting
  Future<String> createQuiz({
    String? clientToken,
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
    // 1. Idempotency Check
    if (clientToken != null) {
      final existing = await _quizzes
          .where('creatorId', isEqualTo: creatorId)
          .where('clientToken', isEqualTo: clientToken)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return existing.docs.first.id;
      }
    }

    // 2. Fetch Feature Flags for Rate Limiting
    final flags = await _settingsService.getFeatureFlags();
    final bool rateLimitEnabled = flags?['enable_quiz_creation_rate_limit'] ?? true;
    final int rateLimitMinutes = (flags?['quiz_creation_rate_limit_minutes'] ?? 5).toInt();

    // 3. Rate Limit Check (Only if enabled and user is not admin)
    bool isUserAdmin = await _adminService.isAdmin(creatorId);
    
    if (rateLimitEnabled && !isUserAdmin) {
      final userDoc = await _users.doc(creatorId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final Timestamp? lastCreated = userData['lastQuizCreatedAt'];
        
        if (lastCreated != null) {
          final lastTime = lastCreated.toDate();
          final now = DateTime.now();
          final difference = now.difference(lastTime);

          if (difference.inMinutes < rateLimitMinutes) {
            final waitTime = rateLimitMinutes - difference.inMinutes;
            throw Exception("Rate limit exceeded. Please wait $waitTime minutes before creating another quiz.");
          }
        }
      }
    }

    // 4. Prepare Creation
    final DocumentReference quizRef = _quizzes.doc();
    final String targetQuizId = quizRef.id;
    final WriteBatch batch = FirebaseFirestore.instance.batch();

    batch.set(quizRef, {
      'creatorId': creatorId,
      'clientToken': clientToken,
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

    batch.set(_questions.doc(targetQuizId), {
      'quizId': targetQuizId,
      'modules': questions,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(_answerKeys.doc(targetQuizId), {
      'quizId': targetQuizId,
      'answerkeys': answerKeys,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(_users.doc(creatorId), {
      'lastQuizCreatedAt': FieldValue.serverTimestamp(),
      'quizCount': FieldValue.increment(1),
    });

    await batch.commit();

    await _adminService.logAction(
      actorId: creatorId,
      action: 'create_quiz',
      targetId: targetQuizId,
      details: 'Created quiz: $title',
      category: 'quiz',
    );

    return targetQuizId;
  }

  /// ✅ Update Quiz Metadata
  Future<void> updateQuiz({
    required String quizId,
    required String userId,
    Map<String, dynamic>? updates,
  }) async {
    if (updates == null || updates.isEmpty) return;

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

    await _adminService.logAction(
      actorId: userId,
      action: 'update_quiz',
      targetId: quizId,
      details: 'Updated fields: ${updates.keys.toList()}',
      category: 'quiz',
    );
  }

  /// ✅ Delete Quiz (Soft Delete)
  Future<void> deleteQuiz(String quizId, String userId) async {
    await _quizzes.doc(quizId).update({
      'isDeleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _adminService.logAction(
      actorId: userId,
      action: 'delete_quiz',
      targetId: quizId,
      details: 'Soft deleted quiz',
      category: 'quiz',
    );
  }

  /// ✅ Fetch Answer Keys
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

  /// ✅ Fetch Questions for a Quiz
  Future<List<Map<String, dynamic>>> getQuizQuestions(String quizId) async {
    final doc = await _questions.doc(quizId).get();
    if (!doc.exists) return [];
    final data = doc.data() as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['modules'] ?? []);
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

  /// ✅ Check if user has access to a quiz
  Future<bool> hasAccess(String quizId, String userId) async {
    final quiz = await getQuiz(quizId);
    if (quiz == null) return false;

    if (quiz['visibility'] == 'public') return true;
    if (quiz['creatorId'] == userId) return true;

    final isAdmin = await _adminService.isAdmin(userId);
    if (isAdmin) return true;

    final access = await FirebaseFirestore.instance.collection('quiz_access').doc('${quizId}_$userId').get();
    return access.exists;
  }

  /// ✅ Update Answer Keys
  Future<void> updateAnswerKeys({
    required String quizId,
    required String userId,
    required List<Map<String, String>> answerKeys,
  }) async {
    await _answerKeys.doc(quizId).update({
      'answerkeys': answerKeys,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _adminService.logAction(
      actorId: userId,
      action: 'update_answer_keys',
      targetId: quizId,
      details: 'Updated answer keys for quiz',
      category: 'quiz',
    );
  }
}
