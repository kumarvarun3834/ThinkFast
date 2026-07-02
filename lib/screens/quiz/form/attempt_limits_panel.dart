import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/utils/global.dart' as global;

class AttemptLimitsPanel extends StatelessWidget {
  final String attemptLimitType;
  final ValueChanged<String> onTypeChanged;
  final List<String> modulesList;
  final Map<String, TextEditingController> globalLimitControllers;
  final Map<String, Map<String, TextEditingController>> moduleLimitControllers;

  const AttemptLimitsPanel({
    super.key,
    required this.attemptLimitType,
    required this.onTypeChanged,
    required this.modulesList,
    required this.globalLimitControllers,
    required this.moduleLimitControllers,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Attempt Limits (Select N out of M)",
          style: GoogleFonts.poppins(
            color: global.valueColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Limit how many questions of each type a user can answer.",
          style: GoogleFonts.poppins(color: global.labelColor, fontSize: 12),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          dropdownColor: global.cardColor,
          value: attemptLimitType,
          style: const TextStyle(color: global.valueColor),
          items: const [
            DropdownMenuItem(value: "none", child: Text("No Limits")),
            DropdownMenuItem(
              value: "global",
              child: Text("Same for all modules"),
            ),
            DropdownMenuItem(
              value: "per_module",
              child: Text("Different for each module"),
            ),
          ],
          onChanged: (v) {
            if (v != null) onTypeChanged(v);
          },
          decoration: const InputDecoration(labelText: "Limit Mode"),
        ),
        if (attemptLimitType == "global") ...[
          const SizedBox(height: 16),
          _buildLimitRow(
            "Single Choice",
            globalLimitControllers["Single Choice"]!,
          ),
          const SizedBox(height: 12),
          _buildLimitRow(
            "Multiple Choice",
            globalLimitControllers["Multiple Choice"]!,
          ),
          const SizedBox(height: 12),
          _buildLimitRow("Integer", globalLimitControllers["Integer"]!),
        ],
        if (attemptLimitType == "per_module") ...[
          const SizedBox(height: 16),
          ...modulesList.map((m) {
            final controllers = moduleLimitControllers[m];
            if (controllers == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
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
                    _buildLimitRow(
                      "Single Choice",
                      controllers["Single Choice"]!,
                      dense: true,
                    ),
                    const SizedBox(height: 8),
                    _buildLimitRow(
                      "Multiple Choice",
                      controllers["Multiple Choice"]!,
                      dense: true,
                    ),
                    const SizedBox(height: 8),
                    _buildLimitRow(
                      "Integer",
                      controllers["Integer"]!,
                      dense: true,
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

  Widget _buildLimitRow(
    String label,
    TextEditingController controller, {
    bool dense = false,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              color: global.valueColor,
              fontSize: dense ? 13 : 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: global.valueColor, fontSize: 14),
            decoration: InputDecoration(
              contentPadding: dense
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                  : null,
              hintText: "No Limit",
              hintStyle: const TextStyle(color: global.hintColor, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
