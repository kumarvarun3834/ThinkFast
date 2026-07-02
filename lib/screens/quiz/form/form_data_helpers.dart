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
    if (attemptLimitType == "global") {
      attemptLimits['global'] = {
        'Single Choice': int.tryParse(globalLimitControllers['Single Choice']!.text),
        'Multiple Choice': int.tryParse(globalLimitControllers['Multiple Choice']!.text),
        'Integer': int.tryParse(globalLimitControllers['Integer']!.text),
      };
    } else if (attemptLimitType == "per_module") {
      final Map<String, dynamic> perModule = {};
      moduleLimitControllers.forEach((module, controllers) {
        perModule[module] = {
          'Single Choice': int.tryParse(controllers['Single Choice']!.text),
          'Multiple Choice': int.tryParse(controllers['Multiple Choice']!.text),
          'Integer': int.tryParse(controllers['Integer']!.text),
        };
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
      },
    };
  }

  static List<String> parseAllowedParticipants(String input) {
    return input
        .split(',')
        .map((e) => e.trim())
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
