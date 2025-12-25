import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:thinkfast/widgets/TextContainer.dart';
import 'package:thinkfast/widgets/drawer_data.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';
import 'package:thinkfast/utils/global.dart' as global;

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

  final CollectionReference _db =
  FirebaseFirestore.instance.collection('databases');

  @override
  void initState() {
    super.initState();
    _auth.authStateChanges().listen((u) {
      if (mounted) setState(() => _user = u);
    });
  }

  /// 🔥 READ QUIZZES
  Stream<List<Map<String, dynamic>>> readDatabases() {
    Query query = _db;

    if (widget.showMyQuizzes && widget.creator != null) {
      query = query.where('creatorId', isEqualTo: widget.creator!.uid);
    } else {
      query = query.where('visibility', isEqualTo: 'public');
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// 🔘 COMMON BUTTON
  ElevatedButton actionButton(
      String text, VoidCallback onPressed) {
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

  /// 🧩 QUIZ CARD
  Widget buildQuizCard(Map<String, dynamic> data) {
    final bool isOwner =
        _user != null && data['creatorId'] == _user!.uid;
    final bool isPublic = data['visibility'] == 'public';

    return Card(
      margin: const EdgeInsets.all(15),
      elevation: 3,
      color: const Color.fromARGB(255, 255, 225, 255),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.blueAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextContainer(
                    "Title: ${data['title'] ?? 'Untitled'}",
                    Colors.white,
                    24,
                  ),
                  const SizedBox(height: 6),
                  TextContainer(
                    "Description: ${data['description'] ?? 'No description'}",
                    Colors.white70,
                    18,
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [

                /// ▶ START QUIZ
                actionButton("Start Quiz", () {
                  if (isPublic || isOwner) {
                    global.quizData =
                        (data['data'] as List<dynamic>)
                            .map((e) => Map<String, Object>.from(e))
                            .toList();

                    global.time = data['time'] as int;
                    Navigator.pushNamed(context, "/Quiz");
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("This quiz is private"),
                      ),
                    );
                  }
                }),

                if (isOwner) ...[
                  const SizedBox(height: 8),

                  /// ✏ UPDATE
                  actionButton("Update Quiz", () {
                    global.quizData =
                        (data['data'] as List<dynamic>)
                            .map((e) => Map<String, Object>.from(e))
                            .toList();

                    global.ID = data['id'];
                    Navigator.pushNamed(context, "/Update Quiz");
                  }),

                  const SizedBox(height: 8),

                  /// 🗑 DELETE
                  actionButton("Delete Quiz", () async {
                    try {
                      await DatabaseService().deleteDatabase(
                        docId: data['id'],
                        currentUserId: _user!.uid,
                      );

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Quiz deleted"),
                        ),
                      );
                    } catch (_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              "Only the creator can delete this quiz"),
                        ),
                      );
                    }
                  }),
                ],
              ],
            ),
          ),
        ],
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
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text("No quizzes available"),
              );
            }

            return SingleChildScrollView(
              child: Column(
                children:
                snapshot.data!.map(buildQuizCard).toList(),
              ),
            );
          },
        ),
      ),
    );
  }
}
