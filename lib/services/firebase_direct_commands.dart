import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_service.dart';
import 'user_service.dart';
import 'quiz_service.dart';
import 'attempt_service.dart';
import 'settings_service.dart';

/// 🚀 Unified Database Service (Facade for specialized services)
class DatabaseService {
  final UserService _userService = UserService();
  final QuizService _quizService = QuizService();
  final AttemptService _attemptService = AttemptService();
  final SettingsService _settingsService = SettingsService();
  final AdminService _adminService = AdminService();

  // --- Admin & Experience Switching ---

  Future<bool> isRegisteredAdmin(String uid) =>
      _adminService.isRegisteredAdmin(uid);

  Future<bool> isAdmin(String uid) => _adminService.isAdmin(uid);

  Future<void> toggleAdminMode({required String uid, required bool enable}) =>
      _adminService.toggleAdminMode(uid: uid, enable: enable);

  // --- User Profiles ---

  Future<void> createUserProfile({
    required String uid,
    required String email,
    String? name,
    String? photoUrl,
  }) => _userService.createUserProfile(
        uid: uid, email: email, name: name, photoUrl: photoUrl);

  Future<Map<String, dynamic>?> getUserProfile(String uid) =>
      _userService.getUserProfile(uid);

  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? email,
  }) async {
    await _userService.updateUserProfile(uid: uid, name: name);
    if (email != null) {
      await _userService.updatePrivateDetails(uid: uid, email: email);
    }
  }

  Future<void> updateProtectedDetails({
    required String uid,
    required Map<String, dynamic> details,
  }) => _userService.updateProtectedDetails(uid: uid, details: details);

  Future<void> updateActiveQuiz({
    required String uid,
    String? quizId,
    DateTime? expiry,
    bool clear = false,
  }) => _userService.updatePrivateDetails(
    uid: uid,
    activeQuizId: quizId,
    activeQuizExpiry: expiry,
    clearActiveQuiz: clear,
  );

  Future<void> handleExpiredQuiz(String uid, String quizId) async {
    try {
      final quiz = await readDatabase(quizId);

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
    required int time, // minutes
    Map<String, dynamic>? markingScheme,
    bool allowMultipleAttempts = true,
  }) async {
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
      answerKeys: List<Map<String, String>>.from(transformed['answerkeys']),
      timeInSeconds: time * 60,
      markingScheme: scheme,
      allowMultipleAttempts: allowMultipleAttempts,
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
    Map<String, dynamic>? markingScheme,
  }) async {
    final Map<String, dynamic> updates = {};
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (visibility != null) updates['visibility'] = visibility;
    if (time != null) updates['time'] = time * 60;
    if (allowMultipleAttempts != null) {
      updates['allowMultipleAttempts'] = allowMultipleAttempts;
    }
    if (markingScheme != null) updates['markingScheme'] = markingScheme;

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
        answerKeys: List<Map<String, String>>.from(transformed['answerkeys']),
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
    final quiz = await _quizService.getQuiz(docId);
    final bool isAdmin = await _adminService.isAdmin(currentUserId);

    if (quiz != null && (quiz['creatorId'] == currentUserId || isAdmin)) {
      await _quizService.deleteQuiz(docId, currentUserId);
    } else {
      throw Exception("Unauthorized to delete this quiz");
    }
  }

  Future<void> toggleQuizLock({
    required String docId,
    required String currentUserId,
    required bool isLocked,
  }) async {
    await _quizService.updateQuiz(
      quizId: docId,
      userId: currentUserId,
      updates: {'isLocked': isLocked},
    );
  }

  Stream<List<Map<String, dynamic>>> readAllDatabases({
    bool showMyQuizzes = false,
    String? creatorId,
  }) {
    if (showMyQuizzes && creatorId != null) {
      return _quizService.getMyQuizzes(creatorId);
    } else {
      return _quizService.getPublicQuizzes();
    }
  }

  Future<Map<String, dynamic>> readDatabase(String docId) async {
    final quiz = await _quizService.getQuiz(docId);
    if (quiz == null || quiz['isDeleted'] == true) {
      throw Exception("Quiz not found");
    }

    // Fetch questions from separate collection
    final questions = await _quizService.getQuizQuestions(docId);
    quiz['modules'] = questions;

    return quiz;
  }

  // --- Attempts & Scoring ---

  Future<Map<String, List<String>>> getQuizAnswers(
    String docId,
    String userId, {
    String? from,
    int? totalQuestions,
    Map<String, dynamic>? userAnswers,
  }) async {
    final quiz = await _quizService.getQuiz(docId);
    if (quiz == null || quiz['isDeleted'] == true) {
      throw Exception("Quiz not found");
    }

    final bool isCreator = quiz['creatorId'] == userId;
    final keysList = await _quizService.getAnswerKeys(docId);
    if (keysList == null) throw Exception("Answers not found");

    final Map<String, List<String>> correctKey = {};
    for (var entry in keysList) {
      final qUid = entry['q'].toString();
      final optUid = entry['a'].toString();
      correctKey.putIfAbsent(qUid, () => []).add(optUid);
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
      );
    }
    return correctKey;
  }

  Stream<List<Map<String, dynamic>>> getUserAttempts(String userId) =>
      _attemptService.getUserAttempts(userId);

  Stream<List<Map<String, dynamic>>> getQuizResponses(String quizId) =>
      _attemptService.getQuizAttempts(quizId);

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
    final List<Map<String, String>> answerKeys = [];
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
      final String qType = item['type']?.toString() ?? 'Single Choice';
      final String qSubject = item['subject']?.toString() ?? 'General';

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
          answerKeys.add({'q': qUid, 'a': answers.first.toString()});
        }
      } else {
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
            answerKeys.add({'q': qUid, 'a': optUid});
          }
        }
      }

      final questionData = {
        'uid': qUid,
        'type': qType,
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
    final List<String> typeOrder = ['Single Choice', 'Multiple Choice', 'Integer'];
    
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
