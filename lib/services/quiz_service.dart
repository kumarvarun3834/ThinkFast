import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

import 'admin_service.dart';
import 'settings_service.dart';

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
  final CollectionReference _users = FirebaseFirestore.instance.collection(
    'users',
  );
  final CollectionReference _tags = FirebaseFirestore.instance.collection(
    'tags',
  );
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
    required List<Map<String, dynamic>> answerKeys,
    required int timeInSeconds,
    Map<String, dynamic>? markingScheme,
    Map<String, dynamic>? attemptLimits,
    bool allowMultipleAttempts = true,
    bool completeRandomShuffle = false,
    int perQuestionTime = 0,
    List<String>? tags,
    DateTime? activeAt,
    bool isRestricted = false,
    List<String>? allowedParticipants,
    bool isPersonal = false,
    bool isAiGenerated = false,
    int? totalQuestions,
    int? moduleCount,
    String? markingType,
    String? attemptLimitType,
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

    // 2. Fetch Feature Flags and Admin Status
    final flags = await _settingsService.getFeatureFlags();
    final bool isUserAdmin =
        await _adminService.isAdmin(creatorId) ||
        await _adminService.isRegisteredAdmin(creatorId);

    // Check if quiz creation is globally disabled
    if (flags != null && flags['enable_create_quiz'] == false) {
      if (!isUserAdmin) {
        throw Exception(
          "Quiz creation is currently disabled by the administrator.",
        );
      }
    }

    final bool rateLimitEnabled =
        flags?['enable_quiz_creation_rate_limit'] ?? true;
    final int rateLimitMinutes =
        (flags?['quiz_creation_rate_limit_minutes'] ?? 5).toInt();

    // 3. Rate Limit Check (Only if enabled and user is not admin)
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
            throw Exception(
              "Rate limit exceeded. Please wait $waitTime minutes before creating another quiz.",
            );
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
      'perQuestionTime': perQuestionTime,
      'allowMultipleAttempts': allowMultipleAttempts,
      'completeRandomShuffle': completeRandomShuffle,
      'markingScheme': markingScheme ?? {'type': 'default'},
      'attemptLimits': attemptLimits ?? {'type': 'none'},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'activeAt': activeAt != null ? Timestamp.fromDate(activeAt) : null,
      'isRestricted': isRestricted,
      'allowedParticipants': allowedParticipants ?? [],
      'isPersonal': isPersonal,
      'isAiGenerated': isAiGenerated,
      'totalQuestions': totalQuestions ?? 0,
      'moduleCount': moduleCount ?? 0,
      'markingType': markingType ?? 'default',
      'attemptLimitType': attemptLimitType ?? 'none',
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

    // 5. Sync Tags to global tags collection
    if (tags != null && tags.isNotEmpty) {
      for (var tag in tags) {
        batch.set(_tags.doc(tag.toLowerCase().trim()), {
          'name': tag.trim(),
          'lastUsed': FieldValue.serverTimestamp(),
          'count': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }
    }

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
      if (updates.containsKey('tags')) {
        final List<String> tags = List<String>.from(updates['tags'] ?? []);
        for (var tag in tags) {
          await _tags.doc(tag.toLowerCase().trim()).set({
            'name': tag.trim(),
            'lastUsed': FieldValue.serverTimestamp(),
            'count': FieldValue.increment(1),
          }, SetOptions(merge: true));
        }
      }
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
    final quizDoc = await _quizzes.doc(quizId).get();
    if (!quizDoc.exists) throw Exception("Quiz not found");

    final data = quizDoc.data() as Map<String, dynamic>;
    String deletedByType = 'system';

    // Attribution logic: Prioritize Quiz Permissions
    if (data['creatorId'] == userId) {
      deletedByType = 'owner';
    } else if (await _adminService.canManageQuiz(quizId, userId)) {
      deletedByType = 'manager';
    } else if (await _adminService.isAdmin(userId)) {
      deletedByType = 'admin';
    }

    await _quizzes.doc(quizId).update({
      'isDeleted': true,
      'deletedBy': userId,
      'deletedByType': deletedByType,
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _adminService.logAction(
      actorId: userId,
      action: 'delete_quiz',
      targetId: quizId,
      details: 'Soft deleted quiz by $deletedByType',
      category: 'quiz',
    );
  }

  /// ✅ Restore Quiz
  Future<void> restoreQuiz(String quizId, String userId) async {
    final quizDoc = await _quizzes.doc(quizId).get();
    if (!quizDoc.exists) throw Exception("Quiz not found");
    final data = quizDoc.data() as Map<String, dynamic>;

    if (data['creatorId'] != userId) {
      final isAdmin = await _adminService.isAdmin(userId);
      if (!isAdmin) throw Exception("Unauthorized to restore this quiz");
    }

    final Timestamp? deletedAt = data['deletedAt'];
    if (deletedAt != null) {
      final expiry = deletedAt.toDate().add(const Duration(days: 7));
      if (DateTime.now().isAfter(expiry)) {
        throw Exception("Recovery window expired (7 days passed)");
      }
    }

    await _quizzes.doc(quizId).update({
      'isDeleted': false,
      'deletedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _adminService.logAction(
      actorId: userId,
      action: 'restore_quiz',
      targetId: quizId,
      details: 'Restored quiz',
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
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList(),
        );
  }

  /// ✅ Fetch My Quizzes
  Stream<List<Map<String, dynamic>>> getMyQuizzes(String creatorId) {
    return _quizzes
        .where('creatorId', isEqualTo: creatorId)
        .where('isDeleted', isEqualTo: false)
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

  /// ✅ Fetch Managed Quizzes (Where user is a collaborator)
  Stream<List<Map<String, dynamic>>> getManagedQuizzes(String userId) {
    return FirebaseFirestore.instance
        .collection('quiz_access')
        .where('userId', isEqualTo: userId)
        .where('role', isEqualTo: 'manager')
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.docs.isEmpty) return [];

          // Trigger all fetches in parallel to minimize sequential server hits
          final results = await Future.wait(
            snapshot.docs.map((doc) async {
              final quizId = doc.data()['quizId'];
              try {
                final quizDoc = await _quizzes.doc(quizId).get();
                if (quizDoc.exists) {
                  final data = quizDoc.data() as Map<String, dynamic>;
                  data['id'] = quizDoc.id;
                  return (data['isDeleted'] == false) ? data : null;
                }
              } catch (e) {
                debugPrint("Permission denied for quiz metadata: $quizId");
              }
              return null;
            }),
          );

          // Filter out nulls and return valid managed quizzes
          return results.whereType<Map<String, dynamic>>().toList();
        });
  }

  /// ✅ Fetch My Soft-Deleted Quizzes (Trash)
  Stream<List<Map<String, dynamic>>> getMyDeletedQuizzes(String creatorId) {
    return _quizzes
        .where('creatorId', isEqualTo: creatorId)
        .where('isDeleted', isEqualTo: true)
        .orderBy('deletedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList(),
        );
  }

  /// ✅ Check if user has access to a quiz
  Future<bool> hasAccess(String quizId, String userId) async {
    // 0. Check if user is banned
    final isBanned = await _adminService.isUserBanned(userId, quizId: quizId);
    if (isBanned) return false;

    final quiz = await getQuiz(quizId);
    if (quiz == null) return false;

    final bool isDeleted = quiz['isDeleted'] ?? false;
    final isAdmin = await _adminService.isAdmin(userId);

    // If quiz is soft-deleted, only admins can access it.
    // Owners and regular users are blocked.
    if (isDeleted && !isAdmin) return false;

    if (quiz['visibility'] == 'public') return true;
    if (quiz['creatorId'] == userId) return true;

    if (isAdmin) return true;

    final access = await FirebaseFirestore.instance
        .collection('quiz_access')
        .doc('${quizId}_$userId')
        .get();
    return access.exists;
  }

  /// ✅ Update Answer Keys
  Future<void> updateAnswerKeys({
    required String quizId,
    required String userId,
    required List<Map<String, dynamic>> answerKeys,
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
