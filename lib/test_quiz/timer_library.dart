import 'dart:async';
import 'package:flutter/material.dart';

void main() {
  runApp(const TimerApp());
}

class TimerApp extends StatelessWidget {
  const TimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: TimerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  Duration _timeLeft = const Duration(seconds: 5); // change limit here
  Timer? _timer;

  String _format(Duration d) =>
      "${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:"
          "${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";

  void _startTimer() {
    _timer?.cancel();
    setState(() => _timeLeft = const Duration(seconds: 5)); // reset to limit

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        if (_timeLeft.inSeconds > 0) {
          _timeLeft -= const Duration(seconds: 1);
        } else {
          t.cancel();
          _runScript(); // ✅ run custom script at end
        }
      });
    });
  }

  void _runScript() {
    // Your custom code here
    print("⏰ Timer finished, running script...");

    // Example: navigate to another page
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ResultScreen()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Countdown Timer"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Container(
            color: Colors.redAccent,
            height: 30,
            alignment: Alignment.center,
            child: Text(
              _timer?.isActive == true
                  ? "⏳ Time left: ${_format(_timeLeft)}"
                  : "No active timer",
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _startTimer,
          child: const Text("Start Timer"),
        ),
      ),
    );
  }
}

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Result")),
      body: const Center(
        child: Text("✅ Script executed!"),
      ),
    );
  }
}
