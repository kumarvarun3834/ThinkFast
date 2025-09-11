import 'package:flutter/material.dart';

class QuizForm extends StatefulWidget {
  final Map<String, Object> form_data_part;
  final void Function(Map<String, Object>) onChanged; // callback

  const QuizForm({
    super.key,
    required this.form_data_part,
    required this.onChanged,
  });

  @override
  State<QuizForm> createState() => _QuizFormState();
}


class _QuizFormState extends State<QuizForm> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _choiceControllers = [];
  Set<int> _selectedAnswers = {}; // stores indexes of correct options
  String? _selectedValue; // current selected item
  @override
  void initState() {
    super.initState();
    _addChoice();
    _addChoice();
  }

  void _addChoice() {
    setState(() {
      _choiceControllers.add(TextEditingController());
    });
  }

  void _toggleAnswer(int index, bool? checked) {
    setState(() {
      if (_selectedValue=="Single Choice"){
        _selectedAnswers={};
        _selectedAnswers.add(index);
      }else if (_selectedValue=="Multiple Choice"){
      if (checked == true) {
        _selectedAnswers.add(index);
      } else {
        _selectedAnswers.remove(index);
      }}
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
              _selectedAnswers.remove(index);
              _choiceControllers.removeAt(index);
            });
          },
        ),
      ],
    );
  }

  List<Widget> options_data() {
    List<Widget> widgets = [];
    for (int y = 0; y < _choiceControllers.length; y++) {
      widgets.add(choicetemplate(y));
    }
    return widgets;
  }

  void _saveForm() {
    final question = _questionController.text.trim();
    final choices = _choiceControllers.map((c) => c.text.trim()).toList();
    final answers = _selectedAnswers.map((i) => choices[i]).toList();
    print("Type: $_selectedValue");
    print("Question: $question");
    print("Choices: $choices");
    print("Correct Answers: $answers");
  }

  @override
  Widget build(BuildContext context) {
    final List<String> _options = ["Multiple Choice","Single Choice"];
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
          DropdownButton<String>(
            value: _selectedValue,
            hint: const Text("Type"),
            items: _options.map((String option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(option),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedValue = value;
              });
            },),
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
          Column(children: options_data()),

          const SizedBox(height: 8),

          // Add choice button
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blue),
                onPressed: _addChoice,
              ),
              const Text("Add Choice"),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
