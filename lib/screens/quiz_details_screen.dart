import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/admin_service.dart';
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
  bool _isAdmin = false;
  bool _canManage = false;
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
      final data = await db.readDatabase(widget.quizId, userId: _user?.uid);

      // Fetch profiles but don't let failure here stop the process
      Map<String, dynamic>? creatorProfile;
      if (data['creatorId'] != null) {
        creatorProfile = await db.getUserProfile(data['creatorId']);
      }

      Map<String, dynamic>? userProfile;
      String? activeQuizId;
      Timestamp? activeQuizExpiry;
      bool hasAttempted = false;
      bool isAdmin = false;

      if (_user != null) {
        userProfile = await db.getUserProfile(_user!.uid);
        activeQuizId = userProfile?['activeQuizId'];
        activeQuizExpiry = userProfile?['activeQuizExpiry'];
        hasAttempted = await db.hasUserAttemptedQuiz(_user!.uid, widget.quizId);

        // Use AdminService to check status
        isAdmin = await AdminService().isAdmin(_user!.uid);
        _canManage = await AdminService().canManageQuiz(
          widget.quizId,
          _user!.uid,
        );
      }

      setState(() {
        _quizData = data;
        _creatorProfile = creatorProfile;
        _userProfile = userProfile;
        _isAdmin = isAdmin;
        _canManage = _canManage;
        _quizData!['activeQuizId'] = activeQuizId;
        _quizData!['activeQuizExpiry'] = activeQuizExpiry;
        _quizData!['hasAttempted'] = hasAttempted;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        // If it's a permission error, it's likely a private quiz
        String errorMsg = e.toString().contains("permission")
            ? "Access Denied: This quiz is private."
            : "Error: $e";

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMsg)));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _toggleVisibility() async {
    if (_quizData == null || _user == null) return;

    final currentVisibility = _quizData!['visibility'] ?? 'private';
    final newVisibility = currentVisibility == 'public' ? 'private' : 'public';

    try {
      await DatabaseService().updateDatabase(
        docId: _quizData!['id'],
        currentUserId: _user!.uid,
        visibility: newVisibility,
      );

      setState(() {
        _quizData!['visibility'] = newVisibility;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Quiz is now $newVisibility")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _toggleLock() async {
    if (_quizData == null || _user == null) return;

    final bool currentLocked = _quizData!['isLocked'] ?? false;
    final bool newLocked = !currentLocked;

    try {
      await DatabaseService().toggleQuizLock(
        docId: _quizData!['id'],
        currentUserId: _user!.uid,
        isLocked: newLocked,
      );

      setState(() {
        _quizData!['isLocked'] = newLocked;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newLocked ? "Quiz Locked" : "Quiz Unlocked")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
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

  Widget _buildVisibilityBadge(String visibility, bool isLocked) {
    Color color;
    if (isLocked) {
      color = Colors.redAccent;
    } else {
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

  Widget _actionButton(
    String text,
    VoidCallback onPressed, {
    bool isPrimary = false,
    IconData? icon,
    VoidCallback? onDoubleTap,
  }) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: ElevatedButton(
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
    final bool canManage = _canManage;
    final bool isPublic = _quizData!['visibility'] == 'public';

    final title = _quizData!['title'] ?? 'Untitled Quiz';
    final description = _quizData!['description'] ?? 'No description provided';
    final timeLimit = "${(_quizData!['time'] ?? 0) ~/ 60} Minutes";

    // Calculate total questions from modules
    final List<dynamic> rawModules = _quizData!['modules'] as List? ?? [];
    final int count = rawModules.fold<int>(0, (sum, module) {
      final List<dynamic> questions = module['data'] as List? ?? [];
      return sum + questions.length;
    });
    final totalQuestions = count.toString();

    final creator =
        _creatorProfile?['name'] ?? _creatorProfile?['email'] ?? 'Unknown';

    return Scaffold(
      backgroundColor: _bgColor,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: _valueColor,
          ),
        ),
        iconTheme: IconThemeData(color: _valueColor),
        actions: [
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    "ADMIN",
                    style: GoogleFonts.poppins(
                      color: Colors.redAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildVisibilityBadge(
                  _quizData!['visibility'] ?? 'private',
                  _quizData!['isLocked'] ?? false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      final link =
                          "https://thinkfast3834.web.app/quiz?id=${_quizData!['id']}";
                      Clipboard.setData(ClipboardData(text: link)).then((_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Quiz link copied!")),
                          );
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.link_rounded,
                            size: 18,
                            color: _primaryAccent,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "thinkfast3834.web.app/quiz?id=${_quizData!['id']}",
                              style: GoogleFonts.poppins(
                                color: _labelColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.copy_all_rounded,
                            size: 16,
                            color: _labelColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
              () async {
                final db = DatabaseService();
                final String? activeQuizId = _quizData!['activeQuizId'];
                final Timestamp? activeQuizExpiry =
                    _quizData!['activeQuizExpiry'];

                if (activeQuizId != null) {
                  bool isExpired = false;
                  if (activeQuizExpiry != null) {
                    isExpired = activeQuizExpiry.toDate().isBefore(
                      DateTime.now(),
                    );
                  }

                  if (isExpired) {
                    // Auto-submit blank and clean up
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Cleaning up previous expired session...',
                        ),
                      ),
                    );
                    await db.handleExpiredQuiz(_user!.uid, activeQuizId);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'You are already taking another quiz ($activeQuizId). Finish it first! (Double tap to instant submit previous)',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                }

                if (_quizData!['isLocked'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'This quiz is locked and not accepting new responses',
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                final bool allowMultiple =
                    _quizData!['allowMultipleAttempts'] ?? true;
                final bool hasAttempted = _quizData!['hasAttempted'] ?? false;

                if (!allowMultiple && hasAttempted && !isOwner) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'You have already attempted this quiz. Multiple attempts are disabled.',
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                if (_user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please Login to Continue')),
                  );
                  Navigator.pushNamed(context, '/login');
                  return;
                }

                // Refresh user state to check verification
                await _user!.reload();
                _user = _auth.currentUser;

                if (!_user!.emailVerified) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please verify your email to start the quiz',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  Navigator.pushNamed(context, '/verify');
                  return;
                }

                if (isPublic || canManage) {
                  final List<Map<String, Object>> flattenedQuestions = [];
                  final List<dynamic> rawModules =
                      _quizData!['modules'] as List? ?? [];

                  for (var module in rawModules) {
                    final String subject = module['subject'].toString();
                    final List<dynamic> questions =
                        module['data'] as List? ?? [];
                    for (var q in questions) {
                      final qMap = Map<String, Object>.from(q);
                      qMap['subject'] =
                          subject; // Re-inject for flat processing in Questions screen
                      flattenedQuestions.add(qMap);
                    }
                  }

                  global.quizData = flattenedQuestions;

                  global.ID = _quizData!['id'];
                  global.time = _quizData!['time'] as int;
                  global.perQuestionTime = _quizData!['perQuestionTime'] ?? 0;
                  global.completeRandomShuffle =
                      _quizData!['completeRandomShuffle'] ?? false;
                  global.markingScheme =
                      _quizData!['markingScheme'] ?? {"type": "default"};
                  global.attemptLimits =
                      _quizData!['attemptLimits'] ?? {"type": "none"};
                  global.currentUserProfile = _userProfile;
                  global.creatorProfile = _creatorProfile;

                  // Mark as active quiz with expiry (Duration + 5 mins buffer)
                  final int quizDurationSeconds = _quizData!['time'] as int;
                  final DateTime expiry = DateTime.now().add(
                    Duration(seconds: quizDurationSeconds + 300),
                  );

                  await db.updateActiveQuiz(
                    uid: _user!.uid,
                    quizId: _quizData!['id'],
                    expiry: expiry,
                  );

                  Navigator.pushNamed(context, "/Quiz");
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("This quiz is private")),
                  );
                }
              },
              isPrimary: true,
              icon: Icons.play_arrow_rounded,
              onDoubleTap: () async {
                final db = DatabaseService();
                final String? activeQuizId = _quizData!['activeQuizId'];

                if (activeQuizId != null && _user != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Instant submitting previous session...'),
                    ),
                  );
                  await db.handleExpiredQuiz(_user!.uid, activeQuizId);

                  // Update UI state to reflect cleared active quiz
                  setState(() {
                    _quizData!['activeQuizId'] = null;
                    _quizData!['activeQuizExpiry'] = null;
                  });
                }
              },
            ),
            if (canManage) ...[
              const SizedBox(height: 16),
              _actionButton(
                _quizData!['visibility'] == 'public'
                    ? "Make Private"
                    : "Make Public",
                _toggleVisibility,
                icon: _quizData!['visibility'] == 'public'
                    ? Icons.lock_outline
                    : Icons.public_outlined,
              ),
              const SizedBox(height: 16),
              _actionButton(
                _quizData!['isLocked'] == true ? "Unlock Quiz" : "Lock Quiz",
                _toggleLock,
                icon: _quizData!['isLocked'] == true
                    ? Icons.lock_open_rounded
                    : Icons.lock_person_rounded,
              ),
              const SizedBox(height: 16),
              _actionButton("View Responses", () {
                Navigator.pushNamed(
                  context,
                  "/Quiz Responses",
                  arguments: {
                    'quizId': _quizData!['id'],
                    'quizTitle': _quizData!['title'] ?? 'Quiz',
                  },
                );
              }, icon: Icons.analytics_outlined),
              const SizedBox(height: 16),
              _actionButton("Manage Collaborators", () {
                Navigator.pushNamed(
                  context,
                  "/Manage Collaborators",
                  arguments: _quizData!['id'],
                );
              }, icon: Icons.people_outline),
              const SizedBox(height: 16),
              _actionButton("Update Quiz", () {
                final List<Map<String, Object>> flattenedQuestions = [];
                final List<dynamic> rawModules =
                    _quizData!['modules'] as List? ?? [];

                for (var module in rawModules) {
                  final String subject = module['subject'].toString();
                  final List<dynamic> questions = module['data'] as List? ?? [];
                  for (var q in questions) {
                    final qMap = Map<String, Object>.from(q);
                    qMap['subject'] = subject;
                    flattenedQuestions.add(qMap);
                  }
                }

                global.quizData = flattenedQuestions;

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
