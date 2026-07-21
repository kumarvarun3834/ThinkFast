import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:thinkfast/services/notification_service.dart';
import '../../utils/global.dart' as global;

import '../admin_service.dart';
import '../quiz_service.dart';
import '../settings_service.dart';

/// 🏢 Database Service for Quiz-Level Administrative Operations
class QAdminDatabaseService {
  final AdminService _adminService = AdminService();
  final QuizService _quizService = QuizService();
  final SettingsService _settingsService = SettingsService();

  Future<void> _ensurePermission(String? flag, {String? userId}) async {
    final flags =
        global.featureFlags ??
            await _settingsService.getFeatureFlags(isAdmin: global.isAdmin);

    if (flags?['maintenance_mode'] == true) {
      bool isUserAdmin = false;
      if (userId != null) {
        isUserAdmin = await _adminService.isAdmin(userId);
      }
      if (!isUserAdmin) {
        throw Exception(
            "System is currently under maintenance. Please try again later.");
      }
    }

    if (flag != null && flags?[flag] == false) {
      bool isUserAdmin = false;
      if (userId != null) {
        isUserAdmin = await _adminService.isAdmin(userId);
      }
      if (!isUserAdmin) {
        final actionName = flag.replaceFirst('enable_', '').replaceAll(
            '_', ' ');
        throw Exception(
            "Access Denied: '$actionName' is currently disabled by the administrator.");
      }
    }
  }

  Future<void> _ensureAdminPermission(String userId, String permission) async {
    if (!await _adminService.hasPermission(userId, permission)) {
      throw Exception(
          "Access Denied: Administrative permission '$permission' required.");
    }
  }

  // --- Quiz Lifecycle ---

  Future<String> createDatabase({
    String? clientToken,
    required String creatorId,
    required String user,
    required String title,
    required String description,
    required String visibility,
    required List<Map<String, Object>> data,
    int? time,
    Map<String, dynamic>? timingScheme,
    Map<String, dynamic>? markingScheme,
    Map<String, dynamic>? attemptLimits,
    bool allowMultipleAttempts = true,
    int maxAttempts = 1,
    bool completeRandomShuffle = false,
    bool shuffleModules = false,
    bool shuffleQuestionsWithinModules = false,
    bool disableModuleSwitchingUntilTimeout = false,
    bool forceWaitUntilTimeout = false,
    bool enableAutoLeaderboard = false,
    int perQuestionTime = 0,
    DateTime? perQuestionStartTime, // Unused but in signature
    DateTime? activeAt,
    bool isRestricted = false,
    List<String>? allowedParticipants,
    bool isPersonal = false,
    bool isAiGenerated = false,
    List<String>? tags,
    Map<String, List<String>>? moduleTags,
    String? examTag,
    List<String>? moduleOrder,
  }) async {
    await _ensurePermission('enable_create_quiz', userId: creatorId);
    final Map<String, dynamic> scheme = markingScheme ?? {'type': 'default'};
    final transformed = _transformQuizData(
        data, scheme, moduleOrder: moduleOrder);
    final List modules = transformed['modules'] as List? ?? [];
    final Set<String> allModules = data.map((q) =>
    q['subject'] as String? ?? 'General').toSet();

    final String quizId = await _quizService.createQuiz(
      clientToken: clientToken,
      creatorId: creatorId,
      user: user,
      title: title,
      description: description,
      visibility: visibility,
      questions: List<Map<String, dynamic>>.from(transformed['modules']),
      answerKeys: List<Map<String, dynamic>>.from(transformed['answerkeys']),
      timeInSeconds: (time ?? 0) * 60,
      timingScheme: timingScheme,
      markingScheme: scheme,
      attemptLimits: attemptLimits ?? {'type': 'none'},
      allowMultipleAttempts: allowMultipleAttempts,
      maxAttempts: maxAttempts,
      completeRandomShuffle: completeRandomShuffle,
      shuffleModules: shuffleModules,
      shuffleQuestionsWithinModules: shuffleQuestionsWithinModules,
      disableModuleSwitchingUntilTimeout: disableModuleSwitchingUntilTimeout,
      forceWaitUntilTimeout: forceWaitUntilTimeout,
      enableAutoLeaderboard: enableAutoLeaderboard,
      perQuestionTime: perQuestionTime,
      activeAt: activeAt,
      isRestricted: isRestricted,
      allowedParticipants: allowedParticipants,
      isPersonal: isPersonal,
      isAiGenerated: isAiGenerated,
      totalQuestions: data.length,
      moduleCount: modules.length,
      markingType: scheme['type'] ?? 'default',
      attemptLimitType: attemptLimits?['type'] ?? 'none',
      tags: tags,
      moduleTags: moduleTags,
      examTag: examTag,
    );

    await syncModuleTags(
        quizId, moduleTags ?? {}, allModules: allModules.toList());

    if (examTag != null && examTag
        .trim()
        .isNotEmpty) {
      await syncExamTag(quizId, examTag);
    }

    // Notify all users if it's a new PUBLIC quiz
    if (visibility == 'public' && !isRestricted && !isPersonal) {
      try {
        await NotificationService().broadcastNotification(
          title: "New Quiz Alert!",
          body: "$user just published a new quiz: $title. Challenge yourself now!",
          type: 'new_quiz',
          targetId: quizId,
        );
      } catch (e) {
        debugPrint("Failed to broadcast new quiz notification: $e");
      }
    }

    return quizId;
  }

