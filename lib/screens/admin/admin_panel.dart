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
  int _adminLevel = 0;

  @override
  void initState() {
    super.initState();
    _fetchAdminLevel();
  }

  Future<void> _fetchAdminLevel() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final level = await _adminService.getAdminLevel(uid);
      if (mounted) setState(() => _adminLevel = level);
    }
  }

  bool _canManageFlag(String key) {
    if (_adminLevel >= 10) return true; // Super Admin

    switch (key) {
      case 'maintenance_mode':
        return _adminLevel >= 8;
      case 'enable_quiz_creation_rate_limit':
      case 'quiz_creation_rate_limit_minutes':
        return _adminLevel >= 5; // Platform Managers and above
      case 'management_features':
        return _adminLevel >= 8;
      default:
        // Most global toggles require System Admin (8)
        return _adminLevel >= 8;
    }
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

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text(
                "Failed to load feature flags",
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final flags = snapshot.data!;
          // Remove timestamps and numbers from toggle list
          final toggleKeys = flags.keys.where((k) => flags[k] is bool).toList();
          toggleKeys.sort();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSectionHeader("Feature Flags"),
              const SizedBox(height: 16),
              ...toggleKeys.map(
                (key) => _buildFlagToggle(key, flags[key] as bool),
              ),

              const SizedBox(height: 32),
              _buildSectionHeader("Rate Limits"),
              const SizedBox(height: 16),
              _buildRateLimitField(flags),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        color: global.primaryAccent,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildFlagToggle(String key, bool value) {
    // Convert snake_case to Title Case for display
    final displayTitle = key
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
                        "Insufficient Level",
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
                        await _settingsService.updateFeatureFlag(
                          'quiz_creation_rate_limit_minutes',
                          newValue,
                        );
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
