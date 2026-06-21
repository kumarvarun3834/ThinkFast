import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/global.dart' as global;
import 'admin_service.dart';
import 'attempt_service.dart';
import 'quiz_service.dart';
import 'settings_service.dart';
import 'user_service.dart';

/// 🚀 Unified Database Service (Facade for specialized services)
class DatabaseService {
  final UserService _userService = UserService();
  final QuizService _quizService = QuizService();
  final AttemptService _attemptService = AttemptService();
  final SettingsService _settingsService = SettingsService();
  final AdminService _adminService = AdminService();

  // --- App Initialization ---

  Future<void> initAppData(String uid) async {
    try {
      // 1. Fetch Profile
      global.currentUserProfile = await _userService.getUserProfile(uid);

      // 2. Fetch Admin Status
      global.isRegisteredAdmin = await _adminService.isRegisteredAdmin(uid);
      global.isAdmin = await _adminService.isAdmin(uid);

      // 3. Fetch Feature Flags
      global.featureFlags = await _settingsService.getFeatureFlags();
    } catch (e) {
      print("Error initializing app data: $e");
    }
  }

  Future<Map<String, dynamic>?> getFeatureFlags() =>
      _settingsService.getFeatureFlags();

  /// 🔐 Helper to check global feature flags and admin overrides
  Future<void> _ensurePermission(String? flag, {String? userId}) async {
    final flags =
        global.featureFlags ?? await _settingsService.getFeatureFlags();

    // 1. Global Maintenance Mode Check
    if (flags?['maintenance_mode'] == true) {
      bool isUserAdmin = false;
      if (userId != null) {
        // All admins (Level 1+) can bypass maintenance check if admin mode is ON
        isUserAdmin = await _adminService.isAdmin(userId);
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
        // Levels 1-10 can bypass feature flags if admin mode is ON
        isUserAdmin = await _adminService.isAdmin(userId);
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

  /// 🔐 Helper to check required admin level for sensitive operations
  Future<void> _ensureAdminLevel(String userId, int requiredLevel) async {
    if (!await _adminService.hasRequiredLevel(userId, requiredLevel)) {
      throw Exception(
        "Access Denied: Administrative level $requiredLevel or higher required (and Admin Mode must be ON).",
      );
    }
  }

  // --- Admin & Experience Switching ---

  Future<bool> isRegisteredAdmin(String uid) =>
      _adminService.isRegisteredAdmin(uid);

  Future<bool> isAdmin(String uid) => _adminService.isAdmin(uid);

  Future<void> toggleAdminMode({required String uid, required bool enable}) =>
      _adminService.toggleAdminMode(uid: uid, enable: enable);

  // --- Quiz Moderation & Management ---

  Future<void> banUser({
    required String userId,
    String? quizId,
    required String reason,
    required String adminId,
  }) async {
    await _ensureAdminLevel(adminId, 5); // Level 5+ for global bans
    return _adminService.banUser(
      userId: userId,
      quizId: quizId,
      reason: reason,
      adminId: adminId,
    );
  }

  Future<void> softDeleteResponse({
    required String responseId,
    required String quizId,
    required String actorId,
    required String reason,
  }) async {
    // Permission check is now inside adminService.softDeleteResponse
    return _adminService.softDeleteResponse(
      responseId: responseId,
      quizId: quizId,
      actorId: actorId,
      reason: reason,
    );
  }

  Future<void> restoreResponse({
    required String responseId,
    required String quizId,
  }) async {
    return _adminService.restoreResponse(
      responseId: responseId,
      quizId: quizId,
    );
  }

  Future<void> grantManagementAccess({
    required String quizId,
    required String userId,
    required Map<String, bool> permissions,
    required String addedBy,
  }) async {
    await _ensureAdminLevel(addedBy, 2); // Level 2+ for collabs
    await _ensurePermission('management_features', userId: addedBy);
    return _adminService.grantQuizManagementAccess(
      quizId: quizId,
      userId: userId,
      permissions: permissions,
      addedBy: addedBy,
    );
  }

  Future<void> addParticipant({
    required String quizId,
    required String userId,
    required String addedBy,
  }) async {
    await _ensureAdminLevel(addedBy, 2);
    await _ensurePermission('management_features', userId: addedBy);
    return _adminService.addParticipant(
      quizId: quizId,
      userId: userId,
      addedBy: addedBy,
    );
  }

  Future<void> removeManagementAccess({
    required String quizId,
    required String userId,
    required String removedBy,
  }) async {
    await _ensureAdminLevel(removedBy, 2);
    await _ensurePermission('management_features', userId: removedBy);
    return _adminService.removeQuizManagementAccess(
      quizId: quizId,
      userId: userId,
      removedBy: removedBy,
    );
  }

  Stream<List<Map<String, dynamic>>> getQuizManagers(String quizId) =>
      _adminService.getQuizManagers(quizId);

  Stream<List<Map<String, dynamic>>> getQuizBannedUsers(String quizId) =>
      _adminService.getQuizBannedUsers(quizId);

  Stream<List<Map<String, dynamic>>> getDeletedQuizzes() =>
      _adminService.getDeletedQuizzes();

  Future<void> unbanUser({
    required String userId,
    String? quizId,
    required String adminId,
  }) =>
      _adminService.unbanUser(userId: userId, quizId: quizId, adminId: adminId);

  Future<bool> isUserBanned(String userId, {String? quizId}) =>
      _adminService.isUserBanned(userId, quizId: quizId);

  Future<void> addOrUpdateAdmin({
    required String targetUid,
    required int level,
    required String actorUid,
  }) async {
    await _ensureAdminLevel(actorUid, 9); // Only level 9-10 can manage admins
    return _adminService.addOrUpdateAdmin(
      targetUid: targetUid,
      level: level,
      actorUid: actorUid,
    );
  }

  Future<void> removeAdmin({
    required String targetUid,
    required String actorUid,
  }) async {
    await _ensureAdminLevel(actorUid, 9);
    return _adminService.removeAdmin(targetUid: targetUid, actorUid: actorUid);
  }

  // --- User Profiles ---

  Future<void> createUserProfile({
    required String uid,
    required String email,
    String? name,
    String? photoUrl,
  }) async {
    await _ensurePermission(null, userId: uid); // Basic maintenance check
    return _userService.createUserProfile(
      uid: uid,
      email: email,
      name: name,
      photoUrl: photoUrl,
    );
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    await _ensurePermission(null, userId: uid);
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

  Future<void> updateProtectedDetails({
    required String uid,
    required Map<String, dynamic> details,
  }) async {
    await _ensurePermission(null, userId: uid);
    return _userService.updateProtectedDetails(uid: uid, details: details);
  }

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
      final quiz = await readDatabase(quizId, userId: uid);

      // Calculate total questions from modules
      final List<dynamic> rawModules = quiz['modules'] as List? ?? [];
      int totalCount = 0;
      for (var module in rawModules) {
        final List<dynamic> questions = module['data'] as List? ?? [];
        totalCount += questions.length;
      }

      // Submit a "Timed Out" blank attempt
      await _attemptService.submitAttempt(
        userId: uid,
        quizId: quizId,
        quizTitle: quiz['title'] ?? 'Timed Out Quiz',
        score: 0,
        totalQuestions: totalCount,
        answers: {}, // Blank
      );
    } catch (e) {
      // If quiz not found or other error, still clear the active quiz
      await updateActiveQuiz(uid: uid, clear: true);
    }
  }

  // --- Quiz Management ---

  Future<String> createDatabase({
    String? clientToken, // Unique token to prevent duplicates on retry
    required String creatorId,
    required String user,
    required String title,
    required String description,
    required String visibility,
    required List<Map<String, Object>> data,
    int? time, // minutes
    Map<String, dynamic>? markingScheme,
    Map<String, dynamic>? attemptLimits,
    bool allowMultipleAttempts = true,
    bool completeRandomShuffle = false,
    int perQuestionTime = 0,
    DateTime? activeAt,
    bool isRestricted = false,
    List<String>? allowedParticipants,
    bool isPersonal = false,
    bool isAiGenerated = false,
  }) async {
    await _ensurePermission('enable_create_quiz', userId: creatorId);
    final Map<String, dynamic> scheme = markingScheme ?? {'type': 'default'};
    final transformed = _transformQuizData(data, scheme);
    return await _quizService.createQuiz(
      clientToken: clientToken,
      creatorId: creatorId,
      user: user,
      title: title,
      description: description,
      visibility: visibility,
      questions: List<Map<String, dynamic>>.from(transformed['modules']),
      answerKeys: List<Map<String, dynamic>>.from(transformed['answerkeys']),
      timeInSeconds: (time ?? 0) * 60,
      markingScheme: scheme,
      attemptLimits: attemptLimits ?? {'type': 'none'},
      allowMultipleAttempts: allowMultipleAttempts,
      completeRandomShuffle: completeRandomShuffle,
      perQuestionTime: perQuestionTime,
      activeAt: activeAt,
      isRestricted: isRestricted,
      allowedParticipants: allowedParticipants,
      isPersonal: isPersonal,
      isAiGenerated: isAiGenerated,
    );
  }

  Future<void> updateDatabase({
    required String docId,
    required String currentUserId,
    String? title,
    String? description,
    String? visibility,
    List<Map<String, Object>>? data,
    int? time, // minutes
    bool? allowMultipleAttempts,
    bool? completeRandomShuffle,
    int? perQuestionTime,
    Map<String, dynamic>? markingScheme,
    Map<String, dynamic>? attemptLimits,
    DateTime? activeAt,
    bool? isRestricted,
    List<String>? allowedParticipants,
    required bool isAiGenerated,
  }) async {
    await _ensurePermission('enable_edit_quiz', userId: currentUserId);

    final quiz = await _quizService.getQuiz(docId);
    if (quiz != null && quiz['isPersonal'] == true) {
      final isAdmin = await _adminService.isAdmin(currentUserId);
      if (!isAdmin) {
        throw Exception("Personal quizzes cannot be edited.");
      }
    }

    final Map<String, dynamic> updates = {};
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (visibility != null) updates['visibility'] = visibility;
    if (time != null) updates['time'] = time * 60;
    if (allowMultipleAttempts != null) {
      updates['allowMultipleAttempts'] = allowMultipleAttempts;
    }
    if (completeRandomShuffle != null) {
      updates['completeRandomShuffle'] = completeRandomShuffle;
    }
    if (perQuestionTime != null) updates['perQuestionTime'] = perQuestionTime;
    if (markingScheme != null) updates['markingScheme'] = markingScheme;
    if (attemptLimits != null) updates['attemptLimits'] = attemptLimits;
    if (activeAt != null) updates['activeAt'] = Timestamp.fromDate(activeAt);
    if (isRestricted != null) updates['isRestricted'] = isRestricted;
    if (allowedParticipants != null) {
      updates['allowedParticipants'] = allowedParticipants;
    }

    if (data != null) {
      // Fetch current marking scheme to propagate to questions if not provided
      Map<String, dynamic> scheme = markingScheme ?? {};
      if (markingScheme == null) {
        final current = await _quizService.getQuiz(docId);
        scheme = current?['markingScheme'] ?? {'type': 'default'};
      }

      final transformed = _transformQuizData(data, scheme);
      updates['modules'] = transformed['modules'];
      await _quizService.updateAnswerKeys(
        quizId: docId,
        userId: currentUserId,
        answerKeys: List<Map<String, dynamic>>.from(transformed['answerkeys']),
      );
    }

    if (updates.isNotEmpty) {
      await _quizService.updateQuiz(
        quizId: docId,
        userId: currentUserId,
        updates: updates,
      );
    }
  }

  Future<void> deleteDatabase({
    required String docId,
    required String currentUserId,
  }) async {
    await _ensurePermission('enable_delete_quiz', userId: currentUserId);
    await _quizService.deleteQuiz(docId, currentUserId);
  }

  Future<void> restoreDatabase({
    required String docId,
    required String currentUserId,
  }) async {
    await _quizService.restoreQuiz(docId, currentUserId);
  }

  Future<void> toggleQuizLock({
    required String docId,
    required String currentUserId,
    required bool isLocked,
  }) async {
    await _ensurePermission('management_features', userId: currentUserId);
    await _quizService.updateQuiz(
      quizId: docId,
      userId: currentUserId,
      updates: {'isLocked': isLocked},
    );
  }

  Stream<List<Map<String, dynamic>>> readAllDatabases({
    bool showMyQuizzes = false,
    bool showManagedQuizzes = false,
    bool showTrash = false,
    String? creatorId,
    String? userId,
  }) {
    // For streams, we can check global flags. If null, we assume enabled
    // but the stream itself doesn't easily support async permission checks before returning
    if (global.featureFlags?['maintenance_mode'] == true &&
        global.isAdmin == false) {
      return Stream.value([]);
    }

    if (showTrash && creatorId != null) {
      return _quizService.getMyDeletedQuizzes(creatorId);
    } else if (showMyQuizzes && creatorId != null) {
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
  }) async {
    await _ensurePermission(
      null,
      userId: userId,
    ); // Basic maintenance/read check
    final quiz = await _quizService.getQuiz(docId);
    if (quiz == null) throw Exception("Quiz not found");

    final bool isDeleted = quiz['isDeleted'] ?? false;
    bool isAdminUser = false;
    if (userId != null) {
      isAdminUser = await _adminService.isAdmin(userId);
    }

    if (isDeleted && !isAdminUser) {
      throw Exception("Quiz not found");
    }

    // Fetch questions from separate collection
    final questions = await _quizService.getQuizQuestions(docId);
    quiz['modules'] = questions;

    return quiz;
  }

  // --- Attempts & Scoring ---

  Future<Map<String, dynamic>> getQuizAnswers(
    String docId,
    String userId, {
    String? from,
    int? totalQuestions,
    Map<String, dynamic>? userAnswers,
    List<String>? reviewItems,
  }) async {
    await _ensurePermission('enable_take_quiz', userId: userId);
    final quiz = await _quizService.getQuiz(docId);
    if (quiz == null) throw Exception("Quiz not found");

    final bool isDeleted = quiz['isDeleted'] ?? false;
    final bool isAdminUser = await _adminService.isAdmin(userId);

    if (isDeleted && !isAdminUser) {
      throw Exception("Quiz not found");
    }

    final bool isCreator = quiz['creatorId'] == userId;
    final keysList = await _quizService.getAnswerKeys(docId);
    if (keysList == null) throw Exception("Answers not found");

    final Map<String, List<String>> correctKey = {};
    final Map<String, String> solutions = {};

    for (var entry in keysList) {
      final qUid = entry['q'].toString();
      final optUid = entry['a'].toString();
      if (optUid != '__desc__') {
        correctKey.putIfAbsent(qUid, () => []).add(optUid);
      }
      if (entry.containsKey('s')) {
        solutions[qUid] = entry['s'].toString();
      }
    }

    if (from == 'quizform') {
      if (!isCreator) {
        throw Exception("Only creator can access answers in editor");
      }
    } else if (userAnswers != null && totalQuestions != null) {
      // Fetch questions for scoring
      final questions = await _quizService.getQuizQuestions(docId);
      final List<Map<String, dynamic>> flattenedQuestions = [];
      for (var module in questions) {
        final List<dynamic> qList = module['data'] as List? ?? [];
        for (var q in qList) {
          flattenedQuestions.add(Map<String, dynamic>.from(q));
        }
      }

      await _attemptService.submitScoredAttempt(
        userId: userId,
        quizId: docId,
        quizTitle: quiz['title'] ?? 'Untitled Quiz',
        totalQuestions: totalQuestions,
        userAnswers: userAnswers,
        correctKey: correctKey,
        markingScheme: quiz['markingScheme'] ?? {'type': 'default'},
        quizData: flattenedQuestions,
        reviewItems: reviewItems,
      );
    }
    return {'answers': correctKey, 'solutions': solutions};
  }

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
    final attempts = await FirebaseFirestore.instance
        .collection('responses')
        .where('userId', isEqualTo: userId)
        .where('quizId', isEqualTo: quizId)
        .limit(1)
        .get();
    return attempts.docs.isNotEmpty;
  }

  Map<String, dynamic> _transformQuizData(
    List<Map<String, Object>> inputData,
    Map<String, dynamic> markingScheme,
  ) {
    final Map<String, List<Map<String, dynamic>>> moduleMap = {};
    final List<Map<String, dynamic>> answerKeys = [];
    final Map<String, dynamic> perQuestionMap = {};

    for (int i = 0; i < inputData.length; i++) {
      final item = inputData[i];
      // Preserve existing UID if available, otherwise generate one
      final String qUid =
          item['uid']?.toString() ??
          (item['Q'] is Map ? (item['Q'] as Map)['id']?.toString() : null) ??
          "q_${DateTime.now().microsecondsSinceEpoch}_$i";

      final String qText =
          (item['question'] ??
                  (item['Q'] is Map ? (item['Q'] as Map)['text'] : ''))
              .toString();
      final String qDescription = (item['description'] ?? '').toString();
      final String qType = item['type']?.toString() ?? 'Single Choice';
      final String qSubject = item['subject']?.toString() ?? 'General';
      final int qTimer = int.tryParse(item['timer']?.toString() ?? '0') ?? 0;

      if (markingScheme['type'] == 'per_question') {
        perQuestionMap[qUid] = {
          'correct': item['correct'] ?? 4,
          'wrong': item['wrong'] ?? -1,
        };
      }

      final choices = (item['choices'] ?? item['As']) as List? ?? [];
      final answers = item['answers'] as List? ?? [];

      final List<Map<String, String>> optionsWithIds = [];

      if (qType == "Integer") {
        if (answers.isNotEmpty) {
          answerKeys.add({
            'q': qUid,
            'a': answers.first.toString(),
            's': qDescription,
          });
        }
      } else {
        bool descriptionAdded = false;
        for (int j = 0; j < choices.length; j++) {
          final choice = choices[j];
          String optUid;
          String optText;

          if (choice is Map && choice.containsKey('id')) {
            optUid = choice['id'].toString();
            optText = choice['text']?.toString() ?? '';
          } else {
            optUid = "opt_${DateTime.now().microsecondsSinceEpoch}_${i}_$j";
            optText = choice.toString();
          }

          optionsWithIds.add({'id': optUid, 'text': optText});

          // Check if this option is an answer (by text or by ID)
          if (answers.contains(optText) || answers.contains(optUid)) {
            final Map<String, dynamic> entry = {'q': qUid, 'a': optUid};
            if (!descriptionAdded) {
              entry['s'] = qDescription;
              descriptionAdded = true;
            }
            answerKeys.add(entry);
          }
        }
        // If no answers were selected but there's a description, add a dummy entry or handle it
        if (!descriptionAdded && qDescription.isNotEmpty) {
          answerKeys.add({'q': qUid, 'a': '__desc__', 's': qDescription});
        }
      }

      final questionData = {
        'uid': qUid,
        'type': qType,
        'timer': qTimer,
        'Q': {'id': qUid, 'text': qText},
        'As': optionsWithIds,
      };

      if (!moduleMap.containsKey(qSubject)) {
        moduleMap[qSubject] = [];
      }
      moduleMap[qSubject]!.add(questionData);
    }

    if (markingScheme['type'] == 'per_question') {
      markingScheme['perQuestion'] = perQuestionMap;
    }

    // Sort questions within each subject to ensure Module > Single > Multiple > Integer order
    final List<String> typeOrder = [
      'Single Choice',
      'Multiple Choice',
      'Integer',
    ];

    final List<Map<String, dynamic>> modules = moduleMap.entries.map((e) {
      final subject = e.key;
      final List<Map<String, dynamic>> questions = e.value;

      // Sort the questions list based on the typeOrder
      questions.sort((a, b) {
        final typeA = a['type']?.toString() ?? 'Single Choice';
        final typeB = b['type']?.toString() ?? 'Single Choice';

        int indexA = typeOrder.indexOf(typeA);
        int indexB = typeOrder.indexOf(typeB);

        // If type not found in order list, put it at the end
        if (indexA == -1) indexA = 99;
        if (indexB == -1) indexB = 99;

        return indexA.compareTo(indexB);
      });

      return {'subject': subject, 'data': questions};
    }).toList();

    return {'modules': modules, 'answerkeys': answerKeys};
  }
}
