import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:thinkfast/services/api_client.dart';

class QuizImportResult {
  final String? title;
  final String? description;
  final int? time;
  final int? perQuestionTime;
  final bool? allowMultipleAttempts;
  final int? maxAttempts;
  final bool? completeRandomShuffle;
  final bool? shuffleModules;
  final bool? shuffleQuestionsWithinModules;
  final bool? disableModuleSwitchingUntilTimeout;
  final bool? forceWaitUntilTimeout;
  final String? markingType;
  final int? markingPassThreshold;
  final Map<String, dynamic>? markingGlobal;
  final Map<String, dynamic>? markingPerType;
  final Map<String, dynamic>? markingPerQuestion;
  final String? attemptLimitType;
  final Map<String, dynamic>? globalLimits;
  final Map<String, dynamic>? perModuleLimits;
  final String? examTag;
  final Map<String, List<String>>? moduleTags;
  final bool? isRestricted;
  final List<String>? allowedParticipants;
  final Map<String, dynamic>? timingScheme;
  final List<String>? moduleOrder;
  final List<Map<String, Object>> questions;

  QuizImportResult({
    this.title,
    this.description,
    this.time,
    this.perQuestionTime,
    this.allowMultipleAttempts,
    this.maxAttempts,
    this.completeRandomShuffle,
    this.shuffleModules,
    this.shuffleQuestionsWithinModules,
    this.disableModuleSwitchingUntilTimeout,
    this.forceWaitUntilTimeout,
    this.markingType,
    this.markingPassThreshold,
    this.markingGlobal,
    this.markingPerType,
    this.markingPerQuestion,
    this.attemptLimitType,
    this.globalLimits,
    this.perModuleLimits,
    this.examTag,
    this.moduleTags,
    this.isRestricted,
    this.allowedParticipants,
    this.timingScheme,
    this.moduleOrder,
    required this.questions,
  });
}

