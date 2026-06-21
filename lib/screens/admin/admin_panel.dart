import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/admin_service.dart';
import 'package:thinkfast/services/settings_service.dart';
import 'package:thinkfast/utils/global.dart' as global;

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final SettingsService _settingsService = SettingsService();
  final AdminService _adminService = AdminService();
  List<String> _permissions = [];

  // Grouped Feature Flags
  final Map<String, List<String>> _flagGroups = {
    "System Control": [
      "maintenance_mode",
      "management_features",
      "user_action_logging",
      "enable_analytics",
    ],
    "User Access": [
      "enable_login",
      "enable_register",
      "enable_profile_edit",
    ],
    "Quiz Operations": [
      "enable_create_quiz",
      "enable_edit_quiz",
      "enable_delete_quiz",
      "enable_take_quiz",
      "enable_import",
      "random_quiz_generator",
    ],
    "AI & Performance": [
      "enable_ai",
      "enable_quiz_creation_rate_limit",
    ],
  };

  @override
  void initState() {
    super.initState();
    _fetchPermissions();
  }

  Future<void> _fetchPermissions() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final perms = await _adminService.getAdminPermissions(uid);
      if (mounted) setState(() => _permissions = perms);
    }
  }

  bool _canManageFlag(String key) {
    return _permissions.contains('manage_app_settings');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Admin Panel",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _settingsService.streamFeatureFlags(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: global.primaryAccent),
            );
          }

          final flags = snapshot.data ?? {};

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ..._flagGroups.entries.map((group) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(group.key),
                    const SizedBox(height: 12),
                    ...group.value.map((key) {
                      final bool value = flags[key] == true;
                      return _buildFlagToggle(key, value);
                    }),
                    const SizedBox(height: 24),
                  ],
                );
              }),

              _buildSectionHeader("Rate Limits"),
              const SizedBox(height: 12),
              _buildRateLimitField(flags),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.poppins(
        color: global.primaryAccent,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildFlagToggle(String key, bool value) {
    // Convert snake_case to Title Case for display
    final displayTitle = key
        .replaceFirst('enable_', '')
        .split('_')
        .map((word) {
          if (word.isEmpty) return "";
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');

    final bool canManage = _canManageFlag(key);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: global.borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: canManage ? 0 : 3,
            sigmaY: canManage ? 0 : 3,
          ),
          child: AbsorbPointer(
            absorbing: !canManage,
            child: Material(
              color: Colors.transparent,
              child: SwitchListTile(
                title: Text(
                  displayTitle,
                  style: const TextStyle(color: global.valueColor, fontSize: 16),
                ),
                subtitle: !canManage
                    ? const Text(
                        "Insufficient Permission",
                        style: TextStyle(color: global.errorColor, fontSize: 12),
                      )
                    : null,
                value: value,
                activeColor: global.primaryAccent,
                onChanged: (newValue) async {
                  try {
                    await _settingsService.updateFeatureFlag(key, newValue);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error updating $key: $e")),
                      );
                    }
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRateLimitField(Map<String, dynamic> flags) {
    final int currentVal = (flags['quiz_creation_rate_limit_minutes'] ?? 5)
        .toInt();
    final bool canManage = _canManageFlag('quiz_creation_rate_limit_minutes');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: global.borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: canManage ? 0 : 3,
            sigmaY: canManage ? 0 : 3,
          ),
          child: AbsorbPointer(
            absorbing: !canManage,
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    "Creation Rate Limit (Minutes)",
                    style: TextStyle(color: global.valueColor, fontSize: 16),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: global.valueColor),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: global.borderColor),
                      ),
                    ),
                    controller: TextEditingController(
                      text: currentVal.toString(),
                    ),
                    onSubmitted: (val) async {
                      final newValue = int.tryParse(val);
                      if (newValue != null) {
                        try {
                          await _settingsService.updateFeatureFlag(
                            'quiz_creation_rate_limit_minutes',
                            newValue,
                          );
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error updating limit: $e")),
                            );
                          }
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
