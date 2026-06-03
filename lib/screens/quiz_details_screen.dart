import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thinkfast/widgets/TextContainer.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';
import 'package:thinkfast/utils/global.dart' as global;

class QuizDetailsScreen extends StatefulWidget {
  final String quizId;

  const QuizDetailsScreen({super.key, required this.quizId});

  @override
  State<QuizDetailsScreen> createState() => _QuizDetailsScreenState();
}

class _QuizDetailsScreenState extends State<QuizDetailsScreen> {
  User? _user;
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _creatorProfile;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _quizData;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _fetchQuizDetails();
  }

  Future<void> _fetchQuizDetails() async {
    try {
      final db = DatabaseService();
      final data = await db.readDatabase(widget.quizId);
      
      Map<String, dynamic>? creatorProfile;
      if (data['creatorId'] != null) {
        creatorProfile = await db.getUserProfile(data['creatorId']);
      }

      Map<String, dynamic>? userProfile;
      if (_user != null) {
        userProfile = await db.getUserProfile(_user!.uid);
      }

      setState(() {
        _quizData = data;
        _creatorProfile = creatorProfile;
        _userProfile = userProfile;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching details: $e")),
        );
        Navigator.pop(context);
      }
    }
  }

  ElevatedButton actionButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_quizData == null) {
      return const Scaffold(
        body: Center(child: Text("No quiz found")),
      );
    }

    final bool isOwner = _user != null && _quizData!['creatorId'] == _user!.uid;
    final bool isPublic = _quizData!['visibility'] == 'public';

    return Scaffold(
      appBar: AppBar(
        title: TextContainer("Quiz Details", Colors.black, 20),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextContainer(
                        "Title: ${_quizData!['title'] ?? 'Untitled'}",
                        Colors.white,
                        24,
                      ),
                      const SizedBox(height: 10),
                      TextContainer(
                        "ID: ${_quizData!['id']}",
                        Colors.white70,
                        16,
                      ),
                      const SizedBox(height: 10),
                      TextContainer(
                        "Created by: ${_creatorProfile?['name'] ?? _creatorProfile?['email'] ?? 'Unknown'}",
                        Colors.white70,
                        18,
                      ),
                      const SizedBox(height: 10),
                      TextContainer(
                        "Description: ${_quizData!['description'] ?? 'No description'}",
                        Colors.white70,
                        18,
                      ),
                      const SizedBox(height: 10),
                      TextContainer(
                        "Time: ${_quizData!['time'] ~/ 60} minutes",
                        Colors.white70,
                        18,
                      ),
                      const SizedBox(height: 10),
                      TextContainer(
                        "Visibility: ${_quizData!['visibility']}",
                        Colors.white70,
                        18,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              actionButton("Start Quiz", () {
                if (isPublic || isOwner) {
                  global.quizData = (_quizData!['data'] as List<dynamic>)
                      .map((e) => Map<String, Object>.from(e))
                      .toList();

                  global.time = _quizData!['time'] as int;
                  global.currentUserProfile = _userProfile;
                  global.creatorProfile = _creatorProfile;
                  
                  Navigator.pushNamed(context, "/Quiz");
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("This quiz is private")),
                  );
                }
              }),
              if (isOwner) ...[
                const SizedBox(height: 15),
                actionButton("Update Quiz", () {
                  global.quizData = (_quizData!['data'] as List<dynamic>)
                      .map((e) => Map<String, Object>.from(e))
                      .toList();

                  global.ID = _quizData!['id'];
                  global.currentUserProfile = _userProfile;
                  global.creatorProfile = _creatorProfile;

                  Navigator.pushNamed(context, "/Update Quiz");
                }),
                const SizedBox(height: 15),
                actionButton("Delete Quiz", () async {
                  try {
                    await DatabaseService().deleteDatabase(
                      docId: _quizData!['id'],
                      currentUserId: _user!.uid,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Quiz deleted")),
                      );
                      Navigator.pop(context);
                    }
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Only the creator can delete this quiz"),
                        ),
                      );
                    }
                  }
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
