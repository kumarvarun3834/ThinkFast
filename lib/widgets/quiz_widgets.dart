import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/utils/global.dart' as global;

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty || value == 'null') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.poppins(
              color: global.labelColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: global.primaryAccent),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: global.valueColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class VisibilityBadge extends StatelessWidget {
  final String visibility;
  final bool isLocked;

  const VisibilityBadge({
    super.key,
    required this.visibility,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    if (isLocked) {
      color = global.errorColor;
    } else {
      switch (visibility.toLowerCase()) {
        case 'public':
          color = global.successColor;
          break;
        case 'private':
          color = global.warningColor;
          break;
        default:
          color = Colors.blueGrey;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            isLocked ? "LOCKED" : visibility.toUpperCase(),
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class QuizActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isPrimary;
  final IconData? icon;
  final VoidCallback? onDoubleTap;

  const QuizActionButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isPrimary = false,
    this.icon,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary
              ? global.btnColor
              : Colors.white.withOpacity(0.05),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isPrimary ? BorderSide.none : const BorderSide(color: global.borderColor),
          ),
          elevation: isPrimary ? 4 : 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 20)],
          ],
        ),
      ),
    );
  }
}

class AdminBadge extends StatelessWidget {
  const AdminBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const StatusBadge(text: "ADMIN", color: global.errorColor);
  }
}

class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;
  final EdgeInsets padding;

  const StatusBadge({
    super.key,
    required this.text,
    required this.color,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withOpacity(0.5),
        ),
      ),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.poppins(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class AiGenerationDialog extends StatefulWidget {
  final Function(String json) onGenerated;
  final String buttonText;

  const AiGenerationDialog({
    super.key,
    required this.onGenerated,
    this.buttonText = "GENERATE",
  });

  @override
  State<AiGenerationDialog> createState() => _AiGenerationDialogState();
}

class _AiGenerationDialogState extends State<AiGenerationDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: global.cardColor,
      title: Text(
        "AI Quiz Generator",
        style: GoogleFonts.poppins(color: global.valueColor),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Describe the quiz topic, number of questions, and difficulty level.",
            style: TextStyle(color: global.labelColor, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 3,
            style: const TextStyle(color: global.valueColor, fontSize: 13),
            decoration: InputDecoration(
              hintText: "e.g. Physics quiz on Newton's laws, 10 questions, Medium...",
              hintStyle: const TextStyle(color: global.hintColor),
              filled: true,
              fillColor: global.bgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          if (_isGenerating) ...[
            const SizedBox(height: 20),
            const LinearProgressIndicator(color: global.primaryAccent),
          ]
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isGenerating ? null : () => Navigator.pop(context),
          child: const Text("CANCEL", style: TextStyle(color: global.labelColor)),
        ),
        ElevatedButton(
          onPressed: _isGenerating ? null : _generate,
          style: ElevatedButton.styleFrom(backgroundColor: global.primaryAccent),
          child: Text(widget.buttonText),
        ),
      ],
    );
  }

  void _generate() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;

    setState(() => _isGenerating = true);
    try {
      // Note: We'll use a mock generator for now as actual AI integration 
      // usually requires secret keys.
      await Future.delayed(const Duration(seconds: 2));
      final json = jsonEncode({
        "title": "AI: $prompt",
        "description": "Generated by ThinkFast AI",
        "time": 600,
        "markingScheme": {"type": "default"},
        "questions": [
          {
            "question": "Sample question about $prompt?",
            "choices": ["Option 1", "Option 2", "Option 3", "Option 4"],
            "answers": ["Option 1"],
            "type": "Single Choice",
            "subject": "General",
            "correct": 4,
            "wrong": -1
          }
        ]
      });
      widget.onGenerated(json);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AI Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}
