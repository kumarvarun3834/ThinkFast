import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/utils/global.dart' as global;

class TimingConfigPanel extends StatelessWidget {
  final String timingType;
  final ValueChanged<String> onTypeChanged;
  final TextEditingController timeController;
  final TextEditingController perQuestionTimeController;
  final List<String> modulesList;
  final Map<String, Map<String, TextEditingController>> moduleTimingControllers;
  final Map<String, TextEditingController> typeTimingControllers;

  const TimingConfigPanel({
    super.key,
    required this.timingType,
    required this.onTypeChanged,
    required this.timeController,
    required this.perQuestionTimeController,
    required this.modulesList,
    required this.moduleTimingControllers,
    required this.typeTimingControllers,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Timing Configuration",
          style: GoogleFonts.poppins(
            color: global.valueColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          dropdownColor: global.cardColor,
          value: timingType,
          style: const TextStyle(color: global.valueColor),
          items: const [
            DropdownMenuItem(value: "global", child: Text("Global Timer")),
            DropdownMenuItem(
              value: "per_question",
              child: Text("Per Question Default"),
            ),
            DropdownMenuItem(
              value: "per_module",
              child: Text("Per Module Settings"),
            ),
            DropdownMenuItem(
              value: "per_question_type",
              child: Text("Per Question Type"),
            ),
          ],
          onChanged: (v) {
            if (v != null) onTypeChanged(v);
          },
          decoration: const InputDecoration(labelText: "Timing Mode"),
        ),
        if (timingType == "global") ...[
          const SizedBox(height: 16),
          TextField(
            controller: timeController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: global.valueColor),
            decoration: const InputDecoration(
              labelText: "Global Quiz Time (seconds)",
              hintText: "e.g. 600 for 10 minutes",
            ),
          ),
        ],
        if (timingType == "per_question") ...[
          const SizedBox(height: 16),
          TextField(
            controller: perQuestionTimeController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: global.valueColor),
            decoration: const InputDecoration(
              labelText: "Default Time Per Question (seconds)",
            ),
          ),
        ],
        if (timingType == "per_question_type") ...[
          const SizedBox(height: 16),
          _buildTimingRow(
            "Single Choice",
            typeTimingControllers["Single Choice"]!,
          ),
          const SizedBox(height: 8),
          _buildTimingRow(
            "Multiple Choice",
            typeTimingControllers["Multiple Choice"]!,
          ),
          const SizedBox(height: 8),
          _buildTimingRow("Integer", typeTimingControllers["Integer"]!),
        ],
        if (timingType == "per_module") ...[
          const SizedBox(height: 16),
          ...modulesList.map((m) {
            final controllers = moduleTimingControllers[m];
            if (controllers == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Container(
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
                      m.toUpperCase(),
                      style: const TextStyle(
                        color: global.primaryAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTimingRow("Module Total Time", controllers["total"]!),
                    const SizedBox(height: 8),
                    _buildTimingRow(
                      "Per Question in Module",
                      controllers["perQuestion"]!,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildTimingRow(String label, TextEditingController controller) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(color: global.valueColor, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: global.valueColor, fontSize: 14),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              hintText: "0",
            ),
          ),
        ),
      ],
    );
  }
}
