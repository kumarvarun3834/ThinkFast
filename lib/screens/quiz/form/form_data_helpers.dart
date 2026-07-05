import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FormDataHelpers {
  static Map<String, dynamic> prepareMarkingScheme({
    required String markingType,
    required TextEditingController globalCorrectController,
    required TextEditingController globalWrongController,
    required TextEditingController scCorrectController,
    required TextEditingController scWrongController,
    required TextEditingController mcCorrectController,
    required TextEditingController mcWrongController,
    required TextEditingController intCorrectController,
    required TextEditingController intWrongController,
  }) {
    final Map<String, dynamic> markingScheme = {'type': markingType};
    if (markingType == 'entire_quiz') {
      markingScheme['global'] = {
        'correct': int.tryParse(globalCorrectController.text) ?? 4,
        'wrong': int.tryParse(globalWrongController.text) ?? -1,
      };
    } else if (markingType == 'per_question_type') {
      markingScheme['perQuestionType'] = {
        'Single Choice': {
          'correct': int.tryParse(scCorrectController.text) ?? 4,
          'wrong': int.tryParse(scWrongController.text) ?? -1,
        },
        'Multiple Choice': {
          'correct': int.tryParse(mcCorrectController.text) ?? 4,
          'wrong': int.tryParse(mcWrongController.text) ?? -1,
        },
        'Integer': {
          'correct': int.tryParse(intCorrectController.text) ?? 4,
          'wrong': int.tryParse(intWrongController.text) ?? -1,
        },
      };
    }
    return markingScheme;
  }

  static Map<String, dynamic> prepareAttemptLimits({
    required String attemptLimitType,
    required Map<String, TextEditingController> globalLimitControllers,
    required Map<String, Map<String, TextEditingController>> moduleLimitControllers,
  }) {
    final Map<String, dynamic> attemptLimits = {'type': attemptLimitType};

    int? parseLimit(String text) {
      final val = int.tryParse(text);
      if (val == null || val <= 0) return null; // 0 or negative = No Limit
      return val;
    }

    if (attemptLimitType == "global") {
      final Map<String, int> limits = {};
      globalLimitControllers.forEach((type, controller) {
        final l = parseLimit(controller.text);
        if (l != null) limits[type] = l;
      });
      attemptLimits['global'] = limits;
    } else if (attemptLimitType == "per_module") {
      final Map<String, dynamic> perModule = {};
      moduleLimitControllers.forEach((module, controllers) {
        final Map<String, int> limits = {};
        controllers.forEach((type, controller) {
          final l = parseLimit(controller.text);
          if (l != null) limits[type] = l;
        });
        perModule[module] = limits;
      });
      attemptLimits['perModule'] = perModule;
    }
    return attemptLimits;
  }

  static Map<String, dynamic> prepareTimingScheme({
    required String timingType,
    required int time,
    required int perQuestionTime,
    required Map<String, TextEditingController> typeTimingControllers,
    required Map<String, Map<String, TextEditingController>> moduleTimingControllers,
    required Map<String, Map<String, TextEditingController>> moduleTypeTimingControllers,
  }) {
    return {
      'type': timingType,
      'settings': {
        'globalTotal': time,
        'perQuestionDefault': perQuestionTime,
        'perType': typeTimingControllers.map(
          (k, v) => MapEntry(k, int.tryParse(v.text) ?? 0),
        ),
        'perModule': moduleTimingControllers.map(
          (k, v) => MapEntry(
            k,
            {
              'total': int.tryParse(v['total']!.text) ?? 0,
              'perQuestion': int.tryParse(v['perQuestion']!.text) ?? 0,
            },
          ),
        ),
        'perModuleType': moduleTypeTimingControllers.map(
          (m, types) => MapEntry(
            m,
            types.map((t, c) => MapEntry(t, int.tryParse(c.text) ?? 0)),
          ),
        ),
      },
    };
  }

  static List<String> parseAllowedParticipants(String input) {
    return input
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static Map<String, List<String>> parseModuleTags(
    Map<String, TextEditingController> moduleTagControllers,
    List<Map<String, Object>> questions,
  ) {
    final Map<String, List<String>> moduleTagsMap = {};
    moduleTagControllers.forEach((module, controller) {
      final tagsList = controller.text
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList();
      if (tagsList.isNotEmpty && questions.any((q) => q['subject'] == module)) {
        moduleTagsMap[module] = tagsList;
      }
    });
    return moduleTagsMap;
  }
}
