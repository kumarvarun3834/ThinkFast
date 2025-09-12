import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:thinkfast/google_sign_in_provider.dart';
import 'package:thinkfast/quiz_form.dart';
import 'package:thinkfast/start_screen.dart';

class SidebarMenu extends StatelessWidget {
  final GoogleSignIn googleSignIn;
  final GoogleSignInAccount? user;
  final Function(Widget) onStateChange;
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
                // Silent login first
                final account = await GoogleSignInProvider()
                    .instance
                    .attemptLightweightAuthentication();

                GoogleSignInAccount? userAccount = account;

                // Fallback to interactive login
                userAccount ??= await GoogleSignInProvider()
                    .instance
                    .authenticate();

                if (userAccount != null) {
                  // ✅ Signed in successfully
                  onStateChange(
                      Main_Screen(
                          onPressed:onStateChange)
                  );
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
            onStateChange(Main_Screen(
                onPressed:onStateChange));
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
              onStateChange(QuizPage(onStateChange: onStateChange));
              refreshParent();
            },
          ),
        // if (user != null)
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('My Quiz'),
            onTap: () {
              onStateChange(Main_Screen(
                onPressed:onStateChange,
                // creatorId : user,
                visibility: "private")
              );
            },
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
