import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ai_service.dart';
import '../services/firebase_direct_commands.dart';
import '../widgets/drawer_data.dart';
import '../widgets/quiz_widgets.dart';

import '../services/quiz_data_processor.dart';
import '../utils/global.dart' as global;

class Main_Screen extends StatefulWidget {
  final User? creator;
  final bool showMyQuizzes;
  final bool showManagedQuizzes;
  final bool showTrash;

  const Main_Screen({
    super.key,
    this.creator,
    this.showMyQuizzes = false,
    this.showManagedQuizzes = false,
    this.showTrash = false,
  });

  @override
  State<Main_Screen> createState() => _Main_ScreenState();
}

class _Main_ScreenState extends State<Main_Screen> {
  User? _user;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // Selection Logic
  final Set<String> _selectedQuizIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _auth.authStateChanges().listen((u) async {
      if (mounted) {
        setState(() => _user = u);
        if (u != null && global.currentUserProfile == null) {
          await DatabaseService().initAppData(u.uid);
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
      final db = DatabaseService();
      try {
        for (String id in _selectedQuizIds) {
          if (widget.showTrash) {
            await db.restoreDatabase(docId: id, currentUserId: _user!.uid);
          } else {
            await db.deleteDatabase(docId: id, currentUserId: _user!.uid);
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
    return DatabaseService().readAllDatabases(
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
            ? global.primaryAccent.withOpacity(0.15)
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
                await DatabaseService().restoreDatabase(
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

  /// 🧱 BUILD
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
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: global.primaryAccent),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  "No quizzes available",
                  style: TextStyle(color: global.labelColor),
                ),
              );
            }

            final filteredQuizzes = snapshot.data!.where((quiz) {
              final title = (quiz['title'] ?? "").toString().toLowerCase();
              return title.contains(_searchQuery);
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
