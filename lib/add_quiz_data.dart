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
  void initState() {
    super.initState();

    // Load existing question
    if (widget.form_data_part["question"] != null) {
      _questionController.text = widget.form_data_part["question"] as String;
    }

    // Load existing type
    if (widget.form_data_part["type"] != null) {
      _selectedValue = widget.form_data_part["type"] as String;
    }

    // Load existing choices
    if (widget.form_data_part["choices"] != null) {
      List choices = widget.form_data_part["choices"] as List;
      for (var choice in choices) {
        final controller = TextEditingController(text: choice.toString());
        _choiceControllers.add(controller);
      }
    } else {
      _choiceControllers.add(TextEditingController());
    }

    // Load existing answers
    if (widget.form_data_part["answers"] != null) {
      List answers = widget.form_data_part["answers"] as List;
      for (var answer in answers) {
        final index = (widget.form_data_part["choices"] as List).indexOf(
          answer,
        );
        if (index != -1) {
          _selectedAnswers.add(index);
        }
      }
    }

    /// 🔧 Emit data *after first frame* to avoid calling setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) => _emitData());
  }

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
    setState(() => _choiceControllers.add(TextEditingController()));
    WidgetsBinding.instance.addPostFrameCallback((_) => _emitData()); // 🔧
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _emitData()); // 🔧
  }

  Widget choicetemplate(int index) {
    return Row(
      children: [
        Checkbox(
          value: _selectedAnswers.contains(index),
          activeColor: const Color(0xFF3B82F6),
          side: const BorderSide(color: Color(0xFF94A3B8)),
          onChanged: (val) => _toggleAnswer(index, val),
        ),
        Expanded(
          child: TextField(
            controller: _choiceControllers[index],
            style: const TextStyle(color: Color(0xFFE2E8F0)),
            decoration: InputDecoration(
              labelText: "Choice ${index + 1}",
              labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF334155)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF3B82F6)),
              ),
            ),
            onChanged: (_) => _emitData(),
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.remove_circle_outline_rounded,
            color: Colors.redAccent,
          ),
          onPressed: () {
            setState(() {
              _selectedAnswers.remove(index);
              _choiceControllers.removeAt(index);
            });
            WidgetsBinding.instance.addPostFrameCallback((_) => _emitData());
          },
        ),
      ],
    );
  }

  List<Widget> options_data() => List.generate(
    _choiceControllers.length,
    (y) => Column(children: [choicetemplate(y), SizedBox(height: 8)]),
  );

  @override
  Widget build(BuildContext context) {
    final List<String> _options = ["Multiple Choice", "Single Choice"];

    return Material(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Color(0xFFE2E8F0)),
              initialValue: _options.contains(_selectedValue)
                  ? _selectedValue
                  : null,
              decoration: const InputDecoration(
                labelText: "Question Type",
                labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF3B82F6)),
                ),
              ),
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
            const SizedBox(height: 16),
            TextField(
              controller: _questionController,
              style: const TextStyle(color: Color(0xFFE2E8F0)),
              decoration: const InputDecoration(
                labelText: "Question Prompt",
                labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF3B82F6)),
                ),
              ),
              onChanged: (_) => _emitData(),
            ),
            const SizedBox(height: 16),
            Column(children: options_data()),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _addChoice,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_circle_outline_rounded,
                      color: Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Add Choice",
                      style: TextStyle(
                        color: const Color(0xFF3B82F6),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// this will eliminate the setState during build error
// your QuizPage doesn’t need changes now - it was fine
