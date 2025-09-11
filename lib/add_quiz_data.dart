import 'package:flutter/material.dart';

class QuizForm extends StatefulWidget {
  Map<String, Object> form_data_part;
  final void Function(Map<String, Object>) onChanged; // callback
  final void Function(TextEditingController, List<TextEditingController>, Set<int>, String?) saveForm;

  QuizForm({
    super.key,
    required this.form_data_part,
    required this.onChanged,
    required this.saveForm,
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
      if (_selectedValue == "Single Choice") {
        _selectedAnswers = {};
        _selectedAnswers.add(index);
      } else if (_selectedValue == "Multiple Choice") {
        if (checked == true) {
          _selectedAnswers.add(index);
        } else {
          _selectedAnswers.remove(index);
        }
      }
    });
    widget.saveForm(
  _questionController,
  _choiceControllers,
  _selectedAnswers,
  _selectedValue,
);
 // ✅ call properly
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
            onChanged: (_) => widget.saveForm(
              _questionController,
              _choiceControllers,
              _selectedAnswers,
              _selectedValue,
            )
          ),
          ),
        IconButton(
          icon: const Icon(Icons.remove_circle, color: Colors.red),
          onPressed: () {
            setState(() {
              _selectedAnswers.remove(index);
              _choiceControllers.removeAt(index);
            });
            widget.saveForm(
  _questionController,
  _choiceControllers,
  _selectedAnswers,
  _selectedValue,
);
 // ✅ call properly
          },
        ),
      ],
    );
  }

  List<Widget> options_data() {
    return List.generate(_choiceControllers.length, (y) => choicetemplate(y));
  }

  @override
  Widget build(BuildContext context) {
    final List<String> _options = ["Multiple Choice", "Single Choice"];
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
              widget.saveForm(
  _questionController,
  _choiceControllers,
  _selectedAnswers,
  _selectedValue,
);
 // ✅ call properly
            },
          ),

          // Question field
          TextField(
            controller: _questionController,
            decoration: const InputDecoration(
              labelText: "Question",
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => widget.saveForm(
              _questionController,
              _choiceControllers,
              _selectedAnswers,
              _selectedValue,
            )
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
                onPressed: () {
                  _addChoice();
                  widget.saveForm(
  _questionController,
  _choiceControllers,
  _selectedAnswers,
  _selectedValue,
);
 // ✅ call properly
                },
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
