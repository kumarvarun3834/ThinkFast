import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

class QuizForm extends StatefulWidget {
  const QuizForm({super.key});

  @override
  State<QuizForm> createState() => _QuizFormState();
}

class _QuizFormState extends State<QuizForm> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _choiceControllers = [];
  final Set<int> _selectedAnswers = {}; // stores indexes of correct options
  late int i;
  @override
  void initState() {
    super.initState();
    _addChoice(); // start with one choice
    i=2;
  }

  void _addChoice() {
    setState(() {
      _choiceControllers.add(TextEditingController());
    });
  }

  void _toggleAnswer(int index, bool? checked) {
    setState(() {
      if (checked == true) {
        _selectedAnswers.add(index);
      } else {
        _selectedAnswers.remove(index);
      }
    });
  }

  Widget choicetemplate(int index) {
    return Row(
      children: [
        Checkbox(
          value: _selectedAnswers.contains(index),
          onChanged: (val) => _toggleAnswer(index, val),
        ),
        Expanded(
          child: TextField(
            controller: _choiceControllers[index],
            decoration: InputDecoration(
              labelText: "Choice ${index + 1}",
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle, color: Colors.red),
          onPressed: () {
            setState(() {
              // also clean up selectedAnswers if removed
              _selectedAnswers.remove(index);
              _choiceControllers.removeAt(index);
            });
          },
        ),
      ],
    );
  }


  List<Widget> options_data(){
    List<Widget> options_data=[];
    for (int y=0;y==i;y++){
      options_data.add(choicetemplate(y));
    }
    return options_data;
  }
  void _saveForm() {
    final question = _questionController.text.trim();
    final choices = _choiceControllers.map((c) => c.text.trim()).toList();
    final answers = _selectedAnswers.map((i) => choices[i]).toList();

    print("Question: $question");
    print("Choices: $choices");
    print("Correct Answers: $answers");
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question field
          TextField(
            controller: _questionController,
            decoration: const InputDecoration(
              labelText: "Question",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // Choices list
          Column(
            children: [Column(children: options_data()),

          const SizedBox(height: 8),

          // Add choice button
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blue),
                onPressed: (){
                  i+=1;
                  _addChoice();
                  print(i);},
              ),
              const Text("Add Choice"),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    ]
      )
    );
  }
}
