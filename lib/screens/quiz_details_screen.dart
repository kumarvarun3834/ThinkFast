import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';
import 'package:thinkfast/utils/global.dart' as global;

class QuizDetailsScreen extends StatefulWidget {
  final String quizId;

  const QuizDetailsScreen({super.key, required this.quizId});

  @override
  State<QuizDetailsScreen> createState() => _QuizDetailsScreenState();
}

class _QuizDetailsScreenState extends State<QuizDetailsScreen> {
  User? _user;
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _creatorProfile;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _quizData;

  // Colors (Fixed Palette)
  final Color _bgColor = const Color(0xFF0F172A);
  final Color _cardColor = const Color(0xFF1E293B);
  final Color _primaryAccent = const Color(0xFF3B82F6);
  final Color _labelColor = const Color(0xFF94A3B8);
  final Color _valueColor = const Color(0xFFE2E8F0);
  final Color _btnColor = const Color(0xFF2563EB);
  final Color _borderColor = const Color(0xFF334155);
  final Color _dividerColor = const Color(0xFF334155);

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _fetchQuizDetails();
  }

  Future<void> _fetchQuizDetails() async {
    try {
      final db = DatabaseService();
      final data = await db.readDatabase(widget.quizId);

      Map<String, dynamic>? creatorProfile;
      if (data['creatorId'] != null) {
        creatorProfile = await db.getUserProfile(data['creatorId']);
      }

      Map<String, dynamic>? userProfile;
      if (_user != null) {
        userProfile = await db.getUserProfile(_user!.uid);
      }

      setState(() {
        _quizData = data;
        _creatorProfile = creatorProfile;
        _userProfile = userProfile;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error fetching details: $e")));
        Navigator.pop(context);
      }
    }
  }

  Widget _buildInfoRow(String label, String value, {IconData? icon}) {
    if (value.isEmpty || value == 'null') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.poppins(
              color: _labelColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: _primaryAccent),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: _valueColor,
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

  Widget _buildVisibilityBadge(String visibility) {
    Color color;
    switch (visibility.toLowerCase()) {
      case 'public':
        color = Colors.greenAccent;
        break;
      case 'private':
        color = Colors.orangeAccent;
        break;
      default:
        color = Colors.blueGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
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
            visibility.toUpperCase(),
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

  Widget _actionButton(
    String text,
    VoidCallback onPressed, {
    bool isPrimary = false,
    IconData? icon,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary
            ? _btnColor
            : Colors.white.withValues(alpha: 0.05),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isPrimary ? BorderSide.none : BorderSide(color: _borderColor),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _bgColor,
        body: Center(child: CircularProgressIndicator(color: _primaryAccent)),
      );
    }

    if (_quizData == null) {
      return Scaffold(
        backgroundColor: _bgColor,
        body: Center(
          child: Text(
            "No quiz found",
            style: GoogleFonts.poppins(color: _valueColor),
          ),
        ),
      );
    }

    final bool isOwner = _user != null && _quizData!['creatorId'] == _user!.uid;
    final bool isPublic = _quizData!['visibility'] == 'public';

    final title = _quizData!['title'] ?? 'Untitled Quiz';
    final description = _quizData!['description'] ?? 'No description provided';
    final timeLimit = "${_quizData!['time'] ~/ 60} Minutes";
    final totalQuestions =
        (_quizData!['data'] as List?)?.length.toString() ?? '0';
    final creator =
        _creatorProfile?['name'] ?? _creatorProfile?['email'] ?? 'Unknown';

    return Scaffold(
      backgroundColor: _bgColor,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Quiz Details",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: _valueColor,
          ),
        ),
        iconTheme: IconThemeData(color: _valueColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                color: _valueColor,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildVisibilityBadge(_quizData!['visibility'] ?? 'private'),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow("Description", description),
                  Divider(color: _dividerColor, height: 32),
                  _buildInfoRow(
                    "Duration",
                    timeLimit,
                    icon: Icons.timer_outlined,
                  ),
                  _buildInfoRow(
                    "Total Questions",
                    totalQuestions,
                    icon: Icons.quiz_outlined,
                  ),
                  _buildInfoRow(
                    "Created By",
                    creator,
                    icon: Icons.person_outline,
                  ),
                  _buildInfoRow(
                    "Quiz ID",
                    _quizData!['id'],
                    icon: Icons.fingerprint,
                  ),
                  if (_quizData!['category'] != null)
                    _buildInfoRow(
                      "Category",
                      _quizData!['category'].toString(),
                      icon: Icons.category_outlined,
                    ),
                  if (_quizData!['difficulty'] != null)
                    _buildInfoRow(
                      "Difficulty",
                      _quizData!['difficulty'].toString(),
                      icon: Icons.speed,
                    ),
                  if (_quizData!['marks'] != null)
                    _buildInfoRow(
                      "Marks",
                      _quizData!['marks'].toString(),
                      icon: Icons.star_outline,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _actionButton(
              "Start Quiz",
              () {
                if (_user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please Login to Continue')),
                  );
                } else {
                  if (isPublic || isOwner) {
                    global.quizData = (_quizData!['data'] as List<dynamic>)
                        .map((e) => Map<String, Object>.from(e))
                        .toList();

                    global.ID = _quizData!['id'];
                    global.time = _quizData!['time'] as int;
                    global.currentUserProfile = _userProfile;
                    global.creatorProfile = _creatorProfile;

                    Navigator.pushNamed(context, "/Quiz");
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("This quiz is private")),
                    );
                  }
                }
              },
              isPrimary: true,
              icon: Icons.play_arrow_rounded,
            ),
            if (isOwner) ...[
              const SizedBox(height: 16),
              _actionButton("Update Quiz", () {
                global.quizData = (_quizData!['data'] as List<dynamic>)
                    .map((e) => Map<String, Object>.from(e))
                    .toList();

                global.ID = _quizData!['id'];
                global.currentUserProfile = _userProfile;
                global.creatorProfile = _creatorProfile;

                Navigator.pushNamed(context, "/Update Quiz");
              }, icon: Icons.edit_outlined),
              const SizedBox(height: 16),
              _actionButton("Delete Quiz", () async {
                try {
                  await DatabaseService().deleteDatabase(
                    docId: _quizData!['id'],
                    currentUserId: _user!.uid,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Quiz deleted")),
                    );
                    Navigator.pop(context);
                  }
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Only the creator can delete this quiz"),
                      ),
                    );
                  }
                }
              }, icon: Icons.delete_outline),
            ],
          ],
        ),
      ),
    );
  }
}
