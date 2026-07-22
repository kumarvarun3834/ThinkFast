import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/utils/global.dart' as global;

import 'admin_permissions_screen.dart';
import 'user_details_screen.dart';

class AllUsersScreen extends StatefulWidget {
  const AllUsersScreen({super.key});

  @override
  State<AllUsersScreen> createState() => _AllUsersScreenState();
}

class _AllUsersScreenState extends State<AllUsersScreen> {
  final String? _adminId = FirebaseAuth.instance.currentUser?.uid;
  String _searchQuery = "";
  late Stream<List<Map<String, dynamic>>> _usersStream;

  final Set<String> _selectedUids = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    if (_adminId != null) {
      _usersStream = global.adminDb.getAllUsers(_adminId!);
    }
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

  @override
  Widget build(BuildContext context) {
    if (_adminId == null)
      return const Scaffold(body: Center(child: Text("Unauthorized")));

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
                "User Management",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
        actions: _isSelectionMode
            ? [
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminPermissionsScreen(
                          targetUids: _selectedUids.toList(),
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
                  },
                  icon: const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: global.primaryAccent,
                  ),
                  label: const Text(
                    "PROMOTE",
                    style: TextStyle(
                      color: global.primaryAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.refresh, color: global.valueColor),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(
                      const SnackBar(content: Text("Syncing user stats...")),
                    );
                    try {
                      await global.adminDb
                          .fetchAllUsers(); // This triggers the sync logic in AdminService
                      if (mounted) {
                        setState(() {});
                      }
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text("Sync failed: $e")),
                        );
                      }
                    }
                  },
                  tooltip: "Sync All Stats",
                ),
              ],
      ),
      body: Column(
        children: [
          if (!_isSelectionMode)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: TextField(
                style: const TextStyle(color: global.valueColor),
                onChanged: (val) =>
                    setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: "Search users by name...",
                  hintStyle: const TextStyle(color: global.labelColor),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: global.labelColor,
                  ),
                  filled: true,
                  fillColor: global.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _usersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: global.primaryAccent,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Error: ${snapshot.error}",
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final users = snapshot.data ?? [];
                final filteredUsers = users.where((u) {
                  final name = (u['name'] ?? "").toString().toLowerCase();
                  final uid = (u['uid'] ?? "").toString().toLowerCase();
                  return name.contains(_searchQuery) ||
                      uid.contains(_searchQuery);
                }).toList();

                if (filteredUsers.isEmpty) {
                  return const Center(
                    child: Text(
                      "No users found",
                      style: TextStyle(color: global.labelColor),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    return _buildUserTile(user);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final String uid = user['uid'] ?? "";
    final String name = user['name'] ?? "Anonymous";
    final String? photoUrl = user['photoUrl'];
    final int quizCount = user['quizCount'] ?? 0;
    final bool isSelected = _selectedUids.contains(uid);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? global.primaryAccent : global.borderColor,
        ),
      ),
      child: Material(
        color: isSelected
            ? global.primaryAccent.withOpacity(0.1)
            : global.cardColor,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onLongPress: () => _toggleSelection(uid),
          onTap: _isSelectionMode
              ? () => _toggleSelection(uid)
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserDetailsScreen(userId: uid),
                  ),
                ),
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: global.bgColor,
                backgroundImage: photoUrl != null
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null
                    ? const Icon(Icons.person, color: global.labelColor)
                    : null,
              ),
              if (isSelected)
                const Positioned(
                  right: 0,
                  bottom: 0,
                  child: Icon(
                    Icons.check_circle,
                    color: global.primaryAccent,
                    size: 16,
                  ),
                ),
            ],
          ),
          title: Text(
            name,
            style: const TextStyle(
              color: global.valueColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            "$quizCount Quizzes Created",
            style: const TextStyle(color: global.labelColor, fontSize: 12),
          ),
          trailing: _isSelectionMode
              ? null
              : const Icon(Icons.chevron_right, color: global.labelColor),
        ),
      ),
    );
  }
}
