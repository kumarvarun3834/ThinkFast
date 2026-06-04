import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';

class SidebarMenu extends StatefulWidget {
  final User? user;

  const SidebarMenu({super.key, required this.user});

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> {
  String? _userName;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _fetchUserProfile();
    }
  }

  Future<void> _fetchUserProfile() async {
    // If Google user, they have a displayName
    if (widget.user?.displayName != null &&
        widget.user!.displayName!.isNotEmpty) {
      setState(() => _userName = widget.user!.displayName);
      return;
    }

    // Otherwise fetch from Firestore users collection
    try {
      final profile = await DatabaseService().getUserProfile(widget.user!.uid);
      if (mounted && profile != null) {
        setState(() => _userName = profile['name'] ?? profile['email']);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E293B),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF0F172A)),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Color(0xFF1E293B),
              child: Icon(Icons.person, size: 40, color: Color(0xFF3B82F6)),
            ),
            accountName: Text(
              _userName ?? (widget.user == null ? "Guest" : "User"),
              style: const TextStyle(color: Color(0xFFE2E8F0), fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              widget.user?.email ?? "Welcome to ThinkFast",
              style: const TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          if (widget.user == null)
            _drawerItem(
              icon: Icons.login,
              text: 'Login',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/login");
              },
            ),
          _drawerItem(
            icon: Icons.home,
            text: 'Home',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, "/home");
            },
          ),
          if (widget.user != null)
            _drawerItem(
              icon: Icons.add_box_outlined,
              text: 'Create New Quiz',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/Create Quiz");
              },
            ),
          if (widget.user != null)
            _drawerItem(
              icon: Icons.library_books_outlined,
              text: 'My Quiz',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/My Quiz");
              },
            ),
          if (widget.user != null)
            _drawerItem(
              icon: Icons.history_rounded,
              text: 'My Attempts',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/My Attempts");
              },
            ),
          const Divider(color: Color(0xFF334155)),
          if (widget.user != null)
            _drawerItem(
              icon: Icons.logout_rounded,
              text: 'Logout',
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) Navigator.pop(context);
              },
            ),
          _drawerItem(
            icon: Icons.info_outline_rounded,
            text: 'About Us',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, "/About Us");
            },
          ),
        ],
      ),
    );
  }

  Widget _drawerItem({required IconData icon, required String text, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF3B82F6)),
      title: Text(
        text,
        style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 16),
      ),
      onTap: onTap,
    );
  }
}
