import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart'; // your service file

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Math Quiz DB Generator',
      home: Scaffold(
        appBar: AppBar(title: const Text('Math Quiz DB Generator')),
        body: const QuizGenerator(),
      ),
    );
  }
}

class QuizGenerator extends StatefulWidget {
  const QuizGenerator({super.key});

  @override
  State<QuizGenerator> createState() => _QuizGeneratorState();
}

class _QuizGeneratorState extends State<QuizGenerator> {
  String status = 'Press button to create quiz';

  void createQuiz() async {
    setState(() {
      status = 'Generating quiz...';
    });

    List<Map<String, Object>> generateMathQuestions(int count) {
      final rand = DateTime.now().millisecondsSinceEpoch % 100;
      List<Map<String, Object>> questions = [];

      for (int i = 0; i < count; i++) {
        int a = (rand + i * 3) % 50 + 1;
        int b = (rand + i * 7) % 50 + 1;
        String op;
        int ans;

        switch (i % 4) {
          case 0:
            op = '+';
            ans = a + b;
            break;
          case 1:
            op = '-';
            ans = a - b;
            break;
          case 2:
            op = '*';
            ans = a * b;
            break;
          default:
            op = '/';
            ans = b != 0 ? (a ~/ b) : 0;
            break;
        }

        questions.add({
          "question": "$a $op $b",
          "type": "Multiple Choice",
          "choices": [
            "$ans",
            "${ans + 1}",
            "${ans + 2}",
            "${ans + 3}",
            "${ans + 4}",
            "${ans + 5}",
          ],
          "answers": ["$ans"] // first choice is correct
        });
      }

      return questions;
    }

    final db = DatabaseService();
    final questions = generateMathQuestions(20); // 20 questions
    final docId = await db.createDatabase(
      creatorId: "",              // REQUIRED
      user: "",    // display only
      title: 'Math Quiz',
      description: 'Simple math quiz',
      visibility: 'public',
      data: questions,
      time: 10,                          // int (minutes)
    );


    setState(() {
      status = 'Quiz created! Doc ID: $docId';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(status),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: createQuiz,
            child: const Text('Create Quiz in Firestore'),
          ),
        ],
      ),
    );
  }
}
