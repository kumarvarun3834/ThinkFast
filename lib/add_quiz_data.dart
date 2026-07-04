import 'package:flutter/material.dart';
import 'package:thinkfast/utils/global.dart' as global;

class QuizForm extends StatefulWidget {
  final Map<String, Object> formDataPart;
  final void Function(Map<String, Object>) onChanged;
  final bool showIndividualMarking;
  final List<String> moduleOptions;

  const QuizForm({
    super.key,
    required this.formDataPart,
    required this.onChanged,
    required this.moduleOptions,
    this.showIndividualMarking = false,
  });

  @override
  State<QuizForm> createState() => _QuizFormState();
}

class _QuizFormState extends State<QuizForm> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _correctAnswerController =
      TextEditingController();
  final List<TextEditingController> _choiceControllers = [];
  final TextEditingController _correctController =
      TextEditingController(text: "4");
  final TextEditingController _wrongController =
      TextEditingController(text: "-1");
  final TextEditingController _timerController =
      TextEditingController(text: "0");
  Set<int> _selectedAnswers = {};
  String? _selectedValue;
  String? _selectedModule;

  @override
  void initState() {
    super.initState();

    // Load existing marking if any
    if (widget.formDataPart["correct"] != null) {
      _correctController.text = widget.formDataPart["correct"].toString();
    }
    if (widget.formDataPart["wrong"] != null) {
      _wrongController.text = widget.formDataPart["wrong"].toString();
    }
    if (widget.formDataPart["timer"] != null) {
      _timerController.text = widget.formDataPart["timer"].toString();
    }
    if (widget.formDataPart["subject"] != null) {
      _selectedModule = widget.formDataPart["subject"] as String;
    }

    if (_selectedModule == null ||
        !widget.moduleOptions.contains(_selectedModule)) {
      _selectedModule = widget.moduleOptions.isNotEmpty
          ? widget.moduleOptions.first
          : "General";
    }

    if (widget.formDataPart["question"] != null) {
      _questionController.text = widget.formDataPart["question"] as String;
    }
    if (widget.formDataPart["description"] != null) {
      _descriptionController.text = widget.formDataPart["description"] as String;
    }

    // Load existing type
    if (widget.formDataPart["type"] != null) {
      _selectedValue = widget.formDataPart["type"] as String;
    }

    // Load existing choices
    if (widget.formDataPart["choices"] != null) {
      List choices = widget.formDataPart["choices"] as List;
      for (var choice in choices) {
        final controller = TextEditingController(text: choice.toString());
        _choiceControllers.add(controller);
      }
    } else {
      _choiceControllers.add(TextEditingController());
    }

    // Load existing answers
    if (widget.formDataPart["answers"] != null) {
      List answers = widget.formDataPart["answers"] as List;
      
      if (_selectedValue == "Integer" && answers.isNotEmpty) {
        _correctAnswerController.text = answers.first.toString();
      } else {
        for (var answer in answers) {
          final index = (widget.formDataPart["choices"] as List).indexOf(
            answer,
          );
          if (index != -1) {
            _selectedAnswers.add(index);
          }
        }
      }
    }

    /// 🔧 Emit data *after first frame* to avoid calling setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) => _emitData());
  }

  void _emitData() {
    final choices = _choiceControllers.map((c) => c.text.trim()).toList();
    List<String> answers;
    
    if (_selectedValue == "Integer") {
      answers = [_correctAnswerController.text.trim()];
    } else {
      answers = _selectedAnswers.map((i) => choices[i]).toList();
    }

    widget.onChanged({
      "type": _selectedValue ?? "",
      "subject": _selectedModule ?? "General",
      "question": _questionController.text.trim(),
      "description": _descriptionController.text.trim(),
      "choices": choices,
      "answers": answers,
      "correct": int.tryParse(_correctController.text) ?? 4,
      "wrong": int.tryParse(_wrongController.text) ?? -1,
      "timer": int.tryParse(_timerController.text) ?? 0,
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
          activeColor: global.primaryAccent,
          side: const BorderSide(color: global.labelColor),
          onChanged: (val) => _toggleAnswer(index, val),
        ),
        Expanded(
          child: TextField(
            controller: _choiceControllers[index],
            style: const TextStyle(color: global.valueColor),
            decoration: InputDecoration(
              labelText: "Choice ${index + 1}",
              labelStyle: const TextStyle(color: global.labelColor),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: global.borderColor),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: global.primaryAccent),
              ),
            ),
            onChanged: (_) => _emitData(),
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.remove_circle_outline_rounded,
            color: global.errorColor,
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

  List<Widget> optionsData() => List.generate(
    _choiceControllers.length,
    (y) => Column(children: [choicetemplate(y), SizedBox(height: 8)]),
  );

  @override
  Widget build(BuildContext context) {
    final List<String> options = ["Multiple Choice", "Single Choice", "Integer"];

    return Material(
      color: global.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: global.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              dropdownColor: global.cardColor,
              style: const TextStyle(color: global.valueColor),
              initialValue: options.contains(_selectedValue)
                  ? _selectedValue
                  : null,
              decoration: const InputDecoration(
                labelText: "Question Type",
                labelStyle: TextStyle(color: global.labelColor),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: global.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: global.primaryAccent),
                ),
              ),
              items: options.map((String option) {
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
            DropdownButtonFormField<String>(
              dropdownColor: global.cardColor,
              style: const TextStyle(color: global.valueColor),
              initialValue: widget.moduleOptions.contains(_selectedModule)
                  ? _selectedModule
                  : (widget.moduleOptions.isNotEmpty
                      ? widget.moduleOptions.first
                      : null),
              decoration: const InputDecoration(
                labelText: "Subject / Module Name",
                labelStyle: TextStyle(color: global.labelColor),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: global.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: global.primaryAccent),
                ),
              ),
              items: widget.moduleOptions.map((String module) {
                return DropdownMenuItem<String>(
                  value: module,
                  child: Text(module),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedModule = value;
                });
                _emitData();
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _questionController,
              style: const TextStyle(color: global.valueColor),
              maxLines: null,
              decoration: const InputDecoration(
                labelText: "Question Prompt",
                labelStyle: TextStyle(color: global.labelColor),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: global.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: global.primaryAccent),
                ),
              ),
              onChanged: (_) => _emitData(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              style: const TextStyle(color: global.valueColor),
              maxLines: null,
              decoration: const InputDecoration(
                labelText: "Solution / Description",
                labelStyle: TextStyle(color: global.labelColor),
                hintText: "Explain the answer...",
                hintStyle: TextStyle(color: global.hintColor, fontSize: 12),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: global.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: global.primaryAccent),
                ),
              ),
              onChanged: (_) => _emitData(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.showIndividualMarking) ...[
                  Expanded(
                    child: TextField(
                      controller: _correctController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: global.valueColor),
                      decoration: const InputDecoration(
                        labelText: "Correct Score",
                        labelStyle: TextStyle(color: global.labelColor),
                      ),
                      onChanged: (_) => _emitData(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _wrongController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: global.valueColor),
                      decoration: const InputDecoration(
                        labelText: "Wrong Score",
                        labelStyle: TextStyle(color: global.labelColor),
                      ),
                      onChanged: (_) => _emitData(),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: TextField(
                    controller: _timerController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: global.valueColor),
                    decoration: const InputDecoration(
                      labelText: "Question Timer (sec)",
                      labelStyle: TextStyle(color: global.labelColor),
                      hintText: "0 = use global",
                    ),
                    onChanged: (_) => _emitData(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedValue == "Integer")
              TextField(
                controller: _correctAnswerController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: global.valueColor),
                decoration: const InputDecoration(
                  labelText: "Correct Integer Value",
                  labelStyle: TextStyle(color: global.labelColor),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: global.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: global.primaryAccent),
                  ),
                ),
                onChanged: (_) => _emitData(),
              )
            else ...[
              Column(children: optionsData()),
              const SizedBox(height: 12),
              if (_selectedAnswers.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    "⚠️ Select at least one correct answer",
                    style: TextStyle(
                      color: global.warningColor.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ),
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
                        color: global.primaryAccent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Add Choice",
                        style: TextStyle(
                          color: global.primaryAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// this will eliminate the setState during build error
// your QuizPage doesn’t need changes now - it was fine
