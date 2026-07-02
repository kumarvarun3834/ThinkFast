import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thinkfast/utils/global.dart' as global;

class QuizHeaderSection extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController examController;
  final TextEditingController timeController;
  final TextEditingController perQuestionTimeController;
  final String visibility;
  final ValueChanged<String?> onVisibilityChanged;
  final bool allowMultipleAttempts;
  final ValueChanged<bool> onAllowMultipleAttemptsChanged;
  final bool disableModuleSwitchingUntilTimeout;
  final ValueChanged<bool> onDisableModuleSwitchingChanged;
  final bool forceWaitUntilTimeout;
  final ValueChanged<bool> onForceWaitUntilTimeoutChanged;

  const QuizHeaderSection({
    super.key,
    required this.titleController,
    required this.descriptionController,
    required this.examController,
    required this.timeController,
    required this.perQuestionTimeController,
    required this.visibility,
    required this.onVisibilityChanged,
    required this.allowMultipleAttempts,
    required this.onAllowMultipleAttemptsChanged,
    required this.disableModuleSwitchingUntilTimeout,
    required this.onDisableModuleSwitchingChanged,
    required this.forceWaitUntilTimeout,
    required this.onForceWaitUntilTimeoutChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: titleController,
          style: const TextStyle(color: global.valueColor),
          decoration: const InputDecoration(labelText: "Quiz Title"),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: descriptionController,
          style: const TextStyle(color: global.valueColor),
          decoration: const InputDecoration(labelText: "Description"),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: examController,
          style: const TextStyle(color: global.valueColor),
          decoration: const InputDecoration(
            labelText: "Exam Tag",
            hintText: "e.g., JEE Mains, NEET, UPSC...",
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: timeController,
          style: const TextStyle(color: global.valueColor),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: "Timer (minutes)",
            hintText: "0 = Unlimited",
            suffixText: "min",
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: perQuestionTimeController,
          style: const TextStyle(color: global.valueColor),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: "Per Question (sec)",
            hintText: "0 = None",
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          dropdownColor: global.cardColor,
          initialValue: visibility,
          style: const TextStyle(color: global.valueColor),
          items: const [
            DropdownMenuItem(value: "public", child: Text("Public")),
            DropdownMenuItem(value: "private", child: Text("Private")),
          ],
          onChanged: onVisibilityChanged,
          decoration: const InputDecoration(labelText: "Visibility"),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text(
            "Allow Multiple Attempts",
            style: TextStyle(color: global.valueColor),
          ),
          subtitle: const Text(
            "If disabled, users can only take this quiz once",
            style: TextStyle(color: global.labelColor, fontSize: 12),
          ),
          value: allowMultipleAttempts,
          activeThumbColor: global.primaryAccent,
          onChanged: onAllowMultipleAttemptsChanged,
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: global.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: global.borderColor),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text(
                  "Disable Module Switching",
                  style: TextStyle(
                    color: global.valueColor,
                    fontSize: 14,
                  ),
                ),
                subtitle: const Text(
                  "Cannot change modules until time runs out",
                  style: TextStyle(
                    color: global.labelColor,
                    fontSize: 11,
                  ),
                ),
                value: disableModuleSwitchingUntilTimeout,
                activeThumbColor: global.primaryAccent,
                onChanged: onDisableModuleSwitchingChanged,
              ),
              const Divider(color: global.borderColor, height: 1),
              SwitchListTile(
                title: const Text(
                  "Force Wait Until Timeout",
                  style: TextStyle(
                    color: global.valueColor,
                    fontSize: 14,
                  ),
                ),
                subtitle: const Text(
                  "Cannot submit until the timer reaches zero",
                  style: TextStyle(
                    color: global.labelColor,
                    fontSize: 11,
                  ),
                ),
                value: forceWaitUntilTimeout,
                activeThumbColor: global.primaryAccent,
                onChanged: onForceWaitUntilTimeoutChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
