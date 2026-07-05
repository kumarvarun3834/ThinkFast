import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/utils/global.dart' as global;

class SchedulingPanel extends StatelessWidget {
  final DateTime? scheduledTime;
  final VoidCallback onPickDateTime;
  final VoidCallback onClearDateTime;
  final bool isRestricted;
  final ValueChanged<bool> onRestrictedChanged;
  final TextEditingController allowedUsersController;

  const SchedulingPanel({
    super.key,
    required this.scheduledTime,
    required this.onPickDateTime,
    required this.onClearDateTime,
    required this.isRestricted,
    required this.onRestrictedChanged,
    required this.allowedUsersController,
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
                const Icon(Icons.lock_clock_outlined, color: global.primaryAccent),
                const SizedBox(width: 12),
                Text(
                  "Scheduling & Access",
                  style: GoogleFonts.poppins(
                    color: global.valueColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildScheduleRow(),
            const Divider(color: global.borderColor, height: 32),
            _buildRestrictedSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleRow() {
    return Row(
      children: [
        const Icon(
          Icons.calendar_today_rounded,
          color: global.labelColor,
          size: 18,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Scheduled Start Time",
                style: TextStyle(color: global.valueColor, fontSize: 13),
              ),
              Text(
                scheduledTime == null
                    ? "Immediate (Active Now)"
                    : "${scheduledTime!.day}/${scheduledTime!.month}/${scheduledTime!.year} ${scheduledTime!.hour}:${scheduledTime!.minute.toString().padLeft(2, '0')}",
                style: const TextStyle(color: global.labelColor, fontSize: 11),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onPickDateTime,
          style: TextButton.styleFrom(
            foregroundColor: global.primaryAccent,
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          child: Text(scheduledTime == null ? "SET TIME" : "CHANGE"),
        ),
        if (scheduledTime != null)
          IconButton(
            icon: const Icon(Icons.clear_rounded, color: global.errorColor, size: 18),
            onPressed: onClearDateTime,
          ),
      ],
    );
  }

  Widget _buildRestrictedSection() {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            "Restricted Quiz",
            style: TextStyle(color: global.valueColor, fontSize: 14),
          ),
          subtitle: const Text(
            "Only allow specific users to attempt",
            style: TextStyle(color: global.labelColor, fontSize: 11),
          ),
          value: isRestricted,
          activeColor: global.primaryAccent,
          onChanged: onRestrictedChanged,
        ),
        if (isRestricted) ...[
          const SizedBox(height: 12),
          TextField(
            controller: allowedUsersController,
            maxLines: 2,
            style: const TextStyle(color: global.valueColor, fontSize: 13),
            decoration: const InputDecoration(
              labelText: "Allowed User Emails or UIDs",
              hintText: "Enter emails/UIDs separated by commas...",
              hintStyle: TextStyle(fontSize: 12),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.info_outline, color: global.warningColor, size: 14),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Tip: Enter full email addresses (user@domain.com) or system UIDs.",
                  style: TextStyle(color: global.warningColor, fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
