import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../utils/global.dart' as global;
import '../admin_service.dart';
import '../attempt_service.dart';
import '../quiz_service.dart';
import '../settings_service.dart';
import '../user_service.dart';

/// 👤 Database Service for Normal User Operations
class UserDatabaseService {
  final UserService _userService = UserService();
  final QuizService _quizService = QuizService();
  final AttemptService _attemptService = AttemptService();
  final SettingsService _settingsService = SettingsService();
  final AdminService _adminService = AdminService();

  // --- App Initialization ---

  Future<void> initAppData(String uid) async {
    try {
      // 1. Fetch & Sync User Profile (Initial Setup to prevent missing document errors)
      var profile = await _userService.getUserProfile(uid);
      if (profile == null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _userService.createUserProfile(
            uid: uid,
            email: user.email ?? 'unknown',
            name: user.displayName,
            photoUrl: user.photoURL,
          );
          profile = await _userService.getUserProfile(uid);
        }
      }
      global.currentUserProfile = profile;

      // 2. Fetch Admin Status
      global.isRegisteredAdmin = await _adminService.isRegisteredAdmin(uid);
      global.isAdmin = await _adminService.isAdmin(uid);

      // 3. Fetch Feature Flags
      global.featureFlags = await _settingsService.getFeatureFlags(
        isAdmin: global.isAdmin,
      );

      // 4. Initialize AI Usage (Initial Setup for daily quota tracking)
      await global.aiConnect.getAiUsageToday(uid);

      // 5. Fetch Management & Access Records for Local Cache
      final accessRecords = await _adminService.getUserAccessRecords(uid);
      global.managedQuizzes = {
        for (var rec in accessRecords)
          if (rec['role'] == 'manager' && rec['quizId'] != null)
            rec['quizId']: Map<String, dynamic>.from(rec['permissions'] ?? {}),
      };

      // 6. Fetch Owned Quizzes (Just IDs for quick check)
      final myQuizzesSnapshot = await FirebaseFirestore.instance
          .collection('quizzes')
          .where('creatorId', isEqualTo: uid)
          .where('isDeleted', isEqualTo: false)
          .get();

      global.ownedQuizIds = myQuizzesSnapshot.docs.map((doc) => doc.id).toSet();
    } catch (e) {
      debugPrint("Error initializing app data: $e");
      rethrow;
    }
  }

  Future<void> _ensurePermission(String? flag, {String? userId}) async {
    final flags =
        global.featureFlags ??
        await _settingsService.getFeatureFlags(isAdmin: global.isAdmin);

    // 1. Global Maintenance Mode Check
    if (flags?['maintenance_mode'] == true) {
      bool isUserAdmin = false;
      if (userId != null) {
        isUserAdmin = await _adminService.isAdmin(userId);
      } else if (global.isAdmin) {
        isUserAdmin = true;
      }
      if (!isUserAdmin) {
        throw Exception(
          "System is currently under maintenance. Please try again later.",
        );
      }
    }

    // 2. Specific Feature Flag Check
    if (flag != null && flags?[flag] == false) {
      bool isUserAdmin = false;
      if (userId != null) {
        isUserAdmin = await _adminService.isAdmin(userId);
      } else if (global.isAdmin) {
        isUserAdmin = true;
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

  Future<bool> isAdmin(String uid) => _adminService.isAdmin(uid);

  Future<bool> isUserBanned(String uid, {String? quizId}) =>
      _adminService.isUserBanned(uid, quizId: quizId);

  Future<Map<String, dynamic>?> getFeatureFlags() =>
      _settingsService.getFeatureFlags(isAdmin: global.isAdmin);

  Future<void> updateProtectedDetails({
    required String uid,
    required Map<String, dynamic> details,
  }) async {
    await _ensurePermission(null, userId: uid);
    return _userService.updateProtectedDetails(uid: uid, details: details);
  }

  Future<bool> hasParticipantAccess(String quizId, String userId) async {
    await _ensurePermission(null, userId: userId);
    return _quizService.hasAccess(quizId, userId);
  }

  // --- Profile Management ---

  Future<void> createUserProfile({
    required String uid,
    required String email,
    String? name,
    String? photoUrl,
  }) async {
    await _ensurePermission(null, userId: uid);
    return _userService.createUserProfile(
      uid: uid,
      email: email,
      name: name,
      photoUrl: photoUrl,
    );
  }

  Future<Map<String, dynamic>?> getUserProfile(
    String uid, {
    String? actorId,
  }) async {
    await _ensurePermission(null, userId: actorId ?? uid);
    return _userService.getUserProfile(uid);
  }

  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? email,
  }) async {
    await _ensurePermission('enable_profile_edit', userId: uid);
    await _userService.updateUserProfile(uid: uid, name: name);
    if (email != null) {
      await _userService.updatePrivateDetails(uid: uid, email: email);
    }
  }

  // --- Quiz Session Management ---

  Future<void> updateActiveQuiz({
    required String uid,
    String? quizId,
    DateTime? expiry,
    bool clear = false,
  }) async {
    await _ensurePermission(null, userId: uid);
    return _userService.updatePrivateDetails(
      uid: uid,
      activeQuizId: quizId,
      activeQuizExpiry: expiry,
      clearActiveQuiz: clear,
    );
  }

  Future<void> handleExpiredQuiz(String uid, String quizId) async {
    try {
      Map<String, dynamic> quiz;
      try {
        quiz = await readDatabase(quizId, userId: uid);
      } catch (e) {
        quiz = {
          'id': quizId,
          'title': 'Unknown/Deleted Quiz ($quizId)',
          'modules': [],
          'markingScheme': {'type': 'default'},
        };
      }

      int totalCount = quiz['totalQuestions'] ?? 0;
      if (totalCount == 0) {
        final List<dynamic> rawModules = quiz['modules'] as List? ?? [];
        for (var module in rawModules) {
          final List<dynamic> questions = module['data'] as List? ?? [];
          totalCount += questions.length;
        }
      }

      await submitAttempt(
        userId: uid,
        quizId: quizId,
        quizTitle: quiz['title'] ?? 'Timed Out Quiz',
        totalQuestions: totalCount,
        userAnswers: {},
        correctKey: {},
        markingScheme: quiz['markingScheme'] ?? {'type': 'default'},
        quizData: [],
      );
    } catch (e) {
      await updateActiveQuiz(uid: uid, clear: true);
    }
  }

  // --- Quiz Viewing & Taking ---

  Stream<List<Map<String, dynamic>>> readAllDatabases({
    bool showMyQuizzes = false,
    bool showManagedQuizzes = false,
    bool showAiGenerations = false,
    bool showTrash = false,
    bool includeDeleted = false,
    String? creatorId,
    String? userId,
  }) {
    if (global.featureFlags?['maintenance_mode'] == true &&
        global.isAdmin == false) {
      return Stream.value([]);
    }

    if (showTrash && creatorId != null) {
      return _quizService.getMyDeletedQuizzes(creatorId);
    } else if (showAiGenerations && creatorId != null) {
      return _quizService.getMyAiQuizzes(creatorId);
    } else if (showMyQuizzes && creatorId != null) {
      if (includeDeleted) {
        return _quizService.getUserQuizzesMaster(creatorId);
      }
      return _quizService.getMyQuizzes(creatorId);
    } else if (showManagedQuizzes && userId != null) {
      return _quizService.getManagedQuizzes(userId);
    } else {
      return _quizService.getPublicQuizzes();
    }
  }

  Future<Map<String, dynamic>> readDatabase(
    String docId, {
    String? userId,
    bool skipAdminBypass = false,
  }) async {
    await _ensurePermission(null, userId: userId);
    final quiz = await _quizService.getQuiz(docId);
    if (quiz == null) throw Exception("Quiz not found");

    final bool isDeleted = quiz['isDeleted'] ?? false;
    bool isAdminUser = false;
    if (userId != null) {
      isAdminUser = await _adminService.isAdmin(userId);
    }

    if (isDeleted && !isAdminUser) throw Exception("Quiz not found");

    if (isAdminUser && quiz['creatorId'] != userId) {
      _adminService.logAction(
        actorId: userId!,
        action: 'see_quiz',
        targetId: docId,
        details: "Admin viewed quiz details: ${quiz['title']}",
        category: 'quiz',
      );
    }

    final String visibility = quiz['visibility'] ?? 'private';
    if (visibility != 'public' && !isAdminUser && quiz['creatorId'] != userId) {
      if (userId == null) {
        throw Exception("Access Denied: This quiz is private.");
      }
      final hasAccess = await _quizService.hasAccess(docId, userId);
      if (!hasAccess) {
        throw Exception("Access Denied: This quiz is private.");
      }
    }

    // Privacy Restraint: If skipAdminBypass is requested (e.g. by editor),
    // and the user is an admin but NOT an explicit manager, deny module content.
    if (skipAdminBypass && isAdminUser) {
      final bool isExplicitManager = await _adminService.canManageQuiz(
        docId,
        userId!,
        skipAdminCheck: true,
      );
      final bool hasPrivacyBypass = await _adminService.hasPermission(
        userId!,
        'bypass_quiz_privacy',
      );

      if (!isExplicitManager && !hasPrivacyBypass) {
        quiz['modules'] = [];
        quiz['internalAccessDenied'] = true;
        return quiz;
      }
    }

    try {
      final questions = await _quizService.getQuizQuestions(docId);
      for (var module in questions) {
        final List<dynamic> qList = module['data'] as List? ?? [];
        for (var q in qList) {
          if (q is Map) {
            q.remove('answers');
            q.remove('correct_answer');
            q.remove('answer');
          }
        }
      }
      quiz['modules'] = questions;
    } catch (e) {
      quiz['modules'] = [];
      quiz['questionsError'] = e.toString();
    }
    return quiz;
  }

  Future<Map<String, dynamic>> fetchAggregatedQuizDetails(
    String quizId, {
    String? userId,
  }) async {
    final results = await Future.wait([
      readDatabase(quizId, userId: userId),
      if (userId != null)
        hasUserAttemptedQuiz(userId, quizId)
      else
        Future.value(false),
      if (userId != null) isAdmin(userId) else Future.value(false),
      if (userId != null)
        getUserProfile(userId, actorId: userId)
      else
        Future.value(null),
    ], eagerError: false);

    final Map<String, dynamic> quizData = results[0] as Map<String, dynamic>;
    quizData['hasAttempted'] = results[1] as bool;
    quizData['isAdmin'] = results[2] as bool;
    quizData['userProfile'] = results[3];

    if (quizData['creatorId'] != null) {
      try {
        quizData['creatorProfile'] = await getUserProfile(
          quizData['creatorId'],
          actorId: userId,
        );
      } catch (_) {}
    }

    quizData['canManage'] =
        global.ownedQuizIds.contains(quizId) ||
        global.managedQuizzes.containsKey(quizId) ||
        (quizData['isAdmin'] == true);

    return quizData;
  }

  Future<Map<String, dynamic>> getQuizAnswers(
    String docId,
    String userId, {
    String? from,
    int? totalQuestions,
    Map<String, dynamic>? userAnswers,
    List<String>? reviewItems,
    List<String>? questionOrder,
    List<String>? visitedItems,
  }) async {
    await _ensurePermission('enable_take_quiz', userId: userId);
    final quiz = await _quizService.getQuiz(docId);
    if (quiz == null) throw Exception("Quiz not found");

    final bool isDeleted = quiz['isDeleted'] ?? false;
    final bool isAdminUser = await _adminService.isAdmin(userId);
    if (isDeleted && !isAdminUser) throw Exception("Quiz not found");

    final bool isCreator = quiz['creatorId'] == userId;

    // Privacy Restraint: Platform admins cannot see answers in editor unless they are managers or have privacy bypass.
    if (from == 'quizform') {
      final bool isExplicitManager = await _adminService.canManageQuiz(
        docId,
        userId,
        skipAdminCheck: true,
      );
      final bool hasPrivacyBypass = await _adminService.hasPermission(
        userId,
        'bypass_quiz_privacy',
      );

      if (!isExplicitManager && isAdminUser && !hasPrivacyBypass) {
        throw Exception(
          "Access Denied: Platform Administrators cannot access internal answer keys without explicit management permissions or 'bypass_quiz_privacy' enabled.",
        );
      }
      if (!isCreator && !isExplicitManager && !hasPrivacyBypass) {
        throw Exception(
          "Only the creator, authorized managers, or admins with privacy bypass can access answers in the editor.",
        );
      }
    }

    final keysList = await _quizService.getAnswerKeys(docId);
    if (keysList == null) throw Exception("Answers not found");

    final Map<String, List<String>> correctKey = {};
    final Map<String, String> solutions = {};

    for (var entry in keysList) {
      final qUid = entry['q'].toString();
      final optUid = entry['a'].toString();
      if (optUid != '__desc__')
        correctKey.putIfAbsent(qUid, () => []).add(optUid);
      if (entry.containsKey('s')) solutions[qUid] = entry['s'].toString();
    }

    Map<String, dynamic>? submissionResult;

    if (from == 'quizform') {
      // Logic already handled above in Privacy Restraint block
    } else if (userAnswers != null && totalQuestions != null) {
      final questions = await _quizService.getQuizQuestions(docId);
      final List<Map<String, dynamic>> flattenedQuestions = [];
      for (var module in questions) {
        final List<dynamic> qList = module['data'] as List? ?? [];
        for (var q in qList) {
          flattenedQuestions.add(Map<String, dynamic>.from(q));
        }
      }

      final String attemptId = await _attemptService.submitAttempt(
        userId: userId,
        quizId: docId,
        quizTitle: quiz['title'] ?? 'Untitled Quiz',
        totalQuestions: totalQuestions,
        userAnswers: userAnswers,
        correctKey: correctKey,
        markingScheme: quiz['markingScheme'] ?? {'type': 'default'},
        quizData: flattenedQuestions,
        reviewItems: reviewItems,
        questionOrder: questionOrder,
        visitedItems: visitedItems,
      );

      submissionResult = {'id': attemptId};
    }
    return {
      'answers': correctKey,
      'solutions': solutions,
      'submission': ?submissionResult,
    };
  }

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
    List<String>? visitedItems,
  }) async {
    await _ensurePermission('enable_take_quiz', userId: userId);
    return _attemptService.submitAttempt(
      userId: userId,
      quizId: quizId,
      quizTitle: quizTitle,
      totalQuestions: totalQuestions,
      userAnswers: userAnswers,
      correctKey: correctKey,
      markingScheme: markingScheme,
      quizData: quizData,
      reviewItems: reviewItems,
      questionOrder: questionOrder,
      visitedItems: visitedItems,
    );
  }

  // --- History ---

  Stream<List<Map<String, dynamic>>> getUserAttempts(
    String userId, {
    bool includeDeleted = false,
  }) {
    if (global.featureFlags?['maintenance_mode'] == true &&
        global.isAdmin == false) {
      return Stream.value([]);
    }
    return _attemptService.getUserAttempts(
      userId,
      includeDeleted: includeDeleted,
    );
  }

  Stream<List<Map<String, dynamic>>> getQuizResponses(
    String quizId, {
    bool includeDeleted = false,
  }) {
    if (global.featureFlags?['maintenance_mode'] == true &&
        global.isAdmin == false) {
      return Stream.value([]);
    }
    return _attemptService.getQuizAttempts(
      quizId,
      includeDeleted: includeDeleted,
    );
  }

  Future<bool> hasUserAttemptedQuiz(String userId, String quizId) async {
    await _ensurePermission(null, userId: userId);
    final attempts = await FirebaseFirestore.instance
        .collection('responses')
        .where('userId', isEqualTo: userId)
        .where('quizId', isEqualTo: quizId)
        .limit(1)
        .get();
    return attempts.docs.isNotEmpty;
  }

  // --- Content Reporting (UGC Compliance) ---

  Future<void> reportContent({
    required String reporterId,
    required String targetType, // 'quiz' or 'question'
    required String quizId,
    String? questionId,
    required String reason,
    String? details,
  }) async {
    await _ensurePermission(null, userId: reporterId);
    final reportData = {
      'reporterId': reporterId,
      'targetType': targetType,
      'quizId': quizId,
      'questionId': questionId,
      'reason': reason,
      'details': details,
      'status': 'pending', // pending, reviewed, resolved, dismissed
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Remove null entries
    reportData.removeWhere((key, value) => value == null);

    await FirebaseFirestore.instance
        .collection('content_reports')
        .add(reportData);

    // Log the report action for admins
    await _adminService.logAction(
      actorId: reporterId,
      action: 'report_content',
      targetId: targetType == 'quiz' ? quizId : (questionId ?? quizId),
      details: 'Type: $targetType, Reason: $reason',
      category: 'moderation',
    );
  }
}
