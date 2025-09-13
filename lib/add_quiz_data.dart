import 'package:flutter/material.dart';

class QuizForm extends StatefulWidget {
  final Map<String, Object> form_data_part;
  final void Function(Map<String, Object>) onChanged;

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
  Set<int> _selectedAnswers = {};
  String? _selectedValue;

  @override
  @override
  void initState() {
    super.initState();

    // load existing question
    if (widget.form_data_part["question"] != null) {
      _questionController.text = widget.form_data_part["question"] as String;
    }

    // load existing type
    if (widget.form_data_part["type"] != null) {
      _selectedValue = widget.form_data_part["type"] as String;
    }

    // load existing choices
    if (widget.form_data_part["choices"] != null) {
      List choices = widget.form_data_part["choices"] as List;
      for (var choice in choices) {
        final controller = TextEditingController(text: choice.toString());
        _choiceControllers.add(controller);
      }
    } else {
      _addChoice();
      // _addChoice();
    }

    // load existing answers
    if (widget.form_data_part["answers"] != null) {
      List answers = widget.form_data_part["answers"] as List;
      for (var answer in answers) {
        final index = (widget.form_data_part["choices"] as List).indexOf(answer);
        if (index != -1) {
          _selectedAnswers.add(index);
        }
      }
    }
  }


  /// 🔹 Helper: send current form state up to QuizPage
  void _emitData() {
    final choices = _choiceControllers.map((c) => c.text.trim()).toList();
    final answers = _selectedAnswers.map((i) => choices[i]).toList();

    widget.onChanged({
      "type": _selectedValue ?? "",
      "question": _questionController.text.trim(),
      "choices": choices,
      "answers": answers,
    });
  }

  void _addChoice() {
    setState(() {
      _choiceControllers.add(TextEditingController());
    });
    _emitData();
  }

  void _toggleAnswer(int index, bool? checked) {
    setState(() {
      if (_selectedValue == "Single Choice") {
        _selectedAnswers = {index};
      } else if (_selectedValue == "Multiple Choice") {
        if (checked == true) {
          _selectedAnswers.add(index);
        } else {
          _selectedAnswers.remove(index);
        }
      }
    });
    _emitData();
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
            onChanged: (_) => _emitData(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle, color: Colors.red),
          onPressed: () {
            setState(() {
              _selectedAnswers.remove(index);
              _choiceControllers.removeAt(index);
            });
            _emitData();
          },
        ),
      ],
    );
  }

  List<Widget> options_data() =>
      List.generate(_choiceControllers.length, (y) => choicetemplate(y));

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
              _emitData();
            },
          ),

          // Question field
          TextField(
            controller: _questionController,
            decoration: const InputDecoration(
              labelText: "Question",
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _emitData(),
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
