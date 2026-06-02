import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thinkfast/widgets/TextContainer.dart';
import 'package:thinkfast/widgets/drawer_data.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';

class Main_Screen extends StatefulWidget {
  final User? creator;
  final bool showMyQuizzes;

  const Main_Screen({
    super.key,
    this.creator,
    this.showMyQuizzes = false,
  });

  @override
  State<Main_Screen> createState() => _Main_ScreenState();
}

class _Main_ScreenState extends State<Main_Screen> {
  User? _user;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _auth.authStateChanges().listen((u) {
      if (mounted) setState(() => _user = u);
    });
  }

  /// 🔥 READ QUIZZES
  Stream<List<Map<String, dynamic>>> readDatabases() {
    return DatabaseService().readAllDatabases(
      showMyQuizzes: widget.showMyQuizzes,
      creatorId: widget.creator?.uid,
    );
  }

  /// 🧩 QUIZ CARD (Minimized)
  Widget buildQuizCard(Map<String, dynamic> data) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          "/Quiz Details",
          arguments: data['id'],
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        elevation: 3,
        color: const Color.fromARGB(255, 255, 225, 255),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title'] ?? 'Untitled',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "ID: ${data['id']}",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.blueAccent),
            ],
          ),
        ),
      ),
    );
  }

  /// 🧱 BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextContainer("THINKFAST", Colors.black, 20),
      ),
      drawer: Drawer(
        child: SidebarMenu(
          user: _user,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 36, 7, 156),
              Color.fromARGB(255, 8, 0, 255),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: readDatabases(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  "No quizzes available",
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                return buildQuizCard(snapshot.data![index]);
              },
            );
          },
        ),
      ),
    );
  }
}
