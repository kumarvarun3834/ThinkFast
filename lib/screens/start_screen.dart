import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thinkfast/widgets/drawer_data.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';
import 'package:thinkfast/widgets/quiz_widgets.dart';

import '../utils/global.dart' as global;

class Main_Screen extends StatefulWidget {
  final User? creator;
  final bool showMyQuizzes;
  final bool showManagedQuizzes;

  const Main_Screen({
    super.key,
    this.creator,
    this.showMyQuizzes = false,
    this.showManagedQuizzes = false,
  });

  @override
  State<Main_Screen> createState() => _Main_ScreenState();
}

class _Main_ScreenState extends State<Main_Screen> {
  User? _user;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _auth.authStateChanges().listen((u) async {
      if (mounted) {
        setState(() => _user = u);
        if (u != null && global.currentUserProfile == null) {
          await DatabaseService().initAppData(u.uid);
          if (mounted) setState(() {}); // Refresh with new global data
        }
      }
    });
  }

  /// 🔥 READ QUIZZES
  Stream<List<Map<String, dynamic>>> readDatabases() {
    return DatabaseService().readAllDatabases(
      showMyQuizzes: widget.showMyQuizzes,
      showManagedQuizzes: widget.showManagedQuizzes,
      creatorId: widget.creator?.uid,
      userId: _user?.uid,
    );
  }

  void _shareQuiz(String quizId) {
    final String shareUrl = "https://thinkfast3834.web.app/quiz?id=$quizId";
    Clipboard.setData(ClipboardData(text: shareUrl)).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Link copied to clipboard: $shareUrl"),
            backgroundColor: global.primaryAccent,
          ),
        );
      }
    });
  }

  /// 🧩 QUIZ CARD (Minimized)
  Widget buildQuizCard(Map<String, dynamic> data) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, "/Quiz Details", arguments: data['id']);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        elevation: 0,
        color: global.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: global.borderColor),
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
                        color: global.valueColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Created by: ${data['user'] ?? 'Anonymous'}",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: global.labelColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.share_rounded,
                  color: global.primaryAccent,
                  size: 20,
                ),
                onPressed: () => _shareQuiz(data['id']),
                tooltip: "Share Quiz Link",
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: global.borderColor,
                size: 18,
              ),
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
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: GoogleFonts.poppins(color: global.valueColor),
                decoration: InputDecoration(
                  hintText: "Search quizzes...",
                  hintStyle: GoogleFonts.poppins(
                    color: global.labelColor,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              )
            : Text(
                widget.showMyQuizzes
                    ? "MY QUIZZES"
                    : (widget.showManagedQuizzes
                        ? "MANAGED QUIZZES"
                        : "THINKFAST"),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: global.valueColor,
                  letterSpacing: 1.5,
                ),
              ),
        iconTheme: const IconThemeData(color: global.valueColor),
        actions: [
          if (global.isAdmin) const AdminBadge(),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = "";
                  _searchController.clear();
                }
              });
            },
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: global.cardColor,
        child: SidebarMenu(user: _user),
      ),
      body: Container(
        color: global.bgColor,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: readDatabases(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: global.primaryAccent),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  "No quizzes available",
                  style: TextStyle(color: global.labelColor),
                ),
              );
            }

            final filteredQuizzes = snapshot.data!.where((quiz) {
              final title = (quiz['title'] ?? "").toString().toLowerCase();
              return title.contains(_searchQuery);
            }).toList();

            if (filteredQuizzes.isEmpty) {
              return const Center(
                child: Text(
                  "No matching quizzes found",
                  style: TextStyle(color: global.labelColor),
                ),
              );
            }

            return ListView.builder(
              itemCount: filteredQuizzes.length,
              itemBuilder: (context, index) {
                return buildQuizCard(filteredQuizzes[index]);
              },
            );
          },
        ),
      ),
      floatingActionButton: global.featureFlags?['random_quiz_generator'] == true
          ? FloatingActionButton.extended(
              onPressed: () {
                // To be implemented: Navigate to a random public quiz
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Random Quiz feature coming soon!")),
                );
              },
              backgroundColor: global.btnColor,
              icon: const Icon(Icons.shuffle_rounded),
              label: const Text("RANDOM"),
            )
          : null,
    );
  }
}
