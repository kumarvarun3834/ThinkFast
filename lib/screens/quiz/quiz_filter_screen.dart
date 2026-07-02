import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/utils/global.dart' as global;

class QuizFilterScreen extends StatefulWidget {
  final Set<String> initialTags;
  final Set<String> initialSubjects;
  final bool initialStrict;
  final List<Map<String, dynamic>> allQuizzes;

  const QuizFilterScreen({
    super.key,
    required this.initialTags,
    required this.initialSubjects,
    required this.initialStrict,
    required this.allQuizzes,
  });

  @override
  State<QuizFilterScreen> createState() => _QuizFilterScreenState();
}

class _QuizFilterScreenState extends State<QuizFilterScreen> {
  late Set<String> _selectedTags;
  late Set<String> _selectedSubjects;
  late bool _isStrict;
  final Set<String> _availableModules = {};
  final Set<String> _availableExams = {};

  @override
  void initState() {
    super.initState();
    _selectedTags = Set.from(widget.initialTags);
    _selectedSubjects = Set.from(widget.initialSubjects);
    _isStrict = widget.initialStrict;

    for (var quiz in widget.allQuizzes) {
      final modules = quiz['modules'] as List? ?? [];
      for (var module in modules) {
        if (module is Map && module.containsKey('subject')) {
          _availableModules.add(module['subject'].toString());
        }
      }
      if (quiz['examTag'] != null && quiz['examTag'].toString().isNotEmpty) {
        _availableExams.add(quiz['examTag'].toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Filter Quizzes",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedTags.clear();
                _selectedSubjects.clear();
              });
            },
            child: const Text("Clear All", style: TextStyle(color: global.errorColor)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildToggleSection(),
                  const SizedBox(height: 24),
                  if (_availableExams.isNotEmpty) ...[
                    _buildSectionTitle("EXAMS"),
                    const SizedBox(height: 12),
                    _buildChipGrid(_availableExams, _selectedSubjects),
                    const SizedBox(height: 24),
                  ],
                  if (_availableModules.isNotEmpty) ...[
                    _buildSectionTitle("MODULES / SUBJECTS"),
                    const SizedBox(height: 12),
                    _buildChipGrid(_availableModules, _selectedSubjects),
                    const SizedBox(height: 24),
                  ],
                  _buildTagSection(),
                ],
              ),
            ),
          ),
          _buildApplyButton(),
        ],
      ),
    );
  }

  Widget _buildToggleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("FILTER MODE"),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _filterModeChip("NORMAL", !_isStrict),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _filterModeChip("STRICT", _isStrict),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _isStrict 
            ? "Showing quizzes that ONLY contain selected tags/modules."
            : "Showing quizzes that contain AT LEAST ONE selected tag/module.",
          style: const TextStyle(color: global.labelColor, fontSize: 10, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _filterModeChip(String label, bool isSelected) {
    return InkWell(
      onTap: () => setState(() => _isStrict = (label == "STRICT")),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? global.primaryAccent : global.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? global.primaryAccent : global.borderColor,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : global.valueColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        color: global.labelColor,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildChipGrid(Set<String> options, Set<String> selectedSet) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selectedSet.contains(option);
        return FilterChip(
          label: Text(
            option,
            style: TextStyle(
              color: isSelected ? Colors.black : global.valueColor,
              fontSize: 12,
            ),
          ),
          selected: isSelected,
          selectedColor: global.primaryAccent,
          checkmarkColor: Colors.black,
          backgroundColor: global.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected ? global.primaryAccent : global.borderColor,
            ),
          ),
          onSelected: (v) {
            setState(() {
              if (v) {
                selectedSet.add(option);
              } else {
                selectedSet.remove(option);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildTagSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tags')
          .orderBy('lastUsed', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final tags = snapshot.data!.docs
            .where((doc) {
              final List quizIds = (doc.data() as Map)['quizIds'] as List? ?? [];
              return quizIds.isNotEmpty;
            })
            .map((doc) => doc.id)
            .toList();

        if (tags.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("OTHER TAGS"),
            const SizedBox(height: 12),
            _buildChipGrid(tags.toSet(), _selectedTags),
          ],
        );
      },
    );
  }

  Widget _buildApplyButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'tags': _selectedTags,
                'subjects': _selectedSubjects,
                'isStrict': _isStrict,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: global.primaryAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Apply Filters",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
