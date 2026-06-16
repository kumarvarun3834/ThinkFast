import 'package:cloud_firestore/cloud_firestore.dart';
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

  // --- User Profiles ---

  Future<void> createUserProfile({required String uid, required String email, String? name}) =>
      _userService.createUserProfile(uid: uid, email: email, name: name);

  Future<Map<String, dynamic>?> getUserProfile(String uid) => _userService.getUserProfile(uid);

  Future<void> updateUserProfile({required String uid, String? name, String? email}) async {
    await _userService.updateUserProfile(uid: uid, name: name);
    if (email != null) await _userService.updatePrivateDetails(uid: uid, email: email);
  }

  Future<void> updateProtectedDetails({required String uid, required Map<String, dynamic> details}) =>
      _userService.updateProtectedDetails(uid: uid, details: details);

  Future<void> updateActiveQuiz({required String uid, String? quizId, DateTime? expiry, bool clear = false}) =>
      _userService.updatePrivateDetails(uid: uid, activeQuizId: quizId, activeQuizExpiry: expiry, clearActiveQuiz: clear);

  Future<void> handleExpiredQuiz(String uid, String quizId) async {
    final quiz = await _quizService.getQuiz(quizId);
    if (quiz == null) {
      await updateActiveQuiz(uid: uid, clear: true);
      return;
    }

    // Submit a "Timed Out" blank attempt
    await _attemptService.submitAttempt(
      userId: uid,
      quizId: quizId,
      quizTitle: quiz['title'] ?? 'Timed Out Quiz',
      score: 0,
      totalQuestions: (quiz['data'] as List?)?.length ?? 0,
      answers: {}, // Blank
    );
    // submitAttempt already clears activeQuizId in AttemptService
  }

  // --- Quiz Management ---

  Future<String> createDatabase({
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
    if (allowMultipleAttempts != null) updates['allowMultipleAttempts'] = allowMultipleAttempts;
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
        answerKeys: List<Map<String, String>>.from(transformed['answerkeys']),
      );
    }

    await _quizService.updateQuiz(quizId: docId, updates: updates);
  }

  Future<void> deleteDatabase({required String docId, required String currentUserId}) async {
    final quiz = await _quizService.getQuiz(docId);
    if (quiz != null && quiz['creatorId'] == currentUserId) {
      await _quizService.deleteQuiz(docId, currentUserId);
    } else {
      throw Exception("Unauthorized to delete this quiz");
    }
  }

  Future<void> toggleQuizLock({required String docId, required bool isLocked}) async {
    await _quizService.updateQuiz(quizId: docId, updates: {'isLocked': isLocked});
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
    if (quiz == null || quiz['isDeleted'] == true) throw Exception("Quiz not found");
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
    if (quiz == null || quiz['isDeleted'] == true) throw Exception("Quiz not found");

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
      if (!isCreator) throw Exception("Only creator can access answers in editor");
    } else if (userAnswers != null && totalQuestions != null) {
      await _attemptService.submitScoredAttempt(
        userId: userId,
        quizId: docId,
        quizTitle: quiz['title'] ?? 'Untitled Quiz',
        totalQuestions: totalQuestions,
        userAnswers: userAnswers,
        correctKey: correctKey,
        markingScheme: quiz['markingScheme'] ?? {'type': 'default'},
        quizData: quiz['data'] ?? [],
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

  Map<String, dynamic> _transformQuizData(List<Map<String, Object>> inputData, Map<String, dynamic> markingScheme) {
    final Map<String, List<Map<String, dynamic>>> moduleMap = {};
    final List<Map<String, String>> answerKeys = [];
    final Map<String, dynamic> perQuestionMap = {};

    for (int i = 0; i < inputData.length; i++) {
      final item = inputData[i];
      final String qUid = "q_${DateTime.now().microsecondsSinceEpoch}_$i";
      final String qText = (item['question'] ?? '').toString();
      final String qType = item['type']?.toString() ?? 'Single Choice';
      final String qSubject = item['subject']?.toString() ?? 'General';

      if (markingScheme['type'] == 'per_question') {
        perQuestionMap[qUid] = {
          'correct': item['correct'] ?? 4,
          'wrong': item['wrong'] ?? -1,
        };
      }

      final choices = item['choices'] as List? ?? [];
      final answers = item['answers'] as List? ?? [];

      final List<Map<String, String>> optionsWithIds = [];
      
      if (qType == "Integer") {
        if (answers.isNotEmpty) {
          answerKeys.add({'q': qUid, 'a': answers.first.toString()});
        }
      } else {
        for (int j = 0; j < choices.length; j++) {
          final String optUid = "opt_${DateTime.now().microsecondsSinceEpoch}_${i}_$j";
          final String optText = choices[j].toString();
          optionsWithIds.add({'id': optUid, 'text': optText});

          if (answers.contains(optText)) {
            answerKeys.add({'q': qUid, 'a': optUid});
          }
        }
      }

      final questionData = {
        'uid': qUid,
        'type': qType,
        'Q': {'id': qUid, 'text': qText},
        'Opt': optionsWithIds,
      };

      if (!moduleMap.containsKey(qSubject)) {
        moduleMap[qSubject] = [];
      }
      moduleMap[qSubject]!.add(questionData);
    }

    if (markingScheme['type'] == 'per_question') {
      markingScheme['perQuestion'] = perQuestionMap;
    }

    final List<Map<String, dynamic>> modules = moduleMap.entries.map((e) => {
      'subject': e.key,
      'questions': e.value,
    }).toList();

    return {'modules': modules, 'answerkeys': answerKeys};
  }
}
