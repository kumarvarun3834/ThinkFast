import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';
import 'package:thinkfast/services/firebase_options.dart';

/// 🚀 Run this as a standalone Flutter app to seed your database.
/// This file is for development/seeding purposes and is not integrated into the main app UI.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: InflaterScreen(),
  ));
}

class InflaterScreen extends StatefulWidget {
  const InflaterScreen({super.key});

  @override
  State<InflaterScreen> createState() => _InflaterScreenState();
}

class _InflaterScreenState extends State<InflaterScreen> {
  bool _isLoading = false;
  String _status = "Ready to inflate database.";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Standalone DB Inflater"),
        backgroundColor: const Color(0xFF1E293B),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.database_rounded, size: 80, color: Color(0xFF3B82F6)),
            const SizedBox(height: 20),
            Text(
              "Seeding Utility",
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "This will generate random math and trivia quizzes in your Firestore.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 40),
            if (_isLoading)
              const CircularProgressIndicator(color: Color(0xFF3B82F6))
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  setState(() {
                    _isLoading = true;
                    _status = "Checking authentication...";
                  });

                  final result = await DatabaseInflater.inflate();

                  setState(() {
                    _isLoading = false;
                    _status = result;
                  });
                },
                icon: const Icon(Icons.bolt_rounded, color: Colors.white),
                label: const Text("Inflate Random Quizzes", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _status.startsWith("Error") ? Colors.redAccent : Colors.greenAccent,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DatabaseInflater {
  static final _random = Random();
  static final _db = DatabaseService();

  static Future<String> inflate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return "Error: No user logged in. You must be authenticated to write to Firestore.";
    }

    try {
      // 1. Random Math Quiz (15 Questions)
      await _db.createDatabase(
        creatorId: user.uid,
        user: user.email ?? "Anonymous",
        title: "Dynamic Math Challenge 🔢",
        description: "A procedurally generated math quiz with varying difficulty.",
        visibility: "public",
        time: 10,
        data: _generateMathQuestions(15),
      );

      // 2. Random Trivia Quiz (15 Questions)
      await _db.createDatabase(
        creatorId: user.uid,
        user: user.email ?? "Anonymous",
        title: "Random Trivia Mix 🎲",
        description: "A random selection of single and multiple choice questions.",
        visibility: "public",
        time: 12,
        data: _generateRandomTrivia(15),
      );

      return "Success: Inflated 2 quizzes (30 questions total)! Check your home screen.";
    } catch (e) {
      return "Error: $e";
    }
  }

  static List<Map<String, Object>> _generateMathQuestions(int count) {
    return List.generate(count, (i) {
      // Alternate between Single Choice arithmetic and Multiple Choice logic
      if (i % 3 == 0) {
        // Multi-choice: Factors
        int num = (_random.nextInt(3) + 1) * 12; // 12, 24, 36
        List<String> factors = [];
        for (int f = 1; f <= num; f++) {
          if (num % f == 0) factors.add(f.toString());
        }
        
        List<String> choices = factors.take(3).toList(); // Take some correct ones
        while(choices.length < 5) {
           String fake = (_random.nextInt(50) + 1).toString();
           if (!factors.contains(fake)) choices.add(fake);
        }
        choices.shuffle();
        
        List<String> correctAnswers = choices.where((c) => factors.contains(c)).toList();

        return {
          "question": "Which of these are factors of $num?",
          "choices": choices,
          "answers": correctAnswers,
          "type": "Multiple Choice"
        };
      } else {
        // Single Choice: Arithmetic
        int a = _random.nextInt(50) + 1;
        int b = _random.nextInt(50) + 1;
        final ops = ['+', '-', '*'];
        final op = ops[_random.nextInt(ops.length)];
        int result;
        if (op == '+') result = a + b;
        else if (op == '-') result = a - b;
        else result = a * b;

        final choices = <String>{result.toString()};
        while (choices.length < 4) {
          choices.add((result + _random.nextInt(20) - 10).toString());
        }
        final choicesList = choices.toList()..shuffle();

        return {
          "question": "Calculate: $a $op $b",
          "choices": choicesList,
          "answers": [result.toString()],
          "type": "Single Choice"
        };
      }
    });
  }

  static List<Map<String, Object>> _generateRandomTrivia(int count) {
    final pool = [
      {"q": "Which of these are planets?", "c": ["Earth", "Mars", "The Moon", "Pluto", "Sun"], "a": ["Earth", "Mars", "Pluto"], "t": "Multiple Choice"},
      {"q": "Capital of France?", "c": ["Berlin", "London", "Paris", "Rome"], "a": ["Paris"], "t": "Single Choice"},
      {"q": "Programming languages?", "c": ["Dart", "Python", "HTML", "C++", "HTTP"], "a": ["Dart", "Python", "C++"], "t": "Multiple Choice"},
      {"q": "Square root of 144?", "c": ["10", "11", "12", "14"], "a": ["12"], "t": "Single Choice"},
      {"q": "Which are primary colors?", "c": ["Red", "Green", "Blue", "Yellow"], "a": ["Red", "Blue", "Yellow"], "t": "Multiple Choice"},
      {"q": "Fastest land animal?", "c": ["Lion", "Cheetah", "Horse", "Eagle"], "a": ["Cheetah"], "t": "Single Choice"},
      {"q": "Ocean names?", "c": ["Pacific", "Atlantic", "Caspian", "Indian"], "a": ["Pacific", "Atlantic", "Indian"], "t": "Multiple Choice"},
      {"q": "Year of first Moon landing?", "c": ["1965", "1969", "1971", "1959"], "a": ["1969"], "t": "Single Choice"},
    ];

    return List.generate(count, (i) {
      final item = pool[_random.nextInt(pool.length)];
      return {
        "question": item["q"]!,
        "choices": item["c"]!,
        "answers": item["a"]!,
        "type": item["t"]!
      };
    });
  }
}