class QuizDataProcessor {
  static Future<QuizImportResult> processImportData(String input) async {
    String jsonContent = input;
    if (input.startsWith("http")) {
      final response = await ApiClient.instance.get(input);
      if (response.statusCode == 200) {
        jsonContent = response.data.toString();
      } else {
        throw Exception("Failed to fetch data from link");
      }
    }

    final dynamic decoded = jsonDecode(jsonContent);
    final Map<String, dynamic> data =
        decoded is List ? {"data": decoded} : decoded;

    String? title = data['title']?.toString();
    String? description = data['description']?.toString();
    String? examTag = data['examTag']?.toString();
    Map<String, List<String>>? moduleTags;
    if (data['moduleTags'] != null) {
      moduleTags = (data['moduleTags'] as Map).map(
        (key, value) => MapEntry(key.toString(), List<String>.from(value as List)),
      );
    }

    int? time;
    if (data['time'] != null) {
      time = (data['time'] is int)
          ? data['time']
          : (int.tryParse(data['time'].toString()) ?? 0);
    }
    int? perQuestionTime = data['perQuestionTime'] != null 
        ? int.tryParse(data['perQuestionTime'].toString()) 
        : null;

    bool? allowMultipleAttempts = data['allowMultipleAttempts'];
    int? maxAttempts = data['maxAttempts'] != null 
        ? int.tryParse(data['maxAttempts'].toString()) 
        : null;
    bool? completeRandomShuffle = data['completeRandomShuffle'];
    bool? shuffleModules = data['shuffleModules'];
    bool? shuffleQuestionsWithinModules = data['shuffleQuestionsWithinModules'];
    bool? disableModuleSwitchingUntilTimeout = data['disableModuleSwitchingUntilTimeout'];
    bool? forceWaitUntilTimeout = data['forceWaitUntilTimeout'];
    bool? isRestricted = data['isRestricted'];
    List<String>? allowedParticipants = data['allowedParticipants'] != null 
        ? List<String>.from(data['allowedParticipants'] as List) 
        : null;

    Map<String, dynamic>? timingScheme;
    if (data['timingScheme'] != null) {
      timingScheme = Map<String, dynamic>.from(data['timingScheme'] as Map);
    } else if (data['timing'] != null) {
      // Legacy or alternative field name
      timingScheme = Map<String, dynamic>.from(data['timing'] as Map);
    }

    String? markingType;
    int? markingPassThreshold;
    Map<String, dynamic>? markingGlobal;
    Map<String, dynamic>? markingPerType;
    Map<String, dynamic>? markingPerQuestion;

    if (data['markingScheme'] != null) {
      final scheme = data['markingScheme'] as Map;
      markingType = scheme['type']?.toString() ?? 'default';
      markingPassThreshold = int.tryParse(scheme['passThreshold']?.toString() ?? '40');
      
      if (scheme['global'] != null) {
        markingGlobal = Map<String, dynamic>.from(scheme['global'] as Map);
      }
      if (scheme['perQuestionType'] != null) {
        markingPerType = Map<String, dynamic>.from(scheme['perQuestionType'] as Map);
      }
      if (scheme['perQuestion'] != null) {
        markingPerQuestion = Map<String, dynamic>.from(scheme['perQuestion'] as Map);
      }
    }

    String? attemptLimitType;
    Map<String, dynamic>? globalLimits;
    Map<String, dynamic>? perModuleLimits;
    if (data['attemptLimits'] != null) {
      final limits = data['attemptLimits'] as Map;
      attemptLimitType = limits['type'] ?? 'none';
      if (attemptLimitType == 'global') {
        globalLimits = Map<String, dynamic>.from(limits['global'] as Map? ?? {});
      } else if (attemptLimitType == 'per_module') {
        perModuleLimits = Map<String, dynamic>.from(limits['perModule'] as Map? ?? {});
      }
    }

    List<String>? moduleOrder = data['moduleOrder'] != null 
        ? List<String>.from(data['moduleOrder'] as List) 
        : null;

    final List<Map<String, Object>> questions = [];
    final List<dynamic> rawData = (data['data'] ?? data['questions'] ?? []) as List;

    for (var q in rawData) {
      String subject = q['subject']?.toString() ?? 'General';
      Map<String, Object> newQ;

      // Support both internal format and external easy format
      if (q['Q'] != null) {
        final qInfo = q['Q'] as Map;
        final qText = qInfo['text'].toString();
        final List<dynamic> opts = q['As'] as List;
        final List<String> choiceTexts =
            opts.map((o) => (o as Map)['text'].toString()).toList();

        newQ = {
          "question": qText,
          "choices": choiceTexts,
          "answers": <String>[],
          "type": q['type'] ?? 'Single Choice',
          "subject": subject,
          "correct": 4,
          "wrong": -1,
          "timer": q['timer'] ?? 0,
          "description": "",
        };
      } else {
        newQ = {
          "question": q['question']?.toString() ?? '',
          "choices": List<String>.from(q['choices'] ?? []),
          "answers": List<String>.from(q['answers'] ?? []),
          "type": q['type'] ?? 'Single Choice',
          "correct": q['correct'] ?? 4,
          "wrong": q['wrong'] ?? -1,
          "subject": subject,
          "timer": q['timer'] ?? 0,
          "description": q['description'] ?? '',
        };
      }
      questions.add(newQ);
    }

    return QuizImportResult(
      title: title,
      description: description,
      time: time,
      perQuestionTime: perQuestionTime,
      allowMultipleAttempts: allowMultipleAttempts,
      maxAttempts: maxAttempts,
      completeRandomShuffle: completeRandomShuffle,
      shuffleModules: shuffleModules,
      shuffleQuestionsWithinModules: shuffleQuestionsWithinModules,
      disableModuleSwitchingUntilTimeout: disableModuleSwitchingUntilTimeout,
      forceWaitUntilTimeout: forceWaitUntilTimeout,
      markingType: markingType,
      markingPassThreshold: markingPassThreshold,
      markingGlobal: markingGlobal,
      markingPerType: markingPerType,
      markingPerQuestion: markingPerQuestion,
      attemptLimitType: attemptLimitType,
      globalLimits: globalLimits,
      perModuleLimits: perModuleLimits,
      examTag: examTag,
      moduleTags: moduleTags,
      isRestricted: isRestricted,
      allowedParticipants: allowedParticipants,
      timingScheme: timingScheme,
      moduleOrder: moduleOrder,
      questions: questions,
    );
  }

  static bool isQuestionDataSame(Map<String, Object> q1, Map<String, Object> q2) {
    if (q1['type'] != q2['type']) return false;
    if (q1['subject'] != q2['subject']) return false;
    if (q1['correct'] != q2['correct']) return false;
    if (q1['wrong'] != q2['wrong']) return false;
    if (q1['description'] != q2['description']) return false;

    // Compare choices
    final List c1 = q1['choices'] as List? ?? [];
    final List c2 = q2['choices'] as List? ?? [];
    if (c1.length != c2.length) return false;
    for (int i = 0; i < c1.length; i++) {
      if (c1[i].toString() != c2[i].toString()) return false;
    }

    // Compare answers
    final List a1 = q1['answers'] as List? ?? [];
    final List a2 = q2['answers'] as List? ?? [];
    if (a1.length != a2.length) return false;
    for (int i = 0; i < a1.length; i++) {
      if (a1[i].toString() != a2[i].toString()) return false;
    }

    return true;
  }
}