  Future<void> updateDatabase({
    required String docId,
    required String currentUserId,
    String? title,
    String? description,
    String? visibility,
    List<Map<String, Object>>? data,
    int? time,
    Map<String, dynamic>? timingScheme,
    bool? allowMultipleAttempts,
    bool? completeRandomShuffle,
    bool? shuffleModules,
    bool? shuffleQuestionsWithinModules,
    bool? disableModuleSwitchingUntilTimeout,
    bool? forceWaitUntilTimeout,
    bool? enableAutoLeaderboard,
    int? perQuestionTime,
    int? maxAttempts,
    Map<String, dynamic>? markingScheme,
    Map<String, dynamic>? attemptLimits,
    DateTime? activeAt,
    bool? isRestricted,
    List<String>? allowedParticipants,
    required bool isAiGenerated,
    List<String>? tags,
    Map<String, List<String>>? moduleTags,
    String? examTag,
    List<String>? moduleOrder,
  }) async {
    await _ensurePermission('enable_edit_quiz', userId: currentUserId);

    final quiz = await _quizService.getQuiz(docId);
    if (quiz == null) throw Exception("Quiz not found.");

    if (quiz['isPersonal'] == true) {
      final isAdmin = await _adminService.isAdmin(currentUserId);
      if (!isAdmin) throw Exception("Personal quizzes cannot be edited.");
    }

    // Privacy Lock: Admins cannot edit internal content (questions/answers) of quizzes they don't explicitly manage.
    if (data != null) {
      final bool isExplicitManager = await _adminService.canManageQuiz(
        docId,
        currentUserId,
        skipAdminCheck: true,
      );
      final bool hasPrivacyBypass = await _adminService.hasPermission(
        currentUserId,
        'bypass_quiz_privacy',
      );

      if (!isExplicitManager && !hasPrivacyBypass && await _adminService.isAdmin(currentUserId)) {
        throw Exception(
          "Access Denied: Platform administrators cannot modify internal quiz content (questions/answers) without explicit management permissions or 'bypass_quiz_privacy' enabled.",
        );
      }
    }

    final Map<String, dynamic> updates = {};
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (visibility != null) updates['visibility'] = visibility;
    if (time != null) updates['time'] = time * 60;
    if (timingScheme != null) updates['timingScheme'] = timingScheme;
    if (allowMultipleAttempts != null)
      updates['allowMultipleAttempts'] = allowMultipleAttempts;
    if (maxAttempts != null) updates['maxAttempts'] = maxAttempts;
    if (completeRandomShuffle != null)
      updates['completeRandomShuffle'] = completeRandomShuffle;
    if (shuffleModules != null) updates['shuffleModules'] = shuffleModules;
    if (shuffleQuestionsWithinModules != null)
      updates['shuffleQuestionsWithinModules'] = shuffleQuestionsWithinModules;
    if (disableModuleSwitchingUntilTimeout != null)
      updates['disableModuleSwitchingUntilTimeout'] =
          disableModuleSwitchingUntilTimeout;
    if (forceWaitUntilTimeout != null)
      updates['forceWaitUntilTimeout'] = forceWaitUntilTimeout;
    if (enableAutoLeaderboard != null)
      updates['enableAutoLeaderboard'] = enableAutoLeaderboard;
    if (perQuestionTime != null) updates['perQuestionTime'] = perQuestionTime;
    if (markingScheme != null) {
      updates['markingScheme'] = markingScheme;
      updates['markingType'] = markingScheme['type'] ?? 'default';
    }
    if (attemptLimits != null) updates['attemptLimits'] = attemptLimits;
    if (activeAt != null) updates['activeAt'] = Timestamp.fromDate(activeAt);
    if (isRestricted != null) updates['isRestricted'] = isRestricted;
    if (allowedParticipants != null)
      updates['allowedParticipants'] = allowedParticipants;
    if (tags != null) updates['tags'] = tags;
    if (moduleTags != null) updates['moduleTags'] = moduleTags;
    if (examTag != null) updates['examTag'] = examTag;
    updates['isAiGenerated'] = isAiGenerated;

    if (data != null) {
      Map<String, dynamic> scheme = markingScheme ?? {};
      if (markingScheme == null) {
        final current = await _quizService.getQuiz(docId);
        scheme = current?['markingScheme'] ?? {'type': 'default'};
      }

      final transformed = _transformQuizData(
          data, scheme, moduleOrder: moduleOrder);
      updates['modules'] = transformed['modules'];
      updates['totalQuestions'] = data.length;
      updates['moduleCount'] = transformed['modules'].length;
      updates['markingType'] = scheme['type'] ?? 'default';
      updates['attemptLimitType'] = attemptLimits?['type'] ?? 'none';

      await _quizService.updateAnswerKeys(
        quizId: docId,
        userId: currentUserId,
        answerKeys: List<Map<String, dynamic>>.from(transformed['answerkeys']),
      );

      final Set<String> allModules = data.map((q) =>
      q['subject'] as String? ?? 'General').toSet();
      await syncModuleTags(
          docId, moduleTags ?? {}, allModules: allModules.toList());
    }

    if (updates.isNotEmpty) {
      await _quizService.updateQuiz(
          quizId: docId, userId: currentUserId, updates: updates);
    }
  }

