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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.getQuizManagers(widget.quizId),
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
                onTap: _isSelectionMode ? () => _toggleSelection(uid) : null,
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
