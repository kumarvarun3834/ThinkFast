import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';
import 'package:thinkfast/utils/global.dart' as global;

class SidebarMenu extends StatefulWidget {
  final User? user;

  const SidebarMenu({super.key, required this.user});

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> {
  String? _userName;
  String? _userPhotoUrl;
  bool _canCreateQuiz = true;
  bool _isAdmin = false;
  bool _isRegisteredAdmin = false;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _isAdmin = global.isAdmin;
      _isRegisteredAdmin = global.isRegisteredAdmin;
      _canCreateQuiz = global.featureFlags?['enable_create_quiz'] ?? true;

      final profile = global.currentUserProfile;
      if (profile != null) {
        _userName = profile['name'];
        _userPhotoUrl = profile['photoUrl'];
      }

      // Fallbacks if not loaded yet or missing
      if (_userName == null || _userPhotoUrl == null) {
        _fetchUserProfile();
      }
    }
  }

  Future<void> _fetchUserProfile() async {
    // Try fetching from Firestore users collection first
    try {
      final profile = await DatabaseService().getUserProfile(widget.user!.uid);
      if (mounted && profile != null) {
        if (profile['name'] != null && profile['name'].toString().isNotEmpty) {
          setState(() => _userName = profile['name']);
        }
        if (profile['photoUrl'] != null &&
            profile['photoUrl'].toString().isNotEmpty) {
          setState(() => _userPhotoUrl = profile['photoUrl']);
        }
        if (_userName != null && _userPhotoUrl != null) return;
      }
    } catch (_) {}

    // Fallback to Google displayName and photoURL
    if (mounted && widget.user != null) {
      if (_userName == null &&
          widget.user!.displayName != null &&
          widget.user!.displayName!.isNotEmpty) {
        setState(() => _userName = widget.user!.displayName);
      }
      if (_userPhotoUrl == null &&
          widget.user!.photoURL != null &&
          widget.user!.photoURL!.isNotEmpty) {
        setState(() => _userPhotoUrl = widget.user!.photoURL);
      }
    }

    // Final fallback to email for name
    if (mounted && _userName == null) {
      setState(() => _userName = widget.user?.email?.split('@')[0]);
    }
  }

  void _showJoinByIdDialog(BuildContext context) {
    final TextEditingController idController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          "Join Quiz",
          style: TextStyle(color: Color(0xFFE2E8F0)),
        ),
        content: TextField(
          controller: idController,
          style: const TextStyle(color: Color(0xFFE2E8F0)),
          decoration: const InputDecoration(
            hintText: "Enter Quiz ID",
            hintStyle: TextStyle(color: Color(0xFF94A3B8)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF334155)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              String id = idController.text.trim();
              if (id.isNotEmpty) {
                // If they pasted a full URL, extract the ID
                if (id.contains("id=")) {
                  final uri = Uri.tryParse(id);
                  if (uri != null && uri.queryParameters.containsKey('id')) {
                    id = uri.queryParameters['id']!;
                  }
                }
                Navigator.pop(context);
                Navigator.pushNamed(context, "/Quiz Details", arguments: id);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
            ),
            child: const Text("Join"),
          ),
        ],
      ),
    );
  }

  void _checkAndNavigate(
    BuildContext context,
    String route, {
    Object? arguments,
  }) {
    if (widget.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login to use this feature")),
      );
      Navigator.pushNamed(context, "/login");
      return;
    }
    if (!widget.user!.emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please verify your email to access this feature"),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.pushNamed(context, "/verify");
      return;
    }
    Navigator.pop(context);
    Navigator.pushNamed(context, route, arguments: arguments);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E293B),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF0F172A)),
            currentAccountPicture: CircleAvatar(
              backgroundColor: const Color(0xFF1E293B),
              backgroundImage: _userPhotoUrl != null
                  ? NetworkImage(_userPhotoUrl!)
                  : null,
              child: _userPhotoUrl == null
                  ? const Icon(Icons.person, size: 40, color: Color(0xFF3B82F6))
                  : null,
            ),
            accountName: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _userName ?? (widget.user == null ? "Guest" : "User"),
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.user != null && !widget.user!.emailVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: const Text(
                      "UNVERIFIED",
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            accountEmail: Text(
              widget.user?.uid ?? "Welcome to ThinkFast",
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
          if (widget.user != null && !widget.user!.emailVerified)
            _drawerItem(
              icon: Icons.verified_user_outlined,
              text: 'Verify Account',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/verify");
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
              icon: Icons.account_circle_outlined,
              text: 'Profile',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/profile");
              },
            ),
          _drawerItem(
            icon: Icons.qr_code_scanner_rounded,
            text: 'Join Quiz by ID',
            onTap: () {
              if (widget.user == null || !widget.user!.emailVerified) {
                _checkAndNavigate(
                  context,
                  "",
                ); // This will trigger the verification check
              } else {
                Navigator.pop(context);
                _showJoinByIdDialog(context);
              }
            },
          ),
          if (widget.user != null && (_canCreateQuiz || _isAdmin))
            _drawerItem(
              icon: Icons.add_box_outlined,
              text: 'Create New Quiz',
              onTap: () => _checkAndNavigate(context, "/Create Quiz"),
            ),
          if (widget.user != null)
            _drawerItem(
              icon: Icons.library_books_outlined,
              text: 'My Quiz',
              onTap: () => _checkAndNavigate(context, "/My Quiz"),
            ),
          if (widget.user != null)
            _drawerItem(
              icon: Icons.history_rounded,
              text: 'My Attempts',
              onTap: () => _checkAndNavigate(context, "/My Attempts"),
            ),
          if (_isAdmin)
            _drawerItem(
              icon: Icons.admin_panel_settings_outlined,
              text: 'Admin Panel',
              onTap: () => _checkAndNavigate(context, "/Admin Panel"),
            ),
          if (_isRegisteredAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: SwitchListTile(
                  title: const Text(
                    "Admin Mode",
                    style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 14),
                  ),
                  secondary: Icon(
                    _isAdmin ? Icons.visibility : Icons.visibility_off,
                    color: const Color(0xFF3B82F6),
                  ),
                  value: _isAdmin,
                  activeColor: const Color(0xFF3B82F6),
                  onChanged: (bool value) async {
                    try {
                      await DatabaseService().toggleAdminMode(
                        uid: widget.user!.uid,
                        enable: value,
                      );
                      global.isAdmin = value;
                      if (mounted) {
                        setState(() => _isAdmin = value);
                        // Refresh features or navigate if needed
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Admin Mode ${value ? 'Enabled' : 'Disabled'}",
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    }
                  },
                ),
              ),
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

  Widget _drawerItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
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