  Future<void> deleteDatabase(
      {required String docId, required String currentUserId}) async {
    await _ensurePermission('enable_delete_quiz', userId: currentUserId);
    return _quizService.deleteQuiz(docId, currentUserId);
  }

  Future<void> restoreDatabase(
      {required String docId, required String currentUserId}) async {
    await _ensurePermission('enable_delete_quiz', userId: currentUserId);
    return _quizService.restoreQuiz(docId, currentUserId);
  }

  Future<void> toggleQuizLock(
      {required String docId, required String currentUserId, required bool isLocked}) async {
    await _ensurePermission('enable_edit_quiz', userId: currentUserId);
    return _quizService.updateQuiz(
        quizId: docId, userId: currentUserId, updates: {'isLocked': isLocked});
  }

  Future<void> grantManagementAccess(
      {required String quizId, required String userId, required Map<String,
          bool> permissions, required String addedBy}) async {
    await _ensurePermission('management_features', userId: addedBy);
    return _adminService.grantQuizManagementAccess(quizId: quizId,
        userId: userId,
        permissions: permissions,
        addedBy: addedBy);
  }

  Future<void> removeManagementAccess(
      {required String quizId, required String userId, required String removedBy}) async {
    await _ensurePermission('management_features', userId: removedBy);
    return _adminService.removeQuizManagementAccess(
        quizId: quizId, userId: userId, removedBy: removedBy);
  }

  Stream<List<Map<String, dynamic>>> getQuizManagers(String quizId) =>
      _adminService.getQuizManagers(quizId);

  Stream<List<Map<String, dynamic>>> getQuizParticipants(String quizId) =>
      _adminService.getQuizParticipants(quizId);

  Future<void> addParticipant(
      {required String quizId, required String userId, required String addedBy}) async {
    await _ensurePermission('management_features', userId: addedBy);
    return _adminService.addParticipant(
        quizId: quizId, userId: userId, addedBy: addedBy);
  }

  Future<void> banUser(
      {required String userId, required String quizId, required String reason, required String adminId}) async {
    return _adminService.banUser(
        userId: userId, quizId: quizId, reason: reason, adminId: adminId);
  }

