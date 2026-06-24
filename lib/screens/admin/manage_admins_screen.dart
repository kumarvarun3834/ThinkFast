import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/admin_service.dart';
import 'package:thinkfast/utils/global.dart' as global;

class ManageAdminsScreen extends StatefulWidget {
  const ManageAdminsScreen({super.key});

  @override
  State<ManageAdminsScreen> createState() => _ManageAdminsScreenState();
}

class _ManageAdminsScreenState extends State<ManageAdminsScreen> {
  final AdminService _adminService = AdminService();
  List<String> _myPermissions = [];

  final Map<String, String> _availablePermissions = {
    'manage_admins': 'Manage App Admins',
    'moderate_users': 'Global User Moderation',
    'manage_all_quizzes': 'Master Quiz Control',
    'view_audit_logs': 'View Audit Logs',
    'manage_app_settings': 'Manage App Settings',
    'bypass_ai_limits': 'Bypass AI Quotas',
    'manage_collaborators': 'Manage Quiz Collaborators',
  };

  @override
  void initState() {
    super.initState();
    _fetchMyPermissions();
  }

  Future<void> _fetchMyPermissions() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final perms = await _adminService.getAdminPermissions(uid);
      if (mounted) setState(() => _myPermissions = perms);
    }
  }

  void _showAdminDialog({String? uid, List<String>? currentPermissions, int? level}) {
    final TextEditingController uidController = TextEditingController(text: uid);
    final List<String> selectedPermissions = List.from(currentPermissions ?? []);
    bool isSuper = level == 0;
    bool isEditing = uid != null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: global.cardColor,
          title: Text(
            isEditing ? "Edit Admin" : "Add Admin",
            style: GoogleFonts.poppins(color: global.valueColor),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isEditing)
                  TextField(
                    controller: uidController,
                    style: const TextStyle(color: global.valueColor),
                    decoration: const InputDecoration(
                      labelText: "User UID",
                      labelStyle: TextStyle(color: global.labelColor),
                    ),
                  ),
                const SizedBox(height: 16),
                if (global.adminLevel == 0) ...[
                  SwitchListTile(
                    title: const Text("Super Admin", style: TextStyle(color: global.valueColor)),
                    subtitle: const Text("Full system access", style: TextStyle(color: global.labelColor, fontSize: 12)),
                    value: isSuper,
                    activeColor: global.primaryAccent,
                    onChanged: (val) => setDialogState(() => isSuper = val),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  "Permissions",
                  style: TextStyle(color: global.primaryAccent, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._availablePermissions.entries.map((entry) {
                  final bool hasPermissionToGrant = global.adminLevel == 0 || _myPermissions.contains(entry.key);
                  
                  return Opacity(
                    opacity: hasPermissionToGrant ? 1.0 : 0.4,
                    child: CheckboxListTile(
                      title: Text(
                        entry.value,
                        style: const TextStyle(color: global.valueColor, fontSize: 14),
                      ),
                      value: isSuper ? true : selectedPermissions.contains(entry.key),
                      activeColor: global.primaryAccent,
                      onChanged: (isSuper || !hasPermissionToGrant)
                          ? null
                          : (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  selectedPermissions.add(entry.key);
                                } else {
                                  selectedPermissions.remove(entry.key);
                                }
                              });
                            },
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: global.labelColor)),
            ),
            ElevatedButton(
              onPressed: () async {
                final targetUid = uidController.text.trim();
                if (targetUid.isEmpty) return;

                try {
                  await _adminService.addOrUpdateAdmin(
                    targetUid: targetUid,
                    permissions: isSuper ? AdminService.allPermissions : selectedPermissions,
                    actorUid: FirebaseAuth.instance.currentUser!.uid,
                    makeSuper: isSuper,
                  );
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: $e")),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: global.primaryAccent),
              child: Text(isEditing ? "UPDATE" : "ADD"),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemove(String uid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: global.cardColor,
        title: const Text("Remove Admin?", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to remove admin privileges for $uid?",
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _adminService.removeAdmin(
                  targetUid: uid,
                  actorUid: FirebaseAuth.instance.currentUser!.uid,
                );
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e")),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: global.errorColor),
            child: const Text("REMOVE"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "App Admins",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _adminService.getAllAdmins(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: global.primaryAccent));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text("No app admins found.", style: TextStyle(color: Colors.white70)),
            );
          }

          final admins = snapshot.data!;

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).padding.bottom + 80,
            ),
            itemCount: admins.length,
            itemBuilder: (context, index) {
              final admin = admins[index];
              final uid = admin['uid'];
              final perms = List<String>.from(admin['permissions'] ?? []);
              final level = admin['level'] ?? 1;

              return Card(
                color: global.cardColor,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: global.borderColor),
                ),
                child: ListTile(
                  title: Row(
                    children: [
                      Expanded(child: Text(uid, style: const TextStyle(color: global.valueColor, fontSize: 14))),
                      if (level == 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: global.primaryAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: global.primaryAccent),
                          ),
                          child: const Text("SUPER", style: TextStyle(color: global.primaryAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    level == 0 ? "Full Access (Super Admin)" : "Permissions: ${perms.isEmpty ? 'None' : perms.join(', ')}",
                    style: const TextStyle(color: global.labelColor, fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: global.primaryAccent, size: 20),
                        onPressed: () => _showAdminDialog(uid: uid, currentPermissions: perms, level: level),
                      ),
                      if (level != 0 || global.adminLevel == 0)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: global.errorColor, size: 20),
                          onPressed: () => _confirmRemove(uid),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: global.primaryAccent,
        onPressed: () => _showAdminDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
