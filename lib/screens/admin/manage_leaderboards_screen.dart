import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/admin_service.dart';
import 'package:thinkfast/utils/global.dart' as global;

class ManageLeaderboardsScreen extends StatefulWidget {
  final String? quizId;
  const ManageLeaderboardsScreen({super.key, this.quizId});

  @override
  State<ManageLeaderboardsScreen> createState() => _ManageLeaderboardsScreenState();
}

class _ManageLeaderboardsScreenState extends State<ManageLeaderboardsScreen> {
  final AdminService _adminService = AdminService();
  final String _adminId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.quizId == null ? "Manage Leaderboards" : "Quiz Leaderboards",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _adminService.getLeaderboards(includePrivate: true, quizId: widget.quizId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final leaderboards = snapshot.data ?? [];

          if (leaderboards.isEmpty) {
            return Center(
              child: Text(
                "No leaderboards created yet.",
                style: TextStyle(color: global.labelColor),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: leaderboards.length,
            itemBuilder: (context, index) {
              final lb = leaderboards[index];
              return Card(
                color: global.cardColor,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: global.borderColor),
                ),
                child: ListTile(
                  title: Text(
                    lb['title'] ?? 'Untitled',
                    style: const TextStyle(color: global.valueColor, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${lb['entries']?.length ?? 0} participants • ${lb['isPublic'] ? 'Public' : 'Private'}",
                    style: const TextStyle(color: global.labelColor, fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: global.primaryAccent),
                        onPressed: () => _showLeaderboardEditor(lb),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: global.errorColor),
                        onPressed: () => _confirmDelete(lb['id']),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLeaderboardEditor(null),
        backgroundColor: global.primaryAccent,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text("NEW LEADERBOARD", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: global.cardColor,
        title: const Text("Delete Leaderboard?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: global.errorColor),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await _adminService.deleteLeaderboard(id, _adminId);
              navigator.pop();
            },
            child: const Text("DELETE"),
          ),
        ],
      ),
    );
  }

  void _showLeaderboardEditor(Map<String, dynamic>? existing) {
    final titleController = TextEditingController(text: existing?['title']);
    final descController = TextEditingController(text: existing?['description']);
    bool isPublic = existing?['isPublic'] ?? true;
    List<Map<String, dynamic>> entries = List<Map<String, dynamic>>.from(existing?['entries'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: global.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final bool canAutoLoad = widget.quizId != null && entries.isEmpty;

          return Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        existing == null ? "Create Leaderboard" : "Edit Leaderboard",
                        style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: global.valueColor),
                      ),
                      if (canAutoLoad)
                        IconButton(
                          icon: const Icon(Icons.auto_fix_high_rounded, color: global.primaryAccent),
                          onPressed: () async {
                            final potential = await _adminService.getPotentialLeaders(widget.quizId!);
                            setModalState(() {
                              entries = potential;
                            });
                          },
                          tooltip: "Auto-load Top 10 First Attempts",
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: "Title"),
                    style: const TextStyle(color: global.valueColor),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: "Description"),
                    style: const TextStyle(color: global.valueColor),
                  ),
                  SwitchListTile(
                    title: const Text("Publicly Visible", style: TextStyle(color: global.valueColor)),
                    value: isPublic,
                    onChanged: (v) => setModalState(() => isPublic = v),
                  ),
                  const Divider(color: global.borderColor),
                  Text("Entries (${entries.length})", style: const TextStyle(color: global.primaryAccent, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...entries.asMap().entries.map((e) {
                    int idx = e.key;
                    Map<String, dynamic> entry = e.value;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry['name'] ?? 'Unknown', style: const TextStyle(color: global.valueColor)),
                      subtitle: Text("Score: ${entry['score']} • Rank: ${entry['rank']}", style: const TextStyle(color: global.labelColor, fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: global.errorColor),
                        onPressed: () => setModalState(() => entries.removeAt(idx)),
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () => _showAddEntryDialog((newEntry) {
                      setModalState(() => entries.add(newEntry));
                    }),
                    icon: const Icon(Icons.add),
                    label: const Text("ADD PARTICIPANT"),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty) return;
                        final navigator = Navigator.of(context);
                        await _adminService.saveLeaderboard(
                          adminId: _adminId,
                          leaderboardId: existing?['id'],
                          quizId: widget.quizId,
                          title: titleController.text.trim(),
                          description: descController.text.trim(),
                          isPublic: isPublic,
                          entries: entries,
                        );
                        navigator.pop();
                      },
                      child: const Text("SAVE LEADERBOARD"),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddEntryDialog(Function(Map<String, dynamic>) onAdd) {
    final nameController = TextEditingController();
    final scoreController = TextEditingController();
    final rankController = TextEditingController();
    final uidController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: global.cardColor,
        title: const Text("Add Entry"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Display Name")),
            TextField(controller: scoreController, decoration: const InputDecoration(labelText: "Score"), keyboardType: TextInputType.number),
            TextField(controller: rankController, decoration: const InputDecoration(labelText: "Rank"), keyboardType: TextInputType.number),
            TextField(controller: uidController, decoration: const InputDecoration(labelText: "User UID (Optional)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty || scoreController.text.isEmpty) return;
              onAdd({
                'name': nameController.text.trim(),
                'score': int.tryParse(scoreController.text) ?? 0,
                'rank': int.tryParse(rankController.text) ?? 0,
                'userId': uidController.text.trim(),
              });
              Navigator.pop(context);
            },
            child: const Text("ADD"),
          ),
        ],
      ),
    );
  }
}
