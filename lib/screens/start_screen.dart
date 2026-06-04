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
        elevation: 0,
        color: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "ID: ${data['id']}",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF3B82F6), size: 18),
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "THINKFAST",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: const Color(0xFFE2E8F0),
            letterSpacing: 1.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFE2E8F0)),
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E293B),
        child: SidebarMenu(
          user: _user,
        ),
      ),
      body: Container(
        color: const Color(0xFF0F172A),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: readDatabases(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  "No quizzes available",
                  style: TextStyle(color: Color(0xFF94A3B8)),
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
