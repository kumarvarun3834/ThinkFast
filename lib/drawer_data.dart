import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:thinkfast/google_sign_in_provider.dart';

class SidebarMenu extends StatelessWidget {
  final GoogleSignIn googleSignIn;
  final GoogleSignInAccount? user;
  final VoidCallback refreshParent;

  const SidebarMenu({
    super.key,
    required this.googleSignIn,
    required this.user,
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
                // 1. Try silent sign-in (cached session, no popup)
                GoogleSignInAccount? userAccount =
                await GoogleSignInProvider().instance.attemptLightweightAuthentication();

                // 2. If silent fails → fallback to interactive login
                userAccount ??= await GoogleSignInProvider().instance.authenticate();

                if (userAccount != null) {
                  // ✅ Signed in successfully
                  Navigator.pushNamed(context, "/home",);
                  refreshParent();
                }
              } catch (error) {
                print("Google login failed: $error");
              }
            }
          ),
        ListTile(
          leading: const Icon(Icons.home),
          title: const Text('Home'),
          onTap: () {
            Navigator.pushNamed(context,"/home");
            refreshParent();
          },
        ),
        // if (user != null)
        // ListTile(
        //   leading: const Icon(Icons.settings),
        //   title: const Text('Settings'),
        //   onTap: () {
        //
        //   },
        // ),

        // if (user != null)
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Create New Quiz'),
            onTap: () {
              Navigator.pushNamed(context, "/Create Quiz");
              refreshParent();
            },
          ),
        // if (user != null)
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('My Quiz'),
            onTap: () {
              Navigator.pushNamed(context, "/My Quiz");
            }
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
        ListTile(
          leading: const Icon(Icons.info),
          title: const Text('About Us'),
          onTap: () async {
            refreshParent();
          },
        ),
      ],
    );
  }
}
