import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/admin_service.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';
import 'package:thinkfast/utils/global.dart' as global;
import 'package:thinkfast/widgets/quiz_widgets.dart';

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

  Future<bool?> _showBypassDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: global.cardColor,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(content, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: global.primaryAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("BYPASS"),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final title = _quizData?['title'] ?? 'Loading Quiz...';
    final description = _quizData?['description'] ?? 'Please wait while we fetch the details.';
    final timeLimit = _quizData != null ? "${(_quizData!['time'] ?? 0) ~/ 60} Minutes" : "--";
    final totalQuestions = _quizData != null ? _calculateTotalQuestions().toString() : "--";
    final creator = _creatorProfile?['name'] ?? _creatorProfile?['email'] ?? (_isLoading ? "Loading..." : "Unknown");

    return Scaffold(
      backgroundColor: global.bgColor,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: global.valueColor,
          ),
        ),
        iconTheme: const IconThemeData(color: global.valueColor),
        actions: [if (_isAdmin) const AdminBadge()],
      ),
      body: _isLoading && _quizData == null
          ? const Center(
              child: CircularProgressIndicator(color: global.primaryAccent),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      VisibilityBadge(
                        visibility: _quizData?['visibility'] ?? 'private',
                        isLocked: _quizData?['isLocked'] ?? false,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _quizData == null ? null : () {
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
                              border: Border.all(color: global.borderColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.link_rounded,
                                  size: 18,
                                  color: global.primaryAccent,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _quizData == null ? "thinkfast.app/quiz?id=..." : "thinkfast3834.web.app/quiz?id=${_quizData!['id']}",
                                    style: GoogleFonts.poppins(
                                      color: global.labelColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.copy_all_rounded,
                                  size: 16,
                                  color: global.labelColor,
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
                      color: global.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: global.borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InfoRow(label: "Description", value: description),
                        const Divider(color: global.borderColor, height: 32),
                        InfoRow(
                          label: "Duration",
                          value: timeLimit,
                          icon: Icons.timer_outlined,
                        ),
                        InfoRow(
                          label: "Total Questions",
                          value: totalQuestions,
                          icon: Icons.quiz_outlined,
                        ),
                        InfoRow(
                          label: "Created By",
                          value: creator,
                          icon: Icons.person_outline,
                        ),
                        if (_quizData != null && _quizData!['activeAt'] != null)
                          InfoRow(
                            label: "Scheduled For",
                            value: "${(_quizData!['activeAt'] as Timestamp).toDate().day}/${(_quizData!['activeAt'] as Timestamp).toDate().month} ${(_quizData!['activeAt'] as Timestamp).toDate().hour}:${(_quizData!['activeAt'] as Timestamp).toDate().minute.toString().padLeft(2, '0')}",
                            icon: Icons.calendar_today_outlined,
                          ),
                        if (_quizData != null && _quizData!['isRestricted'] == true)
                          InfoRow(
                            label: "Access",
                            value: "Restricted (Allowed List Only)",
                            icon: Icons.lock_person_outlined,
                          ),
                        if (_quizData != null && _quizData!['category'] != null)
                          InfoRow(
                            label: "Category",
                            value: _quizData!['category'].toString(),
                            icon: Icons.category_outlined,
                          ),
                        if (_quizData != null && _quizData!['difficulty'] != null)
                          InfoRow(
                            label: "Difficulty",
                            value: _quizData!['difficulty'].toString(),
                            icon: Icons.speed,
                          ),
                        if (_quizData != null && _quizData!['marks'] != null)
                          InfoRow(
                            label: "Marks",
                            value: _quizData!['marks'].toString(),
                            icon: Icons.star_outline,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (!_isLoading || _quizData != null)
                    _buildActionButtons(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  int _calculateTotalQuestions() {
    if (_quizData == null) return 0;
    final List<dynamic> rawModules = _quizData!['modules'] as List? ?? [];
    return rawModules.fold<int>(0, (sum, module) {
      final List<dynamic> questions = module['data'] as List? ?? [];
      return sum + questions.length;
    });
  }

  Widget _buildActionButtons() {
    final bool isOwner = _user != null && _quizData!['creatorId'] == _user!.uid;
    final bool canManage = _canManage;

    return Column(
      children: [
        QuizActionButton(
          text: "Start Quiz",
          onPressed: () async {
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

            // Scheduling Check
            if (_quizData!['activeAt'] != null) {
              final DateTime activeAt = (_quizData!['activeAt'] as Timestamp).toDate();
              if (DateTime.now().isBefore(activeAt)) {
                if (global.isAdmin) {
                  final bool? bypass = await _showBypassDialog("Early Access", "This quiz is scheduled for later. Bypass and start now?");
                  if (bypass != true) return;
                } else {
                  final String formatted = "${activeAt.day}/${activeAt.month} ${activeAt.hour}:${activeAt.minute.toString().padLeft(2, '0')}";
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('This quiz is scheduled to start at $formatted'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
              }
            }

            // Restriction Check
            if (_quizData!['isRestricted'] == true) {
              final List<dynamic> allowed = _quizData!['allowedParticipants'] as List? ?? [];
              if (!allowed.contains(_user?.uid)) {
                if (global.isAdmin) {
                  final bool? bypass = await _showBypassDialog("Restricted Quiz", "You are not in the allowed list. Bypass restriction?");
                  if (bypass != true) return;
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Access Denied: You are not in the allowed participants list for this quiz.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }
              }
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

            // Ban Check
            final bool isBanned = await db.isUserBanned(_user!.uid, quizId: _quizData!['id']);
            if (isBanned) {
              if (global.isAdmin) {
                final bool? bypass = await _showBypassDialog("Banned from Quiz", "You are currently banned from this quiz. As an administrator in Admin Mode, would you like to bypass this restriction?");
                if (bypass != true) return;
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Access Denied: You have been blocked from this quiz."),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
                return;
              }
            }

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

            if (_quizData!['visibility'] == 'public' || canManage) {
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
          QuizActionButton(
            text: _quizData!['visibility'] == 'public'
                ? "Make Private"
                : "Make Public",
            onPressed: _toggleVisibility,
            icon: _quizData!['visibility'] == 'public'
                ? Icons.lock_outline
                : Icons.public_outlined,
          ),
          const SizedBox(height: 16),
          QuizActionButton(
            text: _quizData!['isLocked'] == true
                ? "Unlock Quiz"
                : "Lock Quiz",
            onPressed: _toggleLock,
            icon: _quizData!['isLocked'] == true
                ? Icons.lock_open_rounded
                : Icons.lock_person_rounded,
          ),
          const SizedBox(height: 16),
          QuizActionButton(
            text: "View Responses",
            onPressed: () {
              Navigator.pushNamed(
                context,
                "/Quiz Responses",
                arguments: {
                  'quizId': _quizData!['id'],
                  'quizTitle': _quizData!['title'] ?? 'Quiz',
                },
              );
            },
            icon: Icons.analytics_outlined,
          ),
          const SizedBox(height: 16),
          QuizActionButton(
            text: "Manage Collaborators",
            onPressed: () {
              Navigator.pushNamed(
                context,
                "/Manage Collaborators",
                arguments: _quizData!['id'],
              );
            },
            icon: Icons.people_outline,
          ),
          const SizedBox(height: 16),
          QuizActionButton(
            text: "Update Quiz",
            onPressed: () {
              final List<Map<String, Object>> flattenedQuestions = [];
              final List<dynamic> rawModules =
                  _quizData!['modules'] as List? ?? [];

              for (var module in rawModules) {
                final String subject = module['subject'].toString();
                final List<dynamic> questions =
                    module['data'] as List? ?? [];
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
            },
            icon: Icons.edit_outlined,
          ),
          const SizedBox(height: 16),
          QuizActionButton(
            text: "Delete Quiz",
            onPressed: () async {
              try {
                await DatabaseService().deleteDatabase(
                  docId: _quizData!['id'],
                  currentUserId: _user!.uid,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Quiz moved to trash (Soft Delete)")),
                  );
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Delete Error: $e"),
                    ),
                  );
                }
              }
            },
            icon: Icons.delete_outline,
          ),
        ],
      ],
    );
  }
}
