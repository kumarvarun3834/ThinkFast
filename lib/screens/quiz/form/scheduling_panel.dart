import 'package:flutter/material.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Scheduling & Restriction",
          style: TextStyle(
            color: global.valueColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: global.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: global.borderColor),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: global.primaryAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Scheduled Start Time",
                          style: TextStyle(
                            color: global.valueColor,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          scheduledTime == null
                              ? "Immediate (Active Now)"
                              : "${scheduledTime!.day}/${scheduledTime!.month}/${scheduledTime!.year} ${scheduledTime!.hour}:${scheduledTime!.minute.toString().padLeft(2, '0')}",
                          style: const TextStyle(
                            color: global.labelColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onPickDateTime,
                    child: Text(scheduledTime == null ? "SET TIME" : "CHANGE"),
                  ),
                  if (scheduledTime != null)
                    IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: global.errorColor,
                        size: 18,
                      ),
                      onPressed: onClearDateTime,
                    ),
                ],
              ),
              const Divider(color: global.borderColor, height: 32),
              Material(
                color: Colors.transparent,
                child: SwitchListTile(
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
                  activeThumbColor: global.primaryAccent,
                  onChanged: onRestrictedChanged,
                ),
              ),
              if (isRestricted) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: allowedUsersController,
                  maxLines: 2,
                  style: const TextStyle(
                    color: global.valueColor,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    labelText: "Allowed User UIDs",
                    hintText: "Enter UIDs separated by commas...",
                    hintStyle: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Tip: Participants can find their UID in the Sidebar/Profile.",
                  style: TextStyle(color: global.warningColor, fontSize: 10),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
