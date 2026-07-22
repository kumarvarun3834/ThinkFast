import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/ai_service.dart';
import 'package:thinkfast/utils/global.dart' as global;

class AiGenerationStatusScreen extends StatefulWidget {
  final String? initialQuizId;

  const AiGenerationStatusScreen({super.key, this.initialQuizId});

  @override
  State<AiGenerationStatusScreen> createState() => _AiGenerationStatusScreenState();
}

class _AiGenerationStatusScreenState extends State<AiGenerationStatusScreen> {
  final TextEditingController _idController = TextEditingController();
  final AiService _aiService = AiService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _trackingId;
  bool _isNavigating = false;
  Timer? _pollingTimer;
  Map<String, dynamic>? _apiStatus;
  bool _isPolling = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuizId != null) {
      _trackingId = widget.initialQuizId;
      _idController.text = _trackingId!;
      _startPolling();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _idController.dispose();
    super.dispose();
  }

  void _startTracking() {
    final id = _idController.text.trim();
    if (id.isEmpty) return;
    setState(() {
      _trackingId = id;
    });
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    if (_trackingId == null) return;

    _fetchStatus();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchStatus();
    });
  }

  Future<void> _fetchStatus() async {
    if (_trackingId == null || _isPolling || _isNavigating) return;

    setState(() => _isPolling = true);
    try {
      final statusData = await _aiService.getQuizStatus(_trackingId!);
      if (mounted) {
        setState(() {
          _apiStatus = statusData;
          _isPolling = false;
        });

        if (statusData['status'] == 'completed') {
          _navigateToQuiz();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isPolling = false);
    }
  }

  void _navigateToQuiz() {
    if (_isNavigating) return;
    _isNavigating = true;
    _pollingTimer?.cancel();
    Future.delayed(Duration.zero, () {
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/Quiz Details',
          arguments: _trackingId,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Generation Status",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (_trackingId != null)
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () {
                _pollingTimer?.cancel();
                setState(() {
                  _trackingId = null;
                  _apiStatus = null;
                });
              },
              tooltip: "Track another ID",
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (_trackingId == null) ...[
              _buildIdInput(),
              const SizedBox(height: 32),
              _buildHistorySection(),
              const SizedBox(height: 48),
              _buildJoinExistingQuizPrompt(),
            ] else ...[
              _buildStatusTracker(_trackingId!),
              const SizedBox(height: 32),
              TextButton.icon(
                onPressed: () {
                  _pollingTimer?.cancel();
                  setState(() {
                    _trackingId = null;
                    _apiStatus = null;
                  });
                },
                icon: const Icon(Icons.search_rounded),
                label: const Text("TRACK DIFFERENT ID"),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    final user = _auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_rounded, size: 18, color: global.primaryAccent),
            const SizedBox(width: 8),
            Text(
              "YOUR RECENT GENERATIONS",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: global.primaryAccent,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: global.aiConnect.getAiGenerationHistory(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            }

            final history = snapshot.data ?? [];
            if (history.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: global.cardColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: global.borderColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  "No recent generation requests found.",
                  style: GoogleFonts.poppins(color: global.labelColor, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = history[index];
                final String quizId = item['id'] ?? 'Unknown';
                final String prompt = item['prompt'] ?? 'Custom Quiz';
                final String status = item['status'] ?? 'queued';
                
                return InkWell(
                  onTap: () {
                    _idController.text = quizId;
                    _startTracking();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: global.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: global.borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getStatusIcon(status),
                            size: 20,
                            color: _getStatusColor(status),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prompt,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: global.valueColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "ID: $quizId",
                                style: GoogleFonts.firaCode(
                                  color: global.labelColor,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: global.labelColor),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return global.successColor;
      case 'failed': return global.errorColor;
      case 'generating':
      case 'validating':
      case 'saving': return global.primaryAccent;
      default: return global.labelColor;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return Icons.check_circle_rounded;
      case 'failed': return Icons.error_outline_rounded;
      case 'generating':
      case 'validating':
      case 'saving': return Icons.auto_awesome_rounded;
      default: return Icons.hourglass_empty_rounded;
    }
  }

  Widget _buildIdInput() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: global.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Track AI Generation",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: global.valueColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "If your quiz is taking time or you disconnected, enter the Quiz ID to check its current status.",
            style: GoogleFonts.poppins(color: global.labelColor, fontSize: 13),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _idController,
            style: GoogleFonts.poppins(color: global.valueColor),
            decoration: InputDecoration(
              hintText: "Enter Quiz ID...",
              hintStyle: GoogleFonts.poppins(color: global.hintColor),
              filled: true,
              fillColor: global.bgColor.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: global.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: global.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: global.primaryAccent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startTracking,
              style: ElevatedButton.styleFrom(
                backgroundColor: global.primaryAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("FETCH STATUS", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTracker(String quizId) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: global.aiConnect.listenToGenerationStatus(quizId),
      builder: (context, snapshot) {
        // We use API status as primary if Firestore hasn't caught up yet
        final firestoreData = snapshot.data;
        final data = firestoreData ?? _apiStatus;

        if (data == null) {
          if (snapshot.connectionState == ConnectionState.waiting && !_isPolling) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildErrorState("No active generation found for this ID. It might have expired or doesn't exist.");
        }

        final String status = data['status'] ?? 'Queued';
        final String? error = data['error'];
        final int progress = (data['progress'] ?? 0).toInt();
        final List<dynamic> traces = data['traces'] ?? [];
        final String? prompt = data['prompt'];

        if (status == 'completed' && !_isNavigating) {
          _navigateToQuiz();
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: global.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: status == 'failed' ? global.errorColor : global.primaryAccent.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fingerprint_rounded, size: 12, color: global.labelColor),
                  const SizedBox(width: 4),
                  Text(
                    "TRACKING ID: $quizId",
                    style: GoogleFonts.firaCode(
                      fontSize: 10,
                      color: global.labelColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildStatusIcon(status),
              const SizedBox(height: 24),
              if (prompt != null) ...[
                Text(
                  prompt,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: global.labelColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                status.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: status == 'failed' ? global.errorColor : global.valueColor,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _getStatusMessage(status, error),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: global.labelColor, fontSize: 14),
              ),
              if (status != 'failed' && status != 'completed') ...[
                const SizedBox(height: 32),
                LinearProgressIndicator(
                  value: progress / 100,
                  backgroundColor: global.borderColor,
                  valueColor: const AlwaysStoppedAnimation(global.primaryAccent),
                ),
                const SizedBox(height: 8),
                Text(
                  "$progress%",
                  style: GoogleFonts.poppins(color: global.primaryAccent, fontWeight: FontWeight.bold),
                ),
                if (_isPolling)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      "Polling server for latest updates...",
                      style: GoogleFonts.poppins(color: global.labelColor, fontSize: 10, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
              if (traces.isNotEmpty) ...[
                const SizedBox(height: 32),
                _buildTraceSection(traces),
              ],
              if (status == 'failed') ...[
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    _pollingTimer?.cancel();
                    setState(() {
                      _trackingId = null;
                      _apiStatus = null;
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: global.borderColor),
                  child: const Text("TRY ANOTHER ID"),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTraceSection(List<dynamic> traces) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.analytics_outlined, size: 14, color: global.primaryAccent),
            const SizedBox(width: 8),
            Text(
              "EXECUTION TRACES",
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: global.primaryAccent,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxHeight: 250),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: global.borderColor.withValues(alpha: 0.5)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.all(12),
            itemCount: traces.length,
            separatorBuilder: (context, index) => const Divider(color: global.borderColor, height: 16),
            itemBuilder: (context, index) {
              final trace = traces[index];
              final type = trace['type'] ?? 'info';
              final module = trace['module'] ?? 'SYSTEM';
              final message = trace['message'] ?? '';

              Color typeColor;
              IconData typeIcon;

              switch (type) {
                case 'success':
                  typeColor = global.successColor;
                  typeIcon = Icons.check_circle_rounded;
                  break;
                case 'warning':
                  typeColor = global.warningColor;
                  typeIcon = Icons.warning_rounded;
                  break;
                case 'error':
                  typeColor = global.errorColor;
                  typeIcon = Icons.error_rounded;
                  break;
                default:
                  typeColor = global.infoColor;
                  typeIcon = Icons.info_rounded;
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(typeIcon, size: 14, color: typeColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          module,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: typeColor.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: global.valueColor.withValues(alpha: 0.9),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 64);
      case 'failed':
        return const Icon(Icons.error_outline_rounded, color: global.errorColor, size: 64);
      case 'generating':
      case 'validating':
      case 'saving':
        return const SizedBox(
          width: 64,
          height: 64,
          child: CircularProgressIndicator(strokeWidth: 6, color: global.primaryAccent),
        );
      default:
        return const Icon(Icons.hourglass_empty_rounded, color: global.labelColor, size: 64);
    }
  }

  String _getStatusMessage(String status, String? error) {
    if (status == 'failed') return error ?? "An unknown error occurred during generation.";
    switch (status) {
      case 'queued': return "Waiting for a professional content developer instance...";
      case 'generating': return "AI is crafting your questions and explanations...";
      case 'validating': return "ThinkFast is performing strict pedagogical validation...";
      case 'saving': return "Ingesting quiz data and generating insights...";
      case 'completed': return "Quiz is ready! Redirecting you now...";
      default: return "Please stay on this screen while we prepare your session.";
    }
  }

  Widget _buildJoinExistingQuizPrompt() {
    return Column(
      children: [
        const Divider(color: global.borderColor),
        const SizedBox(height: 24),
        Text(
          "Not tracking a generation?",
          style: GoogleFonts.poppins(color: global.labelColor, fontSize: 13),
        ),
        TextButton(
          onPressed: () {
            // Unify with Sidebar "Join Quiz" logic
            _showJoinByIdDialog();
          },
          child: Text(
            "JOIN EXISTING QUIZ BY ID",
            style: GoogleFonts.poppins(
              color: global.primaryAccent,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ],
    );
  }

  void _showJoinByIdDialog() {
    final TextEditingController idController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: global.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Join Quiz", style: TextStyle(color: global.valueColor)),
        content: TextField(
          controller: idController,
          autofocus: true,
          style: const TextStyle(color: global.valueColor),
          decoration: const InputDecoration(
            hintText: "Enter Quiz ID",
            hintStyle: TextStyle(color: global.labelColor),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              final id = idController.text.trim();
              if (id.isNotEmpty) {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/Quiz Details", arguments: id);
              }
            },
            child: const Text("JOIN"),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Column(
      children: [
        const Icon(Icons.search_off_rounded, color: global.labelColor, size: 48),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: global.labelColor),
        ),
      ],
    );
  }
}
