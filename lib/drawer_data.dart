import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SidebarMenu extends StatelessWidget {
  final GoogleSignIn googleSignIn;
  final GoogleSignInAccount? user;
  final Function(String) onStateChange;
  final VoidCallback refreshParent;

  const SidebarMenu({
    super.key,
    required this.googleSignIn,
    required this.user,
    required this.onStateChange,
    required this.refreshParent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (user == null)
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('Login'),
            onTap: () async {
              try {
                final account = await googleSignIn.signIn();
                if (account != null) {
                  onStateChange("Main_Screen");
                  refreshParent();
                }
              } catch (error) {
                print("Google login failed: $error");
              }
            },
          ),
        ListTile(
          leading: const Icon(Icons.home),
          title: const Text('Home'),
          onTap: () {
            onStateChange("Main_Screen");
          },
        ),
        if (user != null)
        // ListTile(
        //   leading: const Icon(Icons.settings),
        //   title: const Text('Settings'),
        //   onTap: () {
        //
        //   },
        // ),

        if (user != null)
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Create New Quiz'),
            onTap: () {
              onStateChange("QuizForm");
            },
          ),
        if (user != null)
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('My Quiz'),
            onTap: () {},
          ),
        if (user != null)
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await googleSignIn.signOut();
              refreshParent();
            },
          ),
      ],
    );
  }
}