  Future<void> unbanUser(
      {required String userId, required String quizId, required String adminId}) async {
    return _adminService.unbanUser(
        userId: userId, quizId: quizId, adminId: adminId);
  }

  Stream<List<Map<String, dynamic>>> getQuizBannedUsers(String quizId) =>
      _adminService.getQuizBannedUsers(quizId);

  Stream<List<Map<String, dynamic>>> getDeletedQuizzes() =>
      _adminService.getDeletedQuizzes();

  Future<Map<String, dynamic>?> getFeatureFlags() =>
      _settingsService.getFeatureFlags(isAdmin: global.isAdmin);

  // --- Tag & Module Management ---

  Future<void> syncModuleTags(String quizId,
      Map<String, List<String>> moduleTags, {List<String>? allModules}) async {
    final batch = FirebaseFirestore.instance.batch();
    final tagsRef = FirebaseFirestore.instance.collection('tags');
    final moduleTagsRef = FirebaseFirestore.instance.collection('module_tags');

    // 1. Process explicit module tags
    moduleTags.forEach((moduleName, tags) {
      if (tags.isEmpty) {
        _addTagToBatch(
            batch, tagsRef, moduleTagsRef, quizId, moduleName, 'general');
      } else {
        for (var tag in tags) {
          final tagId = tag.toLowerCase().trim();
          _addTagToBatch(
              batch, tagsRef, moduleTagsRef, quizId, moduleName, tagId);
        }
      }
    });

    // 2. Ensure all modules have at least a "general" sub-topic if not tagged
    if (allModules != null) {
      for (var moduleName in allModules) {
        if (!moduleTags.containsKey(moduleName)) {
          _addTagToBatch(
              batch, tagsRef, moduleTagsRef, quizId, moduleName, 'general');
        }
      }
    }

    await batch.commit();
  }

