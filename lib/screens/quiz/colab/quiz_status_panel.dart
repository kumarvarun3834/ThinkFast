import 'package:flutter/material.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';
import 'package:thinkfast/utils/global.dart' as global;

class QuizStatusPanel extends StatefulWidget {
  final String quizId;
  final bool isLocked;
  final bool canLockUnlock;
  final bool isAdmin;
  final String? currentUserId;

  const QuizStatusPanel({
    super.key,
    required this.quizId,
    required this.isLocked,
    required this.canLockUnlock,
    required this.isAdmin,
    this.currentUserId,
  });

  @override
  State<QuizStatusPanel> createState() => _QuizStatusPanelState();
}

class _QuizStatusPanelState extends State<QuizStatusPanel> {
  bool _isProcessing = false;
  final DatabaseService _db = DatabaseService();

  Future<void> _toggleLock(bool newValue) async {
    final uid = widget.currentUserId;
    if (uid == null) return;
    
    setState(() => _isProcessing = true);
    try {
      await _db.toggleQuizLock(
        docId: widget.quizId,
        currentUserId: uid,
        isLocked: newValue,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newValue ? "Quiz Locked" : "Quiz Unlocked")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: global.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool managementEnabled = global.featureFlags?['management_features'] ?? true;
    final bool effectiveEnabled = widget.canLockUnlock && (widget.isAdmin || managementEnabled) && !_isProcessing;

    return Container(
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: effectiveEnabled ? global.borderColor : global.borderColor.withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: SwitchListTile(
          title: Text(
            widget.isLocked ? "Quiz is LOCKED" : "Quiz is UNLOCKED",
            style: TextStyle(
              color: effectiveEnabled ? global.valueColor : global.valueColor.withOpacity(0.4),
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            _isProcessing ? "Processing..." : (widget.isLocked ? "New attempts are blocked" : "Users can start new attempts"),
            style: TextStyle(
              color: effectiveEnabled ? global.labelColor : global.labelColor.withOpacity(0.4),
              fontSize: 12,
            ),
          ),
          secondary: _isProcessing 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(
                widget.isLocked ? Icons.lock_person : Icons.lock_open_rounded,
                color: widget.isLocked ? Colors.redAccent : Colors.greenAccent,
              ),
          value: widget.isLocked,
          activeTrackColor: Colors.redAccent.withOpacity(0.5),
          activeThumbColor: Colors.redAccent,
          onChanged: effectiveEnabled
              ? (v) => _toggleLock(v)
              : (v) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Access Denied: Caller does not have permission to perform this action."),
                      backgroundColor: global.errorColor,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
        ),
      ),
    );
  }
}
