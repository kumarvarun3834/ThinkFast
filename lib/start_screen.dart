import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/TextContainer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Main_Screen extends StatelessWidget {
  final Function(Widget) onPressed;

  Main_Screen({super.key, required this.onPressed});

  final CollectionReference _db = FirebaseFirestore.instance.collection('databases');

  /// ✅ Fetch public datasets as a stream
  Stream<List<Map<String, dynamic>>> readPublicDatabases() {
    return _db.where('visibility', isEqualTo: 'public').snapshots().map(
          (snapshot) => snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList(),
    );
  }

  Widget buildQuizCard(Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.all(15),
      elevation: 3,
      color: const Color.fromARGB(255, 255, 225, 255),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.blueAccent,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextContainer(data["title"] as String, Colors.black, 30),
                  const TextContainer("Are you ready ?", Colors.black, 30),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(5.0),
            child: ElevatedButton(
              onPressed: () {
                // TODO: navigate to quiz screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              child: Text(
                "START",
                style: GoogleFonts.poppins(
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: readPublicDatabases(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No public quizzes available.'));
        }

        final dataset = snapshot.data!;
        return SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: dataset.map(buildQuizCard).toList(),
          ),
        );
      },
    );
  }
}