  void _addTagToBatch(WriteBatch batch, CollectionReference tagsRef,
      CollectionReference moduleTagsRef, String quizId, String moduleName,
      String tagId) {
    // Platform-wide discovery
    batch.set(tagsRef.doc(tagId), {
      'name': tagId,
      'lastUsed': FieldValue.serverTimestamp(),
      'quizIds': FieldValue.arrayUnion([quizId]),
      'moduleNames': FieldValue.arrayUnion([moduleName]),
    }, SetOptions(merge: true));

    // Granular module-tag document
    final String granularDocId = "${quizId}_${moduleName.replaceAll(
        ' ', '_')}_$tagId";
    batch.set(moduleTagsRef.doc(granularDocId), {
      'tag': tagId,
      'moduleName': moduleName,
      'quizId': quizId,
      'syncedAt': FieldValue.serverTimestamp(),
    });

    // Hierarchical Storage Pattern: tags/{module}/sub_topics/{subTag}/quizzes/{quizId}
    final moduleRef = tagsRef.doc(moduleName);
    final subTopicRef = moduleRef.collection('sub_topics').doc(tagId);
    final quizInTagRef = subTopicRef.collection('quizzes').doc(quizId);

    batch.set(moduleRef, {
      'name': moduleName,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(subTopicRef, {
      'name': tagId,
      'moduleName': moduleName,
      'lastUsed': FieldValue.serverTimestamp(),
      'quizIds': FieldValue.arrayUnion([quizId]),
    }, SetOptions(merge: true));

    batch.set(quizInTagRef, {
      'quizId': quizId,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> syncExamTag(String quizId, String examTag) async {
    if (examTag
        .trim()
        .isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    final examTagsRef = FirebaseFirestore.instance.collection('exam_tags');
    final tagId = examTag.toLowerCase().trim();

    batch.set(examTagsRef.doc(tagId), {
      'name': tagId,
      'lastUsed': FieldValue.serverTimestamp(),
      'quizIds': FieldValue.arrayUnion([quizId]),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // --- Response Analytics ---

  Future<void> softDeleteResponse(
      {required String responseId, required String quizId, required String actorId, required String reason}) async {
    await _ensurePermission(null, userId: actorId);
    return _adminService.softDeleteResponse(responseId: responseId,
        quizId: quizId,
        actorId: actorId,
        reason: reason);
  }

  Future<void> restoreResponse(
      {required String responseId, required String quizId}) async {
    await _ensurePermission(null, userId: global.currentUserProfile?['uid']);
    return _adminService.restoreResponse(
        responseId: responseId, quizId: quizId);
  }

  Stream<List<Map<String, dynamic>>> getQuizResponses(String quizId,
      {bool includeDeleted = false}) {
    return FirebaseFirestore.instance
        .collection('responses')
        .where('quizId', isEqualTo: quizId)
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      if (includeDeleted) return docs;
      return docs.where((doc) => doc['isDeleted'] != true).toList();
    });
  }

  // --- Internal Data Helpers ---

  Map<String, dynamic> _transformQuizData(List<Map<String, Object>> inputData,
      Map<String, dynamic> markingScheme, {List<String>? moduleOrder}) {
    final Map<String, List<Map<String, dynamic>>> moduleMap = {};
    final List<Map<String, dynamic>> answerKeys = [];
    final Map<String, dynamic> perQuestionMap = {};

    for (int i = 0; i < inputData.length; i++) {
      final item = inputData[i];
      final String qUid = item['uid']?.toString() ??
          (item['Q'] is Map ? (item['Q'] as Map)['id']?.toString() : null) ??
          "q_${DateTime
              .now()
              .microsecondsSinceEpoch}_$i";

      final String qText = (item['question'] ??
          (item['Q'] is Map ? (item['Q'] as Map)['text'] : '')).toString();
      final String qDescription = (item['explanation'] ?? item['description'] ?? '').toString();
      final String qType = item['type']?.toString() ?? 'Single Choice';
      final String qSubject = item['subject']?.toString() ?? 'General';
      final int qTimer = int.tryParse(item['timer']?.toString() ?? '0') ?? 0;

      if (markingScheme['type'] == 'per_question') {
        perQuestionMap[qUid] =
        {'correct': item['correct'] ?? 4, 'wrong': item['wrong'] ?? -1};
      }

      final choices = (item['choices'] ?? item['As']) as List? ?? [];
      final answers = item['answers'] as List? ?? [];
      final List<Map<String, String>> optionsWithIds = [];

      if (qType == "Integer") {
        if (answers.isNotEmpty) answerKeys.add(
            {'q': qUid, 'a': answers.first.toString(), 's': qDescription});
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
            optUid = "opt_${DateTime
                .now()
                .microsecondsSinceEpoch}_${i}_$j";
            optText = choice.toString();
          }

          optionsWithIds.add({'id': optUid, 'text': optText});

          if (answers.contains(optText) || answers.contains(optUid)) {
            final Map<String, dynamic> entry = {'q': qUid, 'a': optUid};
            if (!descriptionAdded) {
              entry['s'] = qDescription;
              descriptionAdded = true;
            }
            answerKeys.add(entry);
          }
        }
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

      moduleMap.putIfAbsent(qSubject, () => []).add(questionData);
    }

    if (markingScheme['type'] == 'per_question')
      markingScheme['perQuestion'] = perQuestionMap;

    final List<String> typeOrder = [
      'Single Choice',
      'Multiple Choice',
      'Integer'
    ];

    final List<Map<String, dynamic>> modules = moduleMap.entries.map((e) {
      final questions = e.value;
      questions.sort((a, b) {
        final typeA = a['type']?.toString() ?? 'Single Choice';
        final typeB = b['type']?.toString() ?? 'Single Choice';
        int indexA = typeOrder.indexOf(typeA);
        int indexB = typeOrder.indexOf(typeB);
        if (indexA == -1) indexA = 99;
        if (indexB == -1) indexB = 99;
        return indexA.compareTo(indexB);
      });
      return {'subject': e.key, 'data': questions};
    }).toList();

    if (moduleOrder != null) {
      modules.sort((a, b) {
        int indexA = moduleOrder.indexOf(a['subject']);
        int indexB = moduleOrder.indexOf(b['subject']);
        if (indexA == -1) indexA = 999;
        if (indexB == -1) indexB = 999;
        return indexA.compareTo(indexB);
      });
    }

    for (int i = 0; i < modules.length; i++) {
      modules[i]['order'] = i;
    }

    return {'modules': modules, 'answerkeys': answerKeys};
  }
}
