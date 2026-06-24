import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/admin_service.dart';
import 'package:thinkfast/services/settings_service.dart';
import 'package:thinkfast/utils/global.dart' as global;

// import 'user_details_screen.dart';
import 'all_users_screen.dart';
import 'manage_admins_screen.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final SettingsService _settingsService = SettingsService();
  final AdminService _adminService = AdminService();
  List<String> _permissions = [];
  bool _isMaster = false;

  // Grouped Feature Flags
  final Map<String, List<String>> _flagGroups = {
    "System Control": [
      "maintenance_mode",
      "management_features",
      "user_action_logging",
      "enable_analytics",
    ],
    "User Access": ["enable_login", "enable_register", "enable_profile_edit"],
    "Quiz Operations": [
      "enable_create_quiz",
      "enable_edit_quiz",
      "enable_delete_quiz",
      "enable_take_quiz",
      "enable_import",
      "random_quiz_generator",
    ],
    "AI & Performance": ["enable_ai", "enable_quiz_creation_rate_limit"],
  };

  @override
  void initState() {
    super.initState();
    _fetchAdminStatus();
  }

  Future<void> _fetchAdminStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final perms = await _adminService.getAdminPermissions(uid);
      if (mounted) {
        setState(() {
          _permissions = perms;
          _isMaster = global.adminLevel == 0;
        });
      }
    }
  }

  bool _canManageFlag(String key) {
    if (_isMaster) return true;
    return _permissions.contains('manage_app_settings');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Admin Panel",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            if (_isMaster)
              const Text(
                "MASTER CONTROL ENABLED",
                style: TextStyle(
                  color: global.primaryAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
          ],
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

          // Collect all flags that are already grouped
          final groupedKeys = _flagGroups.values.expand((e) => e).toSet();
          groupedKeys.add('quiz_creation_rate_limit_minutes');

          // Find any flags in Firestore that are NOT in our groups
          final otherKeys = flags.keys
              .where((k) => !groupedKeys.contains(k) && k != 'updatedAt')
              .toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
            _buildSectionHeader("Platform Management"),
            const SizedBox(height: 12),
            _buildManagementTile(
              icon: Icons.people_alt_outlined,
              title: "User Management",
              subtitle: "View users, ban accounts, delete data",
              enabled: _isMaster || _permissions.contains('moderate_users'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AllUsersScreen(),
                ),
              ),
            ),
            _buildManagementTile(
              icon: Icons.admin_panel_settings_outlined,
              title: "Admin Management",
              subtitle: "Manage platform-wide administrators",
              enabled: _isMaster || _permissions.contains('manage_admins'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageAdminsScreen(),
                ),
              ),
            ),
            const SizedBox(height: 24),

              ..._flagGroups.entries.map((group) {
                final groupFlags = group.value
                    .where((k) => flags.containsKey(k))
                    .toList();
                if (groupFlags.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(group.key),
                    const SizedBox(height: 12),
                    ...groupFlags.map((key) {
                      final bool value = flags[key] == true;
                      return _buildFlagToggle(key, value);
                    }),
                    const SizedBox(height: 24),
                  ],
                );
              }),

              if (otherKeys.isNotEmpty) ...[
                _buildSectionHeader("Other Settings"),
                const SizedBox(height: 12),
                ...otherKeys.map((key) {
                  final value = flags[key];
                  if (value is bool) {
                    return _buildFlagToggle(key, value);
                  } else {
                    return _buildGenericField(key, value, flags);
                  }
                }),
                const SizedBox(height: 24),
              ],

              _buildSectionHeader("Rate Limits"),
              const SizedBox(height: 12),
              _buildRateLimitField(flags),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildManagementTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? global.borderColor : global.borderColor.withOpacity(0.3),
        ),
      ),
      child: ListTile(
        onTap: enabled ? onTap : null,
        enabled: enabled,
        leading: Icon(
          icon,
          color: enabled ? global.primaryAccent : global.primaryAccent.withOpacity(0.4),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: enabled ? global.valueColor : global.valueColor.withOpacity(0.4),
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          enabled ? subtitle : "Insufficient Permission",
          style: TextStyle(
            color: enabled ? global.labelColor : global.errorColor.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: enabled ? global.labelColor : global.labelColor.withOpacity(0.2),
        ),
      ),
    );
  }

  Widget _buildGenericField(
    String key,
    dynamic value,
    Map<String, dynamic> flags,
  ) {
    final bool canManage = _canManageFlag(key);
    final String displayTitle = key.replaceAll('_', ' ').toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canManage ? global.borderColor : global.borderColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              displayTitle,
              style: TextStyle(
                color: canManage ? global.valueColor : global.valueColor.withOpacity(0.4),
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: TextField(
              enabled: canManage,
              controller: TextEditingController(text: value.toString()),
              style: TextStyle(
                color: canManage ? global.valueColor : global.valueColor.withOpacity(0.4),
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(isDense: true),
              onSubmitted: (newVal) async {
                dynamic typedVal = newVal;
                if (value is int) typedVal = int.tryParse(newVal);
                if (value is double) typedVal = double.tryParse(newVal);

                if (typedVal != null) {
                  await _settingsService.updateFeatureFlag(key, typedVal);
                }
              },
            ),
          ),
        ],
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
        border: Border.all(
          color: canManage ? global.borderColor : global.borderColor.withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: SwitchListTile(
          title: Text(
            displayTitle,
            style: TextStyle(
              color: canManage ? global.valueColor : global.valueColor.withOpacity(0.4),
              fontSize: 16,
            ),
          ),
          subtitle: !canManage
              ? const Text(
                  "Insufficient Permission",
                  style: TextStyle(
                    color: global.errorColor,
                    fontSize: 12,
                  ),
                )
              : null,
          value: value,
          activeTrackColor: global.primaryAccent.withOpacity(0.5),
          activeThumbColor: global.primaryAccent,
          onChanged: canManage ? (newValue) async {
            try {
              await _settingsService.updateFeatureFlag(key, newValue);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error updating $key: $e")),
                );
              }
            }
          } : null,
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
        border: Border.all(
          color: canManage ? global.borderColor : global.borderColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "Creation Rate Limit (Minutes)",
              style: TextStyle(
                color: canManage ? global.valueColor : global.valueColor.withOpacity(0.4),
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: TextField(
              enabled: canManage,
              keyboardType: TextInputType.number,
              style: TextStyle(
                color: canManage ? global.valueColor : global.valueColor.withOpacity(0.4),
              ),
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
                        SnackBar(
                          content: Text("Error updating limit: $e"),
                        ),
                      );
                    }
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
