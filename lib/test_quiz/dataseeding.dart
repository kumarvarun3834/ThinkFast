import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:thinkfast/test_quiz/questions_file.dart';
import 'package:thinkfast/utils/global.dart' as global;

import 'demo_quiz.dart';

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

  void createQuiz({int type = 0}) async {
    setState(() {
      status = 'Generating quiz...';
    });

    List<Map<String, Object>> questions;
    String title;
    String description;
    int time = 10;

    switch (type) {
      case 1: // Flutter
        questions = testQuestions;
        title = 'Flutter Basics Quiz';
        description = 'Test your Flutter knowledge';
        break;
      case 2: // Demo Quiz from JSON string
        final decoded = jsonDecode(demoQuizJson);
        questions = List<Map<String, Object>>.from(decoded['questions']);
        title = decoded['title'];
        description = decoded['description'];
        time = decoded['time'] ?? 10;
        break;
      default: // Math
        questions = generateMathQuestions(20);
        title = 'Math Quiz';
        description = 'Simple math quiz generated via dataseeding.dart';
    }

    final docId = await global.qAdminConnect.createDatabase(
      creatorId: "SYSTEM_SEEDER",
      user: "System Seeder",
      title: title,
      description: description,
      visibility: 'public',
      data: questions,
      time: time,
    );

    setState(() {
      status = 'Quiz created! Doc ID: $docId';
    });
  }

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
        "answers": ["$ans"],
        "subject": "Mathematics",
      });
    }

    return questions;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              status,
              // textAlign: Al
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => createQuiz(type: 0),
            child: const Text('Create Math Quiz'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => createQuiz(type: 1),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
            child: const Text('Create Flutter Basics Quiz'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => createQuiz(type: 2),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('Create Interactive Demo Quiz'),
          ),
        ],
      ),
    );
  }
}
