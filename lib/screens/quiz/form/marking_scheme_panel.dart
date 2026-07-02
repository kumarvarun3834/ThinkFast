import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/utils/global.dart' as global;

class MarkingSchemePanel extends StatelessWidget {
  final bool isAdmin;
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
    required this.isAdmin,
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
    if (!isAdmin && markingType == "default") return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Marking Scheme",
          style: GoogleFonts.poppins(
            color: global.valueColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        AbsorbPointer(
          absorbing: !isAdmin,
          child: Opacity(
            opacity: isAdmin ? 1.0 : 0.6,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  dropdownColor: global.cardColor,
                  value: markingType,
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
                      child: Text("Per Question"),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) onTypeChanged(v);
                  },
                  decoration: const InputDecoration(labelText: "Scheme Type"),
                ),
                if (markingType == "entire_quiz") ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: globalCorrectController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: global.valueColor),
                          decoration: const InputDecoration(
                            labelText: "Correct Score",
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
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (markingType == "per_question_type") ...[
                  const SizedBox(height: 16),
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
              ],
            ),
          ),
        ),
        if (!isAdmin)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              "Note: Only administrators can modify the marking scheme.",
              style: TextStyle(
                color: Colors.orangeAccent.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ),
      ],
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
        color: global.cardColor,
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
                  decoration: const InputDecoration(labelText: "Correct"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: wrong,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: global.valueColor),
                  decoration: const InputDecoration(labelText: "Wrong"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
