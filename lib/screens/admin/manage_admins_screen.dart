import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/admin_service.dart';
import 'package:thinkfast/utils/global.dart' as global;
import 'add_app_admin_screen.dart';
import 'admin_permissions_screen.dart';

class ManageAdminsScreen extends StatefulWidget {
  const ManageAdminsScreen({super.key});

  @override
  State<ManageAdminsScreen> createState() => _ManageAdminsScreenState();
}

class _ManageAdminsScreenState extends State<ManageAdminsScreen> {
  final AdminService _adminService = AdminService();
  List<String> _myPermissions = [];
  List<Map<String, dynamic>> _admins = [];
  bool _isLoading = true;
  DateTime? _lastRefresh;

  final Set<String> _selectedUids = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _fetchMyPermissions();
    _refreshData(force: true);
  }

  Future<void> _refreshData({bool force = false}) async {
    final bool canBypass = global.adminLevel == 0 ||
        global.adminPermissions.contains('manage_admins') ||
        global.featureFlags?['enable_refresh_limit_bypass'] == true;

    if (!force && !canBypass && _lastRefresh != null) {
      final int limit =
          global.featureFlags?['admin_refresh_rate_limit_seconds'] ?? 30;
      final difference = DateTime.now().difference(_lastRefresh!).inSeconds;
      if (difference < limit) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Please wait ${limit - difference}s before refreshing again.",
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final data = await _adminService.fetchAllAdmins();
      if (mounted) {
        setState(() {
          _admins = data;
          _isLoading = false;
          _lastRefresh = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching admins: $e")),
        );
      }
    }
  }

  Future<void> _fetchMyPermissions() async {
    if (mounted) setState(() => _myPermissions = global.adminPermissions);
  }

  void _toggleSelection(String uid) {
    setState(() {
      if (_selectedUids.contains(uid)) {
        _selectedUids.remove(uid);
        if (_selectedUids.isEmpty) _isSelectionMode = false;
      } else {
        _selectedUids.add(uid);
        _isSelectionMode = true;
      }
    });
  }

  void _navigateToPermissions({List<String>? targetUids, List<String>? initialPermissions, bool initialIsSuper = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminPermissionsScreen(
          targetUids: targetUids ?? _selectedUids.toList(),
          initialPermissions: initialPermissions,
          initialIsSuper: initialIsSuper,
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _selectedUids.clear();
          _isSelectionMode = false;
        });
      }
    });
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
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedUids.clear();
                }),
              )
            : null,
        title: _isSelectionMode
            ? Text(
                "${_selectedUids.length} Selected",
                style: const TextStyle(color: Colors.white),
              )
            : Text(
                "App Admins",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
        actions: _isSelectionMode
            ? [
                TextButton.icon(
                  onPressed: () => _navigateToPermissions(),
                  icon: const Icon(Icons.security_rounded,
                      color: global.primaryAccent),
                  label: const Text("UPDATE",
                      style: TextStyle(
                          color: global.primaryAccent,
                          fontWeight: FontWeight.bold)),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.refresh, color: global.valueColor),
                  onPressed: () => _refreshData(),
                  tooltip: "Refresh List",
                ),
              ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: global.primaryAccent))
          : _admins.isEmpty
              ? const Center(
                  child: Text("No app admins found.", style: TextStyle(color: Colors.white70)),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    MediaQuery.of(context).padding.bottom + 80,
                  ),
                  itemCount: _admins.length,
                  itemBuilder: (context, index) {
                    final admin = _admins[index];
                    final uid = admin['uid'];
                    final rawPerms = admin['permissions'];
                    List<String> perms = [];
                    if (rawPerms is Map) {
                      perms = rawPerms.entries
                          .where((e) => e.value == true)
                          .map((e) => e.key.toString())
                          .toList();
                    } else if (rawPerms is List) {
                      perms = List<String>.from(rawPerms);
                    }

                    final level = admin['level'] ?? 1;
                    final isSelected = _selectedUids.contains(uid);

                    final String? name = admin['name'];
                    final String? photoUrl = admin['photoUrl'];

                    return Card(
                      color: isSelected ? global.primaryAccent.withOpacity(0.1) : global.cardColor,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isSelected ? global.primaryAccent : global.borderColor),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          onLongPress: () => _toggleSelection(uid),
                          onTap: _isSelectionMode
                              ? () => _toggleSelection(uid)
                              : () => _navigateToPermissions(
                                    targetUids: [uid],
                                    initialPermissions: perms,
                                    initialIsSuper: level == 0,
                                  ),
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor: global.bgColor,
                                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                                child: photoUrl == null ? const Icon(Icons.admin_panel_settings, color: global.labelColor) : null,
                              ),
                              if (isSelected)
                                const Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Icon(Icons.check_circle, color: global.primaryAccent, size: 16),
                                ),
                            ],
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name ?? uid,
                                  style: const TextStyle(
                                    color: global.valueColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (level == 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: global.primaryAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: global.primaryAccent),
                                  ),
                                  child: const Text("SUPER",
                                      style: TextStyle(
                                          color: global.primaryAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (name != null)
                                Text(
                                  uid,
                                  style: const TextStyle(color: global.labelColor, fontSize: 10),
                                ),
                              Text(
                                level == 0
                                    ? "Full Access (Super Admin)"
                                    : "Permissions: ${perms.isEmpty ? 'None' : perms.join(', ')}",
                                style: const TextStyle(color: global.labelColor, fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: _isSelectionMode
                              ? null
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (level != 0 || global.adminLevel == 0)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: global.errorColor, size: 20),
                                        onPressed: () => _confirmRemove(uid),
                                      ),
                                  ],
                                ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: global.primaryAccent,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddAppAdminScreen()),
          );
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
