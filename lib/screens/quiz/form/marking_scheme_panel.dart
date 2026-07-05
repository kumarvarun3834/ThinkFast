import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/utils/global.dart' as global;

class MarkingSchemePanel extends StatelessWidget {
  final bool canEdit;
  final String markingType;
  final ValueChanged<String> onTypeChanged;
  final TextEditingController globalCorrectController;
  final TextEditingController globalWrongController;
  final TextEditingController scCorrectController;
  final TextEditingController scWrongController;
  final TextEditingController mcCorrectController;
  final TextEditingController mcWrongController;
  final TextEditingController intCorrectController;
  final TextEditingController intWrongController;

  const MarkingSchemePanel({
    super.key,
    required this.canEdit,
    required this.markingType,
    required this.onTypeChanged,
    required this.globalCorrectController,
    required this.globalWrongController,
    required this.scCorrectController,
    required this.scWrongController,
    required this.mcCorrectController,
    required this.mcWrongController,
    required this.intCorrectController,
    required this.intWrongController,
  });

  @override
  Widget build(BuildContext context) {
    if (!canEdit && markingType == "default") return const SizedBox.shrink();
    return Material(
      color: global.cardColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: global.borderColor),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.grade_outlined, color: global.primaryAccent),
                const SizedBox(width: 12),
                Text(
                  "Marking Scheme",
                  style: GoogleFonts.poppins(
                    color: global.valueColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AbsorbPointer(
              absorbing: !canEdit,
              child: Opacity(
                opacity: canEdit ? 1.0 : 0.6,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      dropdownColor: global.cardColor,
                      initialValue: markingType,
                      style: const TextStyle(color: global.valueColor),
                      items: const [
                        DropdownMenuItem(
                          value: "default",
                          child: Text("Default (+4, -1)"),
                        ),
                        DropdownMenuItem(
                          value: "entire_quiz",
                          child: Text("Custom Global"),
                        ),
                        DropdownMenuItem(
                          value: "per_question_type",
                          child: Text("Per Question Type"),
                        ),
                        DropdownMenuItem(
                          value: "per_question",
                          child: Text("Per Question (Individual)"),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) onTypeChanged(v);
                      },
                      decoration: const InputDecoration(
                        labelText: "Scheme Type",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (markingType == "entire_quiz") _buildGlobalMarkingBlock(),
                    if (markingType == "per_question_type")
                      _buildPerTypeMarkingBlock(),
                    if (markingType == "per_question")
                      _buildPerQuestionInfoBlock(),
                  ],
                ),
              ),
            ),
            if (!canEdit)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(
                  "Note: Only the quiz owner or administrators can modify the marking scheme.",
                  style: TextStyle(
                    color: Colors.orangeAccent.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalMarkingBlock() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: globalCorrectController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: global.valueColor),
              decoration: const InputDecoration(
                labelText: "Correct Score",
                prefixIcon: Icon(Icons.add_task_rounded, color: Colors.greenAccent, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: globalWrongController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: global.valueColor),
              decoration: const InputDecoration(
                labelText: "Wrong Score",
                prefixIcon: Icon(Icons.unpublished_rounded, color: Colors.redAccent, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerTypeMarkingBlock() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        children: [
          _buildTypeMarkingRow(
            "Single Choice",
            scCorrectController,
            scWrongController,
          ),
          const SizedBox(height: 12),
          _buildTypeMarkingRow(
            "Multiple Choice",
            mcCorrectController,
            mcWrongController,
          ),
          const SizedBox(height: 12),
          _buildTypeMarkingRow(
            "Integer",
            intCorrectController,
            intWrongController,
          ),
        ],
      ),
    );
  }

  Widget _buildPerQuestionInfoBlock() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.blueAccent, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "In this mode, you can set custom scores for each question directly in the questions list below.",
              style: TextStyle(color: global.valueColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeMarkingRow(
    String type,
    TextEditingController correct,
    TextEditingController wrong,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: global.cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: global.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            type,
            style: const TextStyle(
              color: global.primaryAccent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: correct,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: global.valueColor),
                  decoration: const InputDecoration(
                    labelText: "Correct",
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: wrong,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: global.valueColor),
                  decoration: const InputDecoration(
                    labelText: "Wrong",
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
