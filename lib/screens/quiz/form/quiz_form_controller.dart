import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:thinkfast/screens/quiz/form/form_data_mapping.dart';
import 'package:thinkfast/services/quiz_data_processor.dart';
import 'package:thinkfast/utils/global.dart' as global;

class QuizFormController {
  static Future<void> fetchQuiz({
    required String docId,
    required String uid,
    required TextEditingController titleController,
    required TextEditingController descriptionController,
    required TextEditingController examController,
    required TextEditingController timeController,
    required TextEditingController perQuestionTimeController,
    required TextEditingController allowedUsersController,
    required TextEditingController maxAttemptsController,
    required Map<String, TextEditingController> moduleTagControllers,
    required Map<String, TextEditingController> globalLimitControllers,
    required Map<String, Map<String, TextEditingController>> moduleLimitControllers,
    required Map<String, Map<String, TextEditingController>> moduleTimingControllers,
    required Map<String, Map<String, TextEditingController>> moduleTypeTimingControllers,
    required Map<String, TextEditingController> typeTimingControllers,
    required TextEditingController globalCorrectController,
    required TextEditingController globalWrongController,
    required TextEditingController scCorrectController,
    required TextEditingController scWrongController,
    required TextEditingController mcCorrectController,
    required TextEditingController mcWrongController,
    required TextEditingController intCorrectController,
    required TextEditingController intWrongController,
    required List<String> modulesList,
    required List<Map<String, Object>> questions,
    required Function(String, dynamic) updateState,
    required Function updateModuleLimitControllers,
    required Function updateModuleTimingControllers,
  }) async {
    final data = await global.db.readDatabase(docId, userId: uid);
    final response = await global.db.getQuizAnswers(docId, uid, from: 'quizform');
    final Map<String, List<String>> answersMap = response['answers'];
    final Map<String, String> solutionsMap = response['solutions'];

    titleController.text = data['title'] ?? '';
    descriptionController.text = data['description'] ?? '';
    examController.text = data['examTag'] ?? '';
    allowedUsersController.text = (data['allowedParticipants'] as List? ?? []).join(', ');
    maxAttemptsController.text = (data['maxAttempts'] ?? 1).toString();
    perQuestionTimeController.text = (data['perQuestionTime'] ?? 0).toString();
    timeController.text = ((data['time'] ?? 0) ~/ 60).toString();

    if (data['activeAt'] != null) {
      updateState('scheduledTime', (data['activeAt'] as Timestamp).toDate());
    }
    updateState('visibility', data['visibility'] ?? 'private');
    updateState('allowMultipleAttempts', data['allowMultipleAttempts'] ?? true);
    updateState('completeRandomShuffle', data['completeRandomShuffle'] ?? false);
    updateState('shuffleModules', data['shuffleModules'] ?? false);
    updateState('shuffleQuestionsWithinModules', data['shuffleQuestionsWithinModules'] ?? false);
    updateState('disableModuleSwitchingUntilTimeout', data['disableModuleSwitchingUntilTimeout'] ?? false);
    updateState('forceWaitUntilTimeout', data['forceWaitUntilTimeout'] ?? false);
    updateState('enableAutoLeaderboard', data['enableAutoLeaderboard'] ?? false);
    updateState('isRestricted', data['isRestricted'] ?? false);

    final mTags = data['moduleTags'] as Map? ?? {};
    mTags.forEach((module, tags) {
      moduleTagControllers.putIfAbsent(module, () => TextEditingController()).text = (tags as List).join(', ');
    });

    final tType = data['timingScheme']?['type'] ?? 'global';
    updateState('timingType', tType);
    FormDataMapping.mapTimingToControllers(
      Map<String, dynamic>.from(data['timingScheme']?['settings'] ?? {}),
      timeController, perQuestionTimeController,
      typeTimingControllers, moduleTimingControllers, moduleTypeTimingControllers,
      modulesList, updateModuleTimingControllers,
    );

    final mType = data['markingScheme']?['type'] ?? 'default';
    updateState('markingType', mType);
    FormDataMapping.mapMarkingSchemeToControllers(
      Map<String, dynamic>.from(data['markingScheme'] ?? {}),
      globalCorrectController, globalWrongController,
      scCorrectController, scWrongController,
      mcCorrectController, mcWrongController,
      intCorrectController, intWrongController,
    );

    final lType = data['attemptLimits']?['type'] ?? 'none';
    updateState('attemptLimitType', lType);
    FormDataMapping.mapAttemptLimitsToControllers(
      Map<String, dynamic>.from(data['attemptLimits'] ?? {}),
      globalLimitControllers, moduleLimitControllers, (m) => updateModuleLimitControllers(),
    );

    final pqScheme = (data['markingScheme']?['perQuestion'] as Map?)?.cast<String, dynamic>() ?? {};
    final List<dynamic> rawModules = data['modules'] as List? ?? [];
    final List<Map<String, Object>> transformed = [];

    modulesList.clear();
    rawModules.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));

    for (var module in rawModules) {
      final String qSubject = module['subject'].toString();
      if (!modulesList.contains(qSubject)) modulesList.add(qSubject);
      for (var q in (module['data'] as List? ?? [])) {
        final qInfo = q['Q'] as Map;
        final qUid = qInfo['id'].toString();
        final qMarking = pqScheme[qUid] as Map? ?? {};
        final List<String> choiceTexts = (q['As'] as List? ?? []).map((o) => o['text'].toString()).toList();
        final List<String> correctUids = answersMap[qUid] ?? [];
        final List<String> correctTexts = (q['As'] as List? ?? []).where((o) => correctUids.contains(o['id'].toString())).map((o) => o['text'].toString()).toList();

        transformed.add({
          "subject": qSubject,
          "question": qInfo['text'].toString(),
          "choices": choiceTexts,
          "answers": correctTexts,
          "type": q['type'] ?? 'Single Choice',
          "correct": qMarking['correct'] ?? 4,
          "wrong": qMarking['wrong'] ?? -1,
          "timer": q['timer'] ?? 0,
          "description": solutionsMap[qUid] ?? '',
        });
      }
    }
    if (!modulesList.contains("General")) modulesList.add("General");
    questions..clear()..addAll(transformed);
  }

  static Future<void> importQuizData({
    required QuizImportResult result,
    required bool append,
    required TextEditingController titleController,
    required TextEditingController descriptionController,
    required TextEditingController examController,
    required TextEditingController timeController,
    required TextEditingController perQuestionTimeController,
    required TextEditingController allowedUsersController,
    required TextEditingController maxAttemptsController,
    required Map<String, TextEditingController> moduleTagControllers,
    required Map<String, TextEditingController> globalLimitControllers,
    required Map<String, Map<String, TextEditingController>> moduleLimitControllers,
    required Map<String, Map<String, TextEditingController>> moduleTimingControllers,
    required Map<String, Map<String, TextEditingController>> moduleTypeTimingControllers,
    required Map<String, TextEditingController> typeTimingControllers,
    required TextEditingController globalCorrectController,
    required TextEditingController globalWrongController,
    required TextEditingController scCorrectController,
    required TextEditingController scWrongController,
    required TextEditingController mcCorrectController,
    required TextEditingController mcWrongController,
    required TextEditingController intCorrectController,
    required TextEditingController intWrongController,
    required List<String> modulesList,
    required List<Map<String, Object>> questions,
    required Function(String, dynamic) updateState,
    required Function updateModuleLimitControllers,
    required Function updateModuleTimingControllers,
  }) async {
    if (!append) {
      if (result.title != null) titleController.text = result.title!;
      if (result.description != null) descriptionController.text = result.description!;
      if (result.examTag != null) examController.text = result.examTag!;
      if (result.maxAttempts != null) maxAttemptsController.text = result.maxAttempts.toString();
      if (result.moduleTags != null) {
        result.moduleTags!.forEach((module, tags) {
          moduleTagControllers.putIfAbsent(module, () => TextEditingController()).text = tags.join(', ');
        });
      }
      if (result.time != null) timeController.text = (result.time! ~/ 60).toString();
      if (result.perQuestionTime != null) perQuestionTimeController.text = result.perQuestionTime.toString();
      if (result.allowMultipleAttempts != null) updateState('allowMultipleAttempts', result.allowMultipleAttempts!);
      if (result.completeRandomShuffle != null) updateState('completeRandomShuffle', result.completeRandomShuffle!);
      if (result.shuffleModules != null) updateState('shuffleModules', result.shuffleModules!);
      if (result.shuffleQuestionsWithinModules != null) updateState('shuffleQuestionsWithinModules', result.shuffleQuestionsWithinModules!);
      if (result.disableModuleSwitchingUntilTimeout != null) updateState('disableModuleSwitchingUntilTimeout', result.disableModuleSwitchingUntilTimeout!);
      if (result.forceWaitUntilTimeout != null) updateState('forceWaitUntilTimeout', result.forceWaitUntilTimeout!);
      if (result.isRestricted != null) updateState('isRestricted', result.isRestricted!);
      if (result.allowedParticipants != null) allowedUsersController.text = result.allowedParticipants!.join(', ');

      if (result.timingScheme != null) {
        updateState('timingType', result.timingScheme!['type'] ?? 'global');
        final settings = result.timingScheme!['settings'] as Map?;
        if (settings != null) {
          FormDataMapping.mapTimingToControllers(
            settings.cast<String, dynamic>(),
            timeController, perQuestionTimeController,
            typeTimingControllers, moduleTimingControllers, moduleTypeTimingControllers,
            modulesList, updateModuleTimingControllers,
          );
        }
      }

      if (result.markingType != null) {
        updateState('markingType', result.markingType!);
        FormDataMapping.mapMarkingSchemeToControllers(
          {'type': result.markingType, 'global': result.markingGlobal, 'perQuestionType': result.markingPerType},
          globalCorrectController, globalWrongController,
          scCorrectController, scWrongController,
          mcCorrectController, mcWrongController,
          intCorrectController, intWrongController,
        );
      }

      if (result.attemptLimitType != null) {
        updateState('attemptLimitType', result.attemptLimitType!);
        FormDataMapping.mapAttemptLimitsToControllers(
          {'type': result.attemptLimitType, 'global': result.globalLimits, 'perModule': result.perModuleLimits},
          globalLimitControllers, moduleLimitControllers, (m) => updateModuleLimitControllers(),
        );
      }

      questions.clear();
      modulesList.clear();
      if (result.moduleOrder != null && result.moduleOrder!.isNotEmpty) {
        modulesList.addAll(result.moduleOrder!);
      } else {
        if (!modulesList.contains("General")) modulesList.add("General");
      }
      updateModuleLimitControllers();
      updateModuleTimingControllers();
    }

    for (var newQ in result.questions) {
      String subject = newQ['subject'] as String? ?? 'General';
      if (!modulesList.contains(subject)) {
        modulesList.add(subject);
        updateModuleLimitControllers();
        updateModuleTimingControllers();
      }

      int existingIndex = questions.indexWhere(
        (element) => element['question'].toString().trim().toLowerCase() == newQ['question'].toString().trim().toLowerCase(),
      );

      if (existingIndex != -1) {
        if (!QuizDataProcessor.isQuestionDataSame(questions[existingIndex], newQ)) questions[existingIndex] = newQ;
      } else {
        questions.add(newQ);
      }
    }
  }

  static Future<void> importFromQuizId({
    required String docId,
    required String uid,
    required List<String> modulesList,
    required List<Map<String, Object>> questions,
    required Function updateModuleLimitControllers,
    required Function(String, dynamic) updateState,
  }) async {
    final data = await global.db.readDatabase(docId, userId: uid);
    final response = await global.db.getQuizAnswers(docId, uid, from: 'quizform');
    final Map<String, List<String>> answersMap = response['answers'];
    final Map<String, String> solutionsMap = response['solutions'];

    updateState('isAiGenerated', true);
    final List<dynamic> rawModules = data['modules'] as List? ?? [];

    for (var module in rawModules) {
      final String qSubject = module['subject'].toString();
      if (!modulesList.contains(qSubject)) {
        modulesList.add(qSubject);
        updateModuleLimitControllers();
      }

      final List<dynamic> rawQuestions = module['data'] as List? ?? [];
      for (var q in rawQuestions) {
        final qInfo = q['Q'] as Map;
        final qUid = qInfo['id'].toString();
        final List<dynamic> opts = q['As'] as List;
        final List<String> choiceTexts = [];
        final List<String> correctTexts = [];
        final List<String> correctUids = answersMap[qUid] ?? [];

        for (var o in opts) {
          final oMap = o as Map;
          final oText = oMap['text'].toString();
          choiceTexts.add(oText);
          if (correctUids.contains(oMap['id'].toString())) correctTexts.add(oText);
        }

        final newQ = {
          "subject": qSubject,
          "question": qInfo['text'].toString(),
          "choices": choiceTexts,
          "answers": correctTexts,
          "type": q['type'] ?? 'Single Choice',
          "correct": 4,
          "wrong": -1,
          "timer": q['timer'] ?? 0,
          "description": solutionsMap[qUid] ?? '',
        };

        int existingIndex = questions.indexWhere(
          (element) => element['question'].toString().trim().toLowerCase() == newQ['question'].toString().trim().toLowerCase(),
        );
        if (existingIndex == -1) questions.add(newQ as Map<String, Object>);
      }
    }
  }
}
