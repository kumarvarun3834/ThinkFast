import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';
import 'package:thinkfast/utils/global.dart' as global;
import 'user_details_screen.dart';

class AllUsersScreen extends StatefulWidget {
  const AllUsersScreen({super.key});

  @override
  State<AllUsersScreen> createState() => _AllUsersScreenState();
}

class _AllUsersScreenState extends State<AllUsersScreen> {
  final DatabaseService _db = DatabaseService();
  final String? _adminId = FirebaseAuth.instance.currentUser?.uid;
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    if (_adminId == null) return const Scaffold(body: Center(child: Text("Unauthorized")));

    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "User Management",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: TextField(
              style: const TextStyle(color: global.valueColor),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Search users by name...",
                hintStyle: const TextStyle(color: global.labelColor),
                prefixIcon: const Icon(Icons.search, color: global.labelColor),
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
              stream: _db.getAllUsers(_adminId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: global.errorColor)));
                }

                final users = snapshot.data ?? [];
                final filteredUsers = users.where((u) {
                  final name = (u['name'] ?? "").toString().toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();

                if (filteredUsers.isEmpty) {
                  return const Center(child: Text("No users found", style: TextStyle(color: global.labelColor)));
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: global.borderColor),
      ),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => UserDetailsScreen(userId: uid)),
        ),
        leading: CircleAvatar(
          backgroundColor: global.bgColor,
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null ? const Icon(Icons.person, color: global.labelColor) : null,
        ),
        title: Text(
          name,
          style: const TextStyle(color: global.valueColor, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "$quizCount Quizzes Created",
          style: const TextStyle(color: global.labelColor, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: global.labelColor),
      ),
    );
  }
}
