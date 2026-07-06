import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/utils/global.dart' as global;

class QuizHeaderSection extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController examController;
  final String visibility;
  final ValueChanged<String?> onVisibilityChanged;
  final bool allowMultipleAttempts;
  final ValueChanged<bool> onAllowMultipleAttemptsChanged;
  final TextEditingController maxAttemptsController;
  final bool disableModuleSwitchingUntilTimeout;
  final ValueChanged<bool> onDisableModuleSwitchingChanged;
  final bool forceWaitUntilTimeout;
  final ValueChanged<bool> onForceWaitUntilTimeoutChanged;
  final bool enableAutoLeaderboard;
  final ValueChanged<bool> onEnableAutoLeaderboardChanged;

  const QuizHeaderSection({
    super.key,
    required this.titleController,
    required this.descriptionController,
    required this.examController,
    required this.visibility,
    required this.onVisibilityChanged,
    required this.allowMultipleAttempts,
    required this.onAllowMultipleAttemptsChanged,
    required this.maxAttemptsController,
    required this.disableModuleSwitchingUntilTimeout,
    required this.onDisableModuleSwitchingChanged,
    required this.forceWaitUntilTimeout,
    required this.onForceWaitUntilTimeoutChanged,
    required this.enableAutoLeaderboard,
    required this.onEnableAutoLeaderboardChanged,
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
                const Icon(Icons.info_outline_rounded, color: global.primaryAccent),
                const SizedBox(width: 12),
                Text(
                  "Basic Information",
                  style: GoogleFonts.poppins(
                    color: global.valueColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: titleController,
              style: const TextStyle(color: global.valueColor, fontSize: 16),
              decoration: const InputDecoration(
                labelText: "Quiz Title",
                hintText: "Enter a catchy title...",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              style: const TextStyle(color: global.valueColor, fontSize: 14),
              decoration: const InputDecoration(
                labelText: "Description",
                hintText: "What is this quiz about?",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: examController,
              style: const TextStyle(color: global.valueColor, fontSize: 14),
              decoration: const InputDecoration(
                labelText: "Exam Tag",
                hintText: "e.g., JEE Mains, NEET, UPSC...",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_important_outline_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              dropdownColor: global.cardColor,
              value: visibility,
              style: const TextStyle(color: global.valueColor),
              items: const [
                DropdownMenuItem(value: "public", child: Text("Public (Visible to everyone)")),
                DropdownMenuItem(value: "private", child: Text("Private (Hidden)")),
                DropdownMenuItem(value: "scheduled", child: Text("Scheduled (Visible at specific time)")),
              ],
              onChanged: onVisibilityChanged,
              decoration: const InputDecoration(
                labelText: "Visibility",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.visibility_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            _buildPolicyBlock(),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyBlock() {
    return Material(
      color: global.cardColor.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SwitchListTile(
            dense: true,
            title: const Text("Allow Multiple Attempts", style: TextStyle(color: global.valueColor, fontSize: 13)),
            subtitle: const Text("Users can take this quiz more than once", style: TextStyle(color: global.labelColor, fontSize: 11)),
            value: allowMultipleAttempts,
            activeColor: global.primaryAccent,
            onChanged: onAllowMultipleAttemptsChanged,
          ),
          if (allowMultipleAttempts)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.repeat_rounded, size: 18, color: global.labelColor),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Max Attempts Allowed",
                      style: TextStyle(color: global.valueColor, fontSize: 13),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    height: 36,
                    child: TextField(
                      controller: maxAttemptsController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(color: global.valueColor, fontSize: 13),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(color: global.borderColor, height: 1),
          SwitchListTile(
            dense: true,
            title: const Text("Lock Module Switching", style: TextStyle(color: global.valueColor, fontSize: 13)),
            subtitle: const Text("Cannot change modules until time runs out", style: TextStyle(color: global.labelColor, fontSize: 11)),
            value: disableModuleSwitchingUntilTimeout,
            activeColor: global.primaryAccent,
            onChanged: onDisableModuleSwitchingChanged,
          ),
          const Divider(color: global.borderColor, height: 1),
          SwitchListTile(
            dense: true,
            title: const Text("Force Wait Until Timeout", style: TextStyle(color: global.valueColor, fontSize: 13)),
            subtitle: const Text("Cannot submit until the timer reaches zero", style: TextStyle(color: global.labelColor, fontSize: 11)),
            value: forceWaitUntilTimeout,
            activeColor: global.primaryAccent,
            onChanged: onForceWaitUntilTimeoutChanged,
          ),
          const Divider(color: global.borderColor, height: 1),
          SwitchListTile(
            dense: true,
            title: const Text("Auto Leaderboard", style: TextStyle(color: global.valueColor, fontSize: 13)),
            subtitle: const Text("Automatically generate rankings (Excludes Admins)", style: TextStyle(color: global.labelColor, fontSize: 11)),
            value: enableAutoLeaderboard,
            activeColor: global.primaryAccent,
            onChanged: onEnableAutoLeaderboardChanged,
          ),
        ],
      ),
    );
  }
}
