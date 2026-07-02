import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/screens/quiz/quiz_filter_screen.dart';
import 'package:thinkfast/utils/global.dart' as global;
import 'package:thinkfast/widgets/drawer_data.dart';
import 'package:thinkfast/widgets/quiz_widgets.dart';

class MainScreen extends StatefulWidget {
  final User? creator;
  final bool showMyQuizzes;
  final bool showManagedQuizzes;
  final bool showTrash;

  const MainScreen({
    super.key,
    this.creator,
    this.showMyQuizzes = false,
    this.showManagedQuizzes = false,
    this.showTrash = false,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  User? _user;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // Selection Logic
  final Set<String> _selectedQuizIds = {};
  bool _isSelectionMode = false;

  // Filter Logic
  final Set<String> _selectedTags = {};
  final Set<String> _selectedSubjects = {}; // Added subject selection
  bool _isStrictFilter = false;

  @override
  void initState() {
    super.initState();
    _auth.authStateChanges().listen((u) async {
      if (mounted) {
        setState(() => _user = u);
        if (u != null && global.currentUserProfile == null) {
          await global.db.initAppData(u.uid);
          if (mounted) setState(() {}); // Refresh with new global data
        }
      }
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedQuizIds.contains(id)) {
        _selectedQuizIds.remove(id);
        if (_selectedQuizIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedQuizIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _handleBulkAction() async {
    if (_selectedQuizIds.isEmpty) return;

    final String title = widget.showTrash
        ? "Restore Selected?"
        : "Delete Selected?";
    final String content = widget.showTrash
        ? "These quizzes will be moved back to your active list."
        : "These quizzes will be moved to the Recycle Bin.";

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: global.cardColor,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(content, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.showTrash
                  ? global.successColor
                  : global.errorColor,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              widget.showTrash ? "RESTORE" : "DELETE",
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        for (String id in _selectedQuizIds) {
          if (widget.showTrash) {
            await global.qDb.restoreDatabase(docId: id, currentUserId: _user!.uid);
          } else {
            await global.qDb.deleteDatabase(docId: id, currentUserId: _user!.uid);
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${_selectedQuizIds.length} quizzes processed"),
            ),
          );
          setState(() {
            _selectedQuizIds.clear();
            _isSelectionMode = false;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Bulk Error: $e")));
        }
      }
    }
  }

  /// 🔥 READ QUIZZES
  Stream<List<Map<String, dynamic>>> readDatabases() {
    return global.db.readAllDatabases(
      showMyQuizzes: widget.showMyQuizzes,
      showManagedQuizzes: widget.showManagedQuizzes,
      showTrash: widget.showTrash,
      creatorId: widget.creator?.uid,
      userId: _user?.uid,
    );
  }

  void _shareQuiz(String quizId) {
    final String shareUrl = "https://thinkfast3834.web.app/quiz?id=$quizId";
    Clipboard.setData(ClipboardData(text: shareUrl)).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Link copied to clipboard: $shareUrl"),
            backgroundColor: global.primaryAccent,
          ),
        );
      }
    });
  }

  /// 🧩 QUIZ CARD (Minimized)
  Widget buildQuizCard(Map<String, dynamic> data) {
    final bool isSelected = _selectedQuizIds.contains(data['id']);
    final bool canSelect = widget.showMyQuizzes || widget.showTrash;

    return InkWell(
      onLongPress: canSelect ? () => _toggleSelection(data['id']) : null,
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(data['id']);
        } else if (widget.showTrash) {
          _showRestoreDialog(data);
        } else {
          Navigator.pushNamed(context, "/Quiz Details", arguments: data['id']);
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        elevation: 0,
        color: isSelected
            ? global.primaryAccent.withValues(alpha: 0.15)
            : global.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? global.primaryAccent : global.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? global.primaryAccent
                        : global.labelColor,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title'] ?? 'Untitled',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: global.valueColor,
                      ),
                    ),
                    if (data['examTag'] != null && data['examTag'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          "Exam: ${data['examTag']}",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: global.primaryAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    if (widget.showTrash)
                      _buildTrashSubtitle(data)
                    else
                      Text(
                        "Created by: ${data['user'] ?? 'Anonymous'}",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: global.labelColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    // Show Module Subjects and Tags
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        // Module Subjects
                        ...(data['modules'] as List? ?? []).map((m) {
                          final sub = m is Map ? m['subject'].toString() : "";
                          if (sub.isEmpty) return const SizedBox.shrink();
                          return _buildMetaChip(sub, isSubject: true);
                        }),
                        // Module Tags
                        if (data['moduleTags'] != null)
                          ...(data['moduleTags'] as Map).values.expand((tags) => tags as List).take(3).map((t) {
                            return _buildMetaChip(t.toString(), isModuleTag: true);
                          }),
                        // Regular Tags
                        ...(data['tags'] as List? ?? []).take(5).map((t) {
                          return _buildMetaChip(t.toString());
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              if (!widget.showTrash && !_isSelectionMode)
                IconButton(
                  icon: const Icon(
                    Icons.share_rounded,
                    color: global.primaryAccent,
                    size: 20,
                  ),
                  onPressed: () => _shareQuiz(data['id']),
                  tooltip: "Share Quiz Link",
                ),
              if (!_isSelectionMode)
                Icon(
                  widget.showTrash
                      ? Icons.restore_from_trash_rounded
                      : Icons.arrow_forward_ios_rounded,
                  color: widget.showTrash
                      ? global.successColor
                      : global.borderColor,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip(String text, {bool isSubject = false, bool isModuleTag = false}) {
    Color chipColor = global.primaryAccent;
    if (isSubject) chipColor = global.infoColor;
    if (isModuleTag) chipColor = global.successColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: chipColor.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: chipColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTrashSubtitle(Map<String, dynamic> data) {
    final Timestamp? deletedAt = data['deletedAt'];
    if (deletedAt == null) return const SizedBox.shrink();

    final DateTime expiry = deletedAt.toDate().add(const Duration(days: 7));
    final Duration timeLeft = expiry.difference(DateTime.now());
    final int daysLeft = timeLeft.inDays;

    return Text(
      daysLeft > 0 ? "Expires in: $daysLeft days" : "Expires today",
      style: GoogleFonts.poppins(
        fontSize: 12,
        color: global.errorColor,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  void _showRestoreDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: global.cardColor,
        title: Text(
          "Restore Quiz?",
          style: GoogleFonts.poppins(color: global.valueColor),
        ),
        content: Text(
          "Do you want to restore '${data['title']}'? It will be visible to participants again.",
          style: const TextStyle(color: global.labelColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: global.successColor,
            ),
            onPressed: () async {
              try {
                await global.qDb.restoreDatabase(
                  docId: data['id'],
                  currentUserId: _user!.uid,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Quiz restored successfully")),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Restore error: $e")));
              }
            },
            child: const Text("RESTORE", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizList(List<Map<String, dynamic>> allQuizzes) {
    final filteredQuizzes = allQuizzes.where((quiz) {
      final title = (quiz['title'] ?? "").toString().toLowerCase();
      final matchesSearch = title.contains(_searchQuery);

      if (_selectedTags.isEmpty && _selectedSubjects.isEmpty) return matchesSearch;

      final quizTags = List<String>.from(quiz['tags'] ?? []);
      final quizSubjects = (quiz['modules'] as List? ?? [])
          .map((m) => m is Map ? m['subject'].toString() : "")
          .toSet();
      
      // Include examTag in quizSubjects for easier filtering
      if (quiz['examTag'] != null && quiz['examTag'].toString().isNotEmpty) {
        quizSubjects.add(quiz['examTag'].toString());
      }

      bool matchesTags = true;
      bool matchesSubjects = true;

      if (_isStrictFilter) {
        // Strict: Quiz tags/subjects must be a SUBSET of selected filters
        // i.e., it should only contain selected tags and nothing else.
        if (_selectedTags.isNotEmpty) {
          matchesTags = quizTags.isNotEmpty && quizTags.every((tag) => _selectedTags.contains(tag));
        }
        if (_selectedSubjects.isNotEmpty) {
          matchesSubjects = quizSubjects.isNotEmpty && quizSubjects.every((sub) => _selectedSubjects.contains(sub));
        }
      } else {
        // Non-strict: Must match AT LEAST ONE selected item (union across categories)
        final bool hasSelectedTags = _selectedTags.isNotEmpty;
        final bool hasSelectedSubjects = _selectedSubjects.isNotEmpty;

        bool tagMatch = hasSelectedTags && _selectedTags.any((tag) => quizTags.contains(tag));
        bool subjectMatch = hasSelectedSubjects && _selectedSubjects.any((sub) => quizSubjects.contains(sub));

        if (hasSelectedTags && hasSelectedSubjects) {
          return matchesSearch && (tagMatch || subjectMatch);
        } else if (hasSelectedTags) {
          return matchesSearch && tagMatch;
        } else if (hasSelectedSubjects) {
          return matchesSearch && subjectMatch;
        }
      }

      return matchesSearch && matchesTags && matchesSubjects;
    }).toList();

    if (filteredQuizzes.isEmpty) {
      return const Center(
        child: Text(
          "No matching quizzes found",
          style: TextStyle(color: global.labelColor),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).padding.bottom + 100,
      ),
      itemCount: filteredQuizzes.length,
      itemBuilder: (context, index) {
        return buildQuizCard(filteredQuizzes[index]);
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedQuizIds.clear();
                }),
              )
            : null,
        title: _isSelectionMode
            ? Text(
                "${_selectedQuizIds.length} Selected",
                style: const TextStyle(color: Colors.white),
              )
            : (_isSearching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: GoogleFonts.poppins(color: global.valueColor),
                      decoration: InputDecoration(
                        hintText: "Search quizzes...",
                        hintStyle: GoogleFonts.poppins(
                          color: global.labelColor,
                        ),
                        border: InputBorder.none,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
                    )
                  : Text(
                      widget.showTrash
                          ? "RECYCLE BIN"
                          : (widget.showMyQuizzes
                                ? "MY QUIZZES"
                                : (widget.showManagedQuizzes
                                      ? "MANAGED QUIZZES"
                                      : "THINKFAST")),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: global.valueColor,
                        letterSpacing: 1.5,
                      ),
                    )),
        iconTheme: const IconThemeData(color: global.valueColor),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: Icon(
                    widget.showTrash
                        ? Icons.restore_rounded
                        : Icons.delete_sweep_rounded,
                    color: widget.showTrash
                        ? global.successColor
                        : global.errorColor,
                  ),
                  onPressed: _handleBulkAction,
                ),
              ]
            : [
                if (global.isAdmin) const AdminBadge(),
                IconButton(
                  icon: Icon(_isSearching ? Icons.close : Icons.search),
                  onPressed: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) {
                        _searchQuery = "";
                        _searchController.clear();
                      }
                    });
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.filter_list,
                    color: (_selectedTags.isNotEmpty || _selectedSubjects.isNotEmpty)
                        ? global.primaryAccent
                        : global.valueColor,
                  ),
                  onPressed: () async {
                    final List<Map<String, dynamic>> allQuizzes = await readDatabases().first;
                    if (!mounted) return;
                    
                    final result = await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuizFilterScreen(
                          initialTags: _selectedTags,
                          initialSubjects: _selectedSubjects,
                          initialStrict: _isStrictFilter,
                          allQuizzes: allQuizzes,
                        ),
                      ),
                    );

                    if (result != null) {
                      setState(() {
                        _selectedTags.clear();
                        _selectedTags.addAll(result['tags']);
                        _selectedSubjects.clear();
                        _selectedSubjects.addAll(result['subjects']);
                        _isStrictFilter = result['isStrict'];
                      });
                    }
                  },
                  tooltip: "Filters",
                ),
              ],
      ),
      drawer: _isSelectionMode
          ? null
          : Drawer(
              backgroundColor: global.cardColor,
              child: SidebarMenu(user: _user),
            ),
      body: Container(
        color: global.bgColor,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: readDatabases(),
          builder: (context, snapshot) {
            final allQuizzes = snapshot.data ?? [];
            return Column(
              children: [
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(
                          child: CircularProgressIndicator(color: global.primaryAccent),
                        )
                      : allQuizzes.isEmpty
                          ? const Center(
                              child: Text(
                                "No quizzes available",
                                style: TextStyle(color: global.labelColor),
                              ),
                            )
                          : _buildQuizList(allQuizzes),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton:
          global.featureFlags?['enable_ai'] == true && !_isSelectionMode
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pushNamed(context, '/AI Quiz Generator'),
              backgroundColor: global.btnColor,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text("AI WIZARD"),
            )
          : null,
    );
  }
}
