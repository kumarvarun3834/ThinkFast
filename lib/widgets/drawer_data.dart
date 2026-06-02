import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';

class SidebarMenu extends StatefulWidget {
  final User? user;

  const SidebarMenu({
    super.key,
    required this.user,
  });

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
    if (widget.user?.displayName != null && widget.user!.displayName!.isNotEmpty) {
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
    return Column(
      children: [
        UserAccountsDrawerHeader(
          decoration: const BoxDecoration(color: Colors.blueAccent),
          currentAccountPicture: const CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.person, size: 40, color: Colors.blueAccent),
          ),
          accountName: Text(_userName ?? (widget.user == null ? "Guest" : "User")),
          accountEmail: Text(widget.user?.email ?? "Welcome to ThinkFast"),
        ),
        if (widget.user == null)
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('Login'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.pushNamed(context, "/login");
            }
          ),
        ListTile(
          leading: const Icon(Icons.home),
          title: const Text('Home'),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, "/home");
          },
        ),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('Create New Quiz'),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, "/Create Quiz");
          },
        ),
        ListTile(
          leading: const Icon(Icons.book),
          title: const Text('My Quiz'),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, "/My Quiz");
          }
        ),
        if (widget.user != null)
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('My Attempts'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, "/My Attempts");
            },
          ),

        if (widget.user != null)
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ListTile(
          leading: const Icon(Icons.info),
          title: const Text('About Us'),
          onTap: () async {
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
