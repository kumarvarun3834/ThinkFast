import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
                    if (data['tags'] != null && (data['tags'] as List).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 0,
                        children: (data['tags'] as List).take(3).map((t) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: global.primaryAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: global.primaryAccent.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              t.toString(),
                              style: const TextStyle(
                                color: global.primaryAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
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

  Widget _buildTagFilterBar() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tags')
          .orderBy('lastUsed', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final tags = snapshot.data!.docs.where((doc) {
          final List quizIds = (doc.data() as Map)['quizIds'] as List? ?? [];
          return quizIds.isNotEmpty; // Hide empty tags
        }).toList();

        if (tags.isEmpty) return const SizedBox.shrink();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Text(
                    "FILTER BY TAGS",
                    style: GoogleFonts.poppins(
                      color: global.labelColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "STRICT",
                    style: GoogleFonts.poppins(
                      color: _isStrictFilter
                          ? global.primaryAccent
                          : global.labelColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    height: 24,
                    child: Switch(
                      value: _isStrictFilter,
                      activeThumbColor: global.primaryAccent,
                      onChanged: (v) => setState(() => _isStrictFilter = v),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 50,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: tags.length,
                itemBuilder: (context, index) {
                  final tag = tags[index].id;
                  final isSelected = _selectedTags.contains(tag);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(
                        tag,
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
                          color: isSelected
                              ? global.primaryAccent
                              : global.borderColor,
                        ),
                      ),
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _selectedTags.add(tag);
                          } else {
                            _selectedTags.remove(tag);
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            if (_selectedTags.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: TextButton(
                    onPressed: () => setState(() => _selectedTags.clear()),
                    child: const Text(
                      "Clear Filters",
                      style: TextStyle(color: global.errorColor, fontSize: 12),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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
        child: Column(
          children: [
            if (!_isSelectionMode) _buildTagFilterBar(),
            Expanded(
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
                    final matchesSearch = title.contains(_searchQuery);
                    
                    if (_selectedTags.isEmpty) return matchesSearch;

                    final quizTags = List<String>.from(quiz['tags'] ?? []);
                    bool matchesTags;
                    if (_isStrictFilter) {
                      // Strict: Quiz must have ALL selected tags
                      matchesTags = _selectedTags.every((tag) => quizTags.contains(tag));
                    } else {
                      // Non-strict: Quiz must have AT LEAST ONE selected tag
                      matchesTags = _selectedTags.any((tag) => quizTags.contains(tag));
                    }

                    return matchesSearch && matchesTags;
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
          ],
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
