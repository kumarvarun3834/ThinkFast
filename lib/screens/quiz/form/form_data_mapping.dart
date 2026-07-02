import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FormDataMapping {
  static void mapMarkingSchemeToControllers(
    Map<String, dynamic> scheme,
    TextEditingController globalCorrectController,
    TextEditingController globalWrongController,
    TextEditingController scCorrectController,
    TextEditingController scWrongController,
    TextEditingController mcCorrectController,
    TextEditingController mcWrongController,
    TextEditingController intCorrectController,
    TextEditingController intWrongController,
  ) {
    final type = scheme['type'] ?? 'default';
    if (type == 'entire_quiz') {
      globalCorrectController.text =
          (scheme['global']?['correct'] ?? 4).toString();
      globalWrongController.text = (scheme['global']?['wrong'] ?? -1).toString();
    } else if (type == 'per_question_type') {
      final pqt = scheme['perQuestionType'] as Map? ?? {};
      scCorrectController.text =
          (pqt['Single Choice']?['correct'] ?? 4).toString();
      scWrongController.text = (pqt['Single Choice']?['wrong'] ?? -1).toString();
      mcCorrectController.text =
          (pqt['Multiple Choice']?['correct'] ?? 4).toString();
      mcWrongController.text =
          (pqt['Multiple Choice']?['wrong'] ?? -1).toString();
      intCorrectController.text = (pqt['Integer']?['correct'] ?? 4).toString();
      intWrongController.text = (pqt['Integer']?['wrong'] ?? -1).toString();
    }
  }

  static void mapAttemptLimitsToControllers(
    Map<String, dynamic> limits,
    Map<String, TextEditingController> globalLimitControllers,
    Map<String, Map<String, TextEditingController>> moduleLimitControllers,
    Function(String) updateModuleLimitControllers,
  ) {
    final type = limits['type'] ?? 'none';
    if (type == 'global') {
      final g = limits['global'] as Map? ?? {};
      globalLimitControllers['Single Choice']?.text =
          (g['Single Choice'] ?? '').toString();
      globalLimitControllers['Multiple Choice']?.text =
          (g['Multiple Choice'] ?? '').toString();
      globalLimitControllers['Integer']?.text = (g['Integer'] ?? '').toString();
    } else if (type == 'per_module') {
      final pm = limits['perModule'] as Map? ?? {};
      pm.forEach((module, values) {
        updateModuleLimitControllers(module);
        final mLimits = values as Map? ?? {};
        moduleLimitControllers[module]?['Single Choice']?.text =
            (mLimits['Single Choice'] ?? '').toString();
        moduleLimitControllers[module]?['Multiple Choice']?.text =
            (mLimits['Multiple Choice'] ?? '').toString();
        moduleLimitControllers[module]?['Integer']?.text =
            (mLimits['Integer'] ?? '').toString();
      });
    }
  }

  static void mapTimingToControllers(
    Map<String, dynamic> settings,
    TextEditingController timeController,
    TextEditingController perQuestionTimeController,
    Map<String, TextEditingController> typeTimingControllers,
    Map<String, Map<String, TextEditingController>> moduleTimingControllers,
    List<String> modulesList,
    Function updateModuleTimingControllers,
  ) {
    if (settings['globalTotal'] != null) {
      timeController.text = settings['globalTotal'].toString();
    }
    if (settings['perQuestionDefault'] != null) {
      perQuestionTimeController.text =
          settings['perQuestionDefault'].toString();
    }
    if (settings['perType'] != null) {
      (settings['perType'] as Map).forEach((type, val) {
        typeTimingControllers[type]?.text = val.toString();
      });
    }
    if (settings['perModule'] != null) {
      (settings['perModule'] as Map).forEach((module, val) {
        if (!modulesList.contains(module)) modulesList.add(module);
        updateModuleTimingControllers();
        if (val is Map) {
          moduleTimingControllers[module]?['total']?.text =
              (val['total'] ?? 0).toString();
          moduleTimingControllers[module]?['perQuestion']?.text =
              (val['perQuestion'] ?? 0).toString();
        } else {
          moduleTimingControllers[module]?['total']?.text = val.toString();
        }
      });
    }
  }
}
