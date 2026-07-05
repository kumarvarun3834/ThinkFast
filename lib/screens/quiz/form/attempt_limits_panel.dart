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
                const Icon(Icons.rule_folder_outlined, color: global.primaryAccent),
                const SizedBox(width: 12),
                Text(
                  "Attempt Limits",
                  style: GoogleFonts.poppins(
                    color: global.valueColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Limit how many questions (e.g. answer any 5 out of 10) user can answer.",
              style: GoogleFonts.poppins(color: global.labelColor, fontSize: 11),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              dropdownColor: global.cardColor,
              initialValue: attemptLimitType,
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
              decoration: const InputDecoration(
                labelText: "Limit Mode",
                border: OutlineInputBorder(),
              ),
            ),
            if (attemptLimitType == "global") _buildGlobalLimitBlock(),
            if (attemptLimitType == "per_module") _buildPerModuleLimitBlock(),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalLimitBlock() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        children: [
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
      ),
    );
  }

  Widget _buildPerModuleLimitBlock() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        children: modulesList.map((m) {
          final controllers = moduleLimitControllers[m];
          if (controllers == null) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: global.cardColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: global.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.folder_outlined,
                      size: 16,
                      color: global.primaryAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      m.toUpperCase(),
                      style: const TextStyle(
                        color: global.primaryAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildLimitRow(
                  "Single Choice",
                  controllers["Single Choice"]!,
                  small: true,
                ),
                const SizedBox(height: 8),
                _buildLimitRow(
                  "Multiple Choice",
                  controllers["Multiple Choice"]!,
                  small: true,
                ),
                const SizedBox(height: 8),
                _buildLimitRow(
                  "Integer",
                  controllers["Integer"]!,
                  small: true,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLimitRow(
    String label,
    TextEditingController controller, {
    bool small = false,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              color: global.valueColor,
              fontSize: small ? 12 : 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: small ? 36 : 45,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                color: global.valueColor,
                fontSize: small ? 13 : 14,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                hintText: "Unlimited",
                hintStyle: const TextStyle(fontSize: 10, color: global.labelColor),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: global.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: global.primaryAccent),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
