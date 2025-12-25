import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SidebarMenu extends StatelessWidget {
  final User? user;

  const SidebarMenu({
    super.key,
    required this.user,
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
              // try {
              //     refreshParent();
              //   }
              // } catch (error) {
                print(" login failed: ");
              // }
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
              Navigator.pop(context);
              Navigator.pushNamed(context, "/Create Quiz");
            },
          ),
        // if (user != null)
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('My Quiz'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, "/My Quiz");
            }
          ),

        if (user != null)
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ListTile(
          leading: const Icon(Icons.info),
          title: const Text('About Us'),
          onTap: () async {
          },
        ),
      ],
    );
  }
}
