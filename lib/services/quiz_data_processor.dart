import 'dart:convert';
import 'package:http/http.dart' as http;

class QuizImportResult {
  final String? title;
  final String? description;
  final int? time;
  final int? perQuestionTime;
  final String? markingType;
  final Map<String, dynamic>? markingGlobal;
  final Map<String, dynamic>? markingPerType;
  final Map<String, dynamic>? markingPerQuestion;
  final String? attemptLimitType;
  final Map<String, dynamic>? globalLimits;
  final Map<String, dynamic>? perModuleLimits;
  final List<Map<String, Object>> questions;

  QuizImportResult({
    this.title,
    this.description,
    this.time,
    this.perQuestionTime,
    this.markingType,
    this.markingGlobal,
    this.markingPerType,
    this.markingPerQuestion,
    this.attemptLimitType,
    this.globalLimits,
    this.perModuleLimits,
    required this.questions,
  });
}

class QuizDataProcessor {
  static Future<QuizImportResult> processImportData(String input) async {
    String jsonContent = input;
    if (input.startsWith("http")) {
      final response = await http.get(Uri.parse(input));
      if (response.statusCode == 200) {
        jsonContent = response.body;
      } else {
        throw Exception("Failed to fetch data from link");
      }
    }

    final dynamic decoded = jsonDecode(jsonContent);
    final Map<String, dynamic> data =
        decoded is List ? {"data": decoded} : decoded;

    String? title = data['title']?.toString();
    String? description = data['description']?.toString();
    int? time;
    if (data['time'] != null) {
      time = (data['time'] is int)
          ? data['time']
          : (int.tryParse(data['time'].toString()) ?? 0);
    }
    int? perQuestionTime = data['perQuestionTime'] != null 
        ? int.tryParse(data['perQuestionTime'].toString()) 
        : null;

    String? markingType;
    Map<String, dynamic>? markingGlobal;
    Map<String, dynamic>? markingPerType;
    Map<String, dynamic>? markingPerQuestion;

    if (data['markingScheme'] != null) {
      final scheme = data['markingScheme'] as Map;
      markingType = scheme['type']?.toString() ?? 'default';
      
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
      markingType: markingType,
      markingGlobal: markingGlobal,
      markingPerType: markingPerType,
      markingPerQuestion: markingPerQuestion,
      attemptLimitType: attemptLimitType,
      globalLimits: globalLimits,
      perModuleLimits: perModuleLimits,
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
