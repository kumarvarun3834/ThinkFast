import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/add_quiz_data.dart';
import 'package:thinkfast/utils/global.dart' as global;

class QuestionsListSection extends StatelessWidget {
  final List<String> modulesList;
  final List<Map<String, Object>> questions;
  final Map<String, GlobalKey> moduleKeys;
  final Map<int, GlobalKey> questionKeys;
  final String markingType;
  final String timingType;
  final Function(int, Map<String, Object>) onUpdateFormData;
  final Function(int) onRemoveForm;

  const QuestionsListSection({
    super.key,
    required this.modulesList,
    required this.questions,
    required this.moduleKeys,
    required this.questionKeys,
    required this.markingType,
    required this.timingType,
    required this.onUpdateFormData,
    required this.onRemoveForm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: modulesList.map((module) {
        final moduleQuestions = questions
            .asMap()
            .entries
            .where((e) => e.value['subject'] == module)
            .toList();
        if (moduleQuestions.isEmpty) {
          return const SizedBox.shrink();
        }
        final key = moduleKeys.putIfAbsent(
          module,
          () => GlobalKey(),
        );

        return Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.folder_open_rounded,
                    color: Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    module.toUpperCase(),
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF3B82F6),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Divider(
                      color: const Color(
                        0xFF3B82F6,
                      ).withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
            ...moduleQuestions.map((entry) {
              final index = entry.key;
              final qKey = questionKeys.putIfAbsent(
                index,
                () => GlobalKey(),
              );
              return Card(
                key: qKey,
                color: global.cardColor,
                margin: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(
                    color: global.borderColor,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      QuizForm(
                        formDataPart: questions[index],
                        onChanged: (d) => onUpdateFormData(index, d),
                        showIndividualMarking: markingType == "per_question",
                        showIndividualTiming: timingType == "per_question",
                        moduleOptions: modulesList,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: global.errorColor,
                          ),
                          onPressed: () => onRemoveForm(index),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      }).toList(),
    );
  }
}
