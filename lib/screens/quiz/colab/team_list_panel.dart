import 'package:flutter/material.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';
import 'package:thinkfast/utils/global.dart' as global;
import 'collaborator_tile.dart';

class TeamListPanel extends StatefulWidget {
  final String quizId;
  final bool canManageThisTeam;
  final String? currentUserId;
  final bool isAdmin;

  const TeamListPanel({
    super.key,
    required this.quizId,
    required this.canManageThisTeam,
    required this.currentUserId,
    required this.isAdmin,
  });

  @override
  State<TeamListPanel> createState() => _TeamListPanelState();
}

class _TeamListPanelState extends State<TeamListPanel> {
  final DatabaseService _db = DatabaseService();
  final Set<String> _selectedUids = {};
  bool _isSelectionMode = false;
  bool _isProcessing = false;
  late Stream<List<Map<String, dynamic>>> _managersStream;

  @override
  void initState() {
    super.initState();
    _managersStream = _db.getQuizManagers(widget.quizId);
  }

  void _toggleSelection(String uid) {
    if (uid == widget.currentUserId) return; // Cannot select self
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

  void _bulkRemove() async {
    if (_selectedUids.isEmpty || widget.currentUserId == null) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: global.cardColor,
        title: const Text("Remove Collaborators?", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to revoke access for ${_selectedUids.length} member(s)?",
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: global.errorColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("REMOVE ALL", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      int successCount = 0;
      try {
        for (String uid in _selectedUids) {
          await _db.removeManagementAccess(
            quizId: widget.quizId,
            userId: uid,
            removedBy: widget.currentUserId!,
          );
          successCount++;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Removed $successCount collaborator(s)")),
          );
          setState(() {
            _selectedUids.clear();
            _isSelectionMode = false;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  void _showEditPermissionsDialog(Map<String, dynamic> collaborator) {
    final String uid = collaborator['userId'];
    final String name = collaborator['userName'] ?? "User";
    final Map<String, dynamic> currentPerms = collaborator['permissions'] as Map<String, dynamic>? ?? {};
    final Map<String, bool> selectedPermissions = {
      for (var entry in currentPerms.entries) entry.key: entry.value == true,
    };

    final Map<String, String> availablePermissions = {
      'can_update': 'Edit Questions',
      'can_delete': 'Delete Quiz',
      'can_publish': 'Publish/Visibility',
      'can_lock_quiz': 'Lock/Unlock Session',
      'can_view_results': 'View Responses',
      'can_view_answer_key': 'View Answer Key',
      'can_view_analytics': 'Advanced Analytics',
      'can_export_data': 'Export Data',
      'can_moderate': 'Moderate Responses',
      'can_ban_users': 'Ban Users',
      'can_manage_collaborators': 'Manage Team',
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: global.cardColor,
          title: Text("Edit Permissions", style: const TextStyle(color: global.valueColor)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: const TextStyle(color: global.primaryAccent, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ...availablePermissions.entries.map((entry) => CheckboxListTile(
                      title: Text(entry.value, style: const TextStyle(color: global.valueColor, fontSize: 14)),
                      value: selectedPermissions[entry.key] ?? false,
                      activeColor: global.primaryAccent,
                      onChanged: (val) {
                        setDialogState(() {
                          selectedPermissions[entry.key] = val ?? false;
                        });
                      },
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: global.labelColor))),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _db.grantManagementAccess(
                    quizId: widget.quizId,
                    userId: uid,
                    permissions: selectedPermissions,
                    addedBy: widget.currentUserId!,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permissions updated")));
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: global.primaryAccent),
              child: const Text("UPDATE"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _managersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error loading team: ${snapshot.error}",
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }
        
        final managers = snapshot.data ?? [];
        final bool isLoading = snapshot.connectionState == ConnectionState.waiting;

        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (managers.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text("No collaborators yet", style: TextStyle(color: global.labelColor)),
            ),
          );
        }

        return Column(
          children: [
            if (_isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Text(
                      "${_selectedUids.length} selected",
                      style: const TextStyle(color: global.primaryAccent, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _bulkRemove,
                      icon: const Icon(Icons.delete_sweep, color: global.errorColor),
                      label: const Text("REMOVE SELECTED", style: TextStyle(color: global.errorColor)),
                    ),
                    IconButton(
                      onPressed: () => setState(() {
                        _selectedUids.clear();
                        _isSelectionMode = false;
                      }),
                      icon: const Icon(Icons.close, color: global.labelColor),
                    ),
                  ],
                ),
              ),
            ...managers.map((m) {
              final uid = m['userId'];
              final isSelected = _selectedUids.contains(uid);
              return CollaboratorTile(
                collaborator: m,
                canManageThisTeam: widget.canManageThisTeam,
                currentUserId: widget.currentUserId,
                isSelected: isSelected,
                isSelectionMode: _isSelectionMode,
                onLongPress: () => _toggleSelection(uid),
                onTap: _isSelectionMode ? () => _toggleSelection(uid) : () => _showEditPermissionsDialog(m),
                onRemove: (uid, name) async {
                  // Standard single remove
                  final bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: global.cardColor,
                      title: const Text("Remove Collaborator?", style: TextStyle(color: Colors.white)),
                      content: Text("Are you sure you want to revoke access for $name?",
                          style: const TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: global.errorColor),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("REMOVE", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && widget.currentUserId != null) {
                    try {
                      await _db.removeManagementAccess(
                        quizId: widget.quizId,
                        userId: uid,
                        removedBy: widget.currentUserId!,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Collaborator removed")));
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    }
                  }
                },
                isAdmin: widget.isAdmin,
              );
            }).toList(),
          ],
        );
      },
    );
  }
}
