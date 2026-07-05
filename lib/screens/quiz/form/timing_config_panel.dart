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
  final Map<String, Map<String, TextEditingController>> moduleTypeTimingControllers;
  final Map<String, TextEditingController> typeTimingControllers;

  const TimingConfigPanel({
    super.key,
    required this.timingType,
    required this.onTypeChanged,
    required this.timeController,
    required this.perQuestionTimeController,
    required this.modulesList,
    required this.moduleTimingControllers,
    required this.moduleTypeTimingControllers,
    required this.typeTimingControllers,
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
                const Icon(Icons.timer_outlined, color: global.primaryAccent),
                const SizedBox(width: 12),
                Text(
                  "Timing Configuration",
                  style: GoogleFonts.poppins(
                    color: global.valueColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              dropdownColor: global.cardColor,
              initialValue: timingType,
              style: const TextStyle(color: global.valueColor),
              items: const [
                DropdownMenuItem(value: "global", child: Text("Global Timer")),
                DropdownMenuItem(
                  value: "per_question",
                  child: Text("Per Question (Fixed)"),
                ),
                DropdownMenuItem(
                  value: "per_module",
                  child: Text("Per Module (Fixed)"),
                ),
                DropdownMenuItem(
                  value: "per_question_type",
                  child: Text("Per Question Type (Fixed)"),
                ),
                DropdownMenuItem(
                  value: "per_type_per_module",
                  child: Text("Per Type Per Module"),
                ),
              ],
              onChanged: (v) {
                if (v != null) onTypeChanged(v);
              },
              decoration: const InputDecoration(
                labelText: "Timing Mode",
                border: OutlineInputBorder(),
              ),
            ),
            if (timingType == "global") _buildGlobalBlock(),
            if (timingType == "per_question") _buildPerQuestionBlock(),
            if (timingType == "per_question_type") _buildPerTypeBlock(),
            if (timingType == "per_module") _buildPerModuleBlock(),
            if (timingType == "per_type_per_module") _buildPerTypePerModuleBlock(),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalBlock() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: TextField(
        controller: timeController,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: global.valueColor),
        decoration: const InputDecoration(
          labelText: "Global Quiz Time (seconds)",
          hintText: "0 = Unlimited",
          prefixIcon: Icon(Icons.av_timer_rounded, color: global.labelColor),
        ),
      ),
    );
  }

  Widget _buildPerQuestionBlock() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: TextField(
        controller: perQuestionTimeController,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: global.valueColor),
        decoration: const InputDecoration(
          labelText: "Default Time Per Question (seconds)",
          hintText: "0 = Unlimited",
          prefixIcon: Icon(Icons.timer_3_rounded, color: global.labelColor),
        ),
      ),
    );
  }

  Widget _buildPerTypeBlock() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        children: [
          _buildTimingRow(
            "Single Choice",
            typeTimingControllers["Single Choice"]!,
            icon: Icons.radio_button_checked_rounded,
          ),
          const SizedBox(height: 12),
          _buildTimingRow(
            "Multiple Choice",
            typeTimingControllers["Multiple Choice"]!,
            icon: Icons.check_box_rounded,
          ),
          const SizedBox(height: 12),
          _buildTimingRow(
            "Integer",
            typeTimingControllers["Integer"]!,
            icon: Icons.numbers_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildPerModuleBlock() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        children: modulesList.map((m) {
          final controllers = moduleTimingControllers[m];
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
                _buildTimingRow("Module Total Time", controllers["total"]!),
                const SizedBox(height: 8),
                _buildTimingRow(
                  "Per Question in Module",
                  controllers["perQuestion"]!,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPerTypePerModuleBlock() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        children: modulesList.map((m) {
          final controllers = moduleTypeTimingControllers[m];
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
                      Icons.folder_special_outlined,
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
                _buildTimingRow(
                  "Single Choice",
                  controllers["Single Choice"]!,
                  small: true,
                ),
                const SizedBox(height: 8),
                _buildTimingRow(
                  "Multiple Choice",
                  controllers["Multiple Choice"]!,
                  small: true,
                ),
                const SizedBox(height: 8),
                _buildTimingRow(
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

  Widget _buildTimingRow(
    String label,
    TextEditingController controller, {
    IconData? icon,
    bool small = false,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: global.labelColor),
          const SizedBox(width: 12),
        ],
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
