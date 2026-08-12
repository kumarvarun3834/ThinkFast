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
  State<AiGenerationStatusScreen> createState() =>
      _AiGenerationStatusScreenState();
}

class _AiGenerationStatusScreenState extends State<AiGenerationStatusScreen> {
  final TextEditingController _idController = TextEditingController();
  final AiService _aiService = AiService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _trackingId;
  bool _isNavigating = false;
  Timer? _pollingTimer;
  StreamSubscription? _statusSubscription;
  Map<String, dynamic>? _apiStatus;
  bool _isPolling = false;

  // Premium Shell State
  final List<Map<String, dynamic>> _shellLogs = [];
  String? _lastStatus;
  final Set<String> _recordedTraceIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialQuizId != null) {
      _idController.text = widget.initialQuizId!;
      _startTracking();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _statusSubscription?.cancel();
    _idController.dispose();
    super.dispose();
  }

  void _startTracking() {
    final id = _idController.text.trim();
    if (id.isEmpty) return;

    _pollingTimer?.cancel();
    _statusSubscription?.cancel();

    setState(() {
      _trackingId = id;
      _shellLogs.clear();
      _recordedTraceIds.clear();
      _lastStatus = null;
      _apiStatus = null;
      _isNavigating = false;
    });

    _logToShell(
      "Watcher initialized for session ID: $id",
      type: 'info',
      module: 'SYS',
    );
    _startPolling();
    _startStream(id);
  }

  void _startStream(String id) {
    _statusSubscription = global.aiConnect.listenToGenerationStatus(id).listen((
      data,
    ) {
      if (mounted) {
        setState(() {
          _processIncomingData(data);
        });
      }
    });
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    if (_trackingId == null) return;

    _fetchStatus();
    // Real-time Polling: 5 seconds for a responsive feel and latest backend state
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchStatus();
    });
  }

  void _logToShell(
    String message, {
    String type = 'info',
    String module = 'SYS',
  }) {
    _shellLogs.add({
      'type': type,
      'module': module,
      'message': message,
      'timestamp': DateTime.now(),
    });
  }

  void _processIncomingData(Map<String, dynamic>? data) {
    if (data == null) return;

    final String status = (data['status'] ?? 'Queued').toString().toLowerCase();
    final String? statusText = data['statusText'] ?? data['message'];
    final bool isImplicitFailure =
        statusText != null &&
        (statusText.toLowerCase().contains('failed') ||
            statusText.toLowerCase().contains('error'));

    if (status != _lastStatus) {
      _logToShell(
        "Transitioning state to ${status.toUpperCase()}...",
        type: isImplicitFailure ? 'error' : 'success',
        module: 'CORE',
      );
      _lastStatus = status;
    }

    if (isImplicitFailure) {
      _logToShell(
        "CRITICAL ERROR: $statusText",
        type: 'error',
        module: 'BACKEND',
      );
    }

    final List<dynamic> traces = data['traces'] ?? [];
    for (var trace in traces) {
      final String? tid = trace['id'];
      // Use Trace ID if available, otherwise fallback to message content hash
      final String uniqueKey =
          tid ?? trace['message']?.hashCode.toString() ?? '';

      if (uniqueKey.isNotEmpty && !_recordedTraceIds.contains(uniqueKey)) {
        _recordedTraceIds.add(uniqueKey);
        _shellLogs.add({
          'type': trace['type'] ?? 'info',
          'module': trace['module'] ?? 'SYSTEM',
          'message': trace['message'] ?? '',
          'timestamp': DateTime.now(),
        });
      }
    }

    if ((status == 'completed' || status == 'ready') && !_isNavigating) {
      _navigateToQuiz();
    }
  }

  Future<void> _fetchStatus() async {
    if (_trackingId == null || _isPolling || _isNavigating) return;

    setState(() => _isPolling = true);
    try {
      Map<String, dynamic> statusData;

      // Logic: If status is Queued or the ID suggests a queue item, use Queue Endpoint
      if (_lastStatus == 'Queued' ||
          _lastStatus == 'pending' ||
          _lastStatus == 'processing' ||
          _trackingId!.startsWith('Q-')) {
        try {
          statusData = await _aiService.getQueueStatus(_trackingId!);
        } catch (e) {
          // Fallback to Quiz status if queue check fails
          statusData = await _aiService.getQuizStatus(_trackingId!);
        }
      } else {
        statusData = await _aiService.getQuizStatus(_trackingId!);
      }

      if (mounted) {
        setState(() {
          _apiStatus = statusData;
          _processIncomingData(statusData);
          _isPolling = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPolling = false);
        _logToShell(
          "Network error during polling: $e",
          type: 'error',
          module: 'WATCHER',
        );
      }
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
                _statusSubscription?.cancel();
                setState(() {
                  _trackingId = null;
                  _apiStatus = null;
                  _shellLogs.clear();
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
              const SizedBox(height: 24),
              _buildExecutionShell(),
              const SizedBox(height: 40),
              TextButton.icon(
                onPressed: () {
                  _pollingTimer?.cancel();
                  _statusSubscription?.cancel();
                  setState(() {
                    _trackingId = null;
                    _apiStatus = null;
                    _shellLogs.clear();
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
            const Icon(
              Icons.history_rounded,
              size: 18,
              color: global.primaryAccent,
            ),
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
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }

            final history = snapshot.data ?? [];
            if (history.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: global.cardColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: global.borderColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  "No recent generation requests found.",
                  style: GoogleFonts.poppins(
                    color: global.labelColor,
                    fontSize: 13,
                  ),
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

                // Robust status detection for history list
                final String status = (item['status'] ?? 'queued').toString();
                final String message =
                    (item['message'] ?? item['statusText'] ?? '').toString();
                final String s = status.toLowerCase();
                final String m = message.toLowerCase();

                final bool isDone =
                    s.contains('completed') || s.contains('ready');
                final bool isFailed =
                    s.contains('failed') ||
                    s.contains('error') ||
                    m.contains('failed') ||
                    m.contains('error');

                final String displayStatus = isFailed
                    ? 'FAILED'
                    : (isDone ? 'COMPLETED' : status.toUpperCase());
                final Color statusColor = isFailed
                    ? global.errorColor
                    : (isDone ? global.successColor : global.primaryAccent);

                return InkWell(
                  onTap: () {
                    if (isDone) {
                      Navigator.pushNamed(
                        context,
                        '/Quiz Details',
                        arguments: item['quizId'] ?? quizId,
                      );
                    } else {
                      _idController.text = quizId;
                      _startTracking();
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: global.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isFailed
                            ? global.errorColor.withValues(alpha: 0.3)
                            : global.borderColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFailed
                                ? Icons.error_outline_rounded
                                : (isDone
                                      ? Icons.check_circle_rounded
                                      : Icons.auto_awesome_rounded),
                            size: 20,
                            color: statusColor,
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
                              Row(
                                children: [
                                  Text(
                                    "ID: $quizId",
                                    style: GoogleFonts.firaCode(
                                      color: global.labelColor,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      displayStatus,
                                      style: GoogleFonts.poppins(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isDone
                              ? Icons.play_circle_outline_rounded
                              : Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: isDone
                              ? global.successColor
                              : global.labelColor,
                        ),
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
    final s = status.toLowerCase();
    if (s.contains('completed') || s.contains('ready')) {
      return global.successColor;
    }
    if (s.contains('failed') || s.contains('error')) {
      return global.errorColor;
    }
    // Treat everything else as an active/processing state
    return global.primaryAccent;
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
                borderSide: const BorderSide(
                  color: global.primaryAccent,
                  width: 2,
                ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "FETCH STATUS",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
          if (snapshot.connectionState == ConnectionState.waiting &&
              !_isPolling) {
            return const Center(child: CircularProgressIndicator());
          }
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: global.cardColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: global.borderColor.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              "No active generation found for this ID. It might have expired or doesn't exist.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: global.labelColor,
                fontSize: 13,
              ),
            ),
          );
        }

        final String status = (data['status'] ?? 'Queued')
            .toString()
            .toLowerCase();
        final String? statusText = data['statusText'] ?? data['message'];

        // Map status to progress if numeric progress is missing or 0
        int progress = (data['progress'] ?? 0).toInt();
        if (progress == 0) {
          if (status.contains('queued')) {
            progress = 10;
          } else if (status.contains('generating')) {
            progress = 40;
          } else if (status.contains('validating')) {
            progress = 70;
          } else if (status.contains('saving')) {
            progress = 90;
          } else if (status.contains('completed') || status.contains('ready')) {
            progress = 100;
          }
        }

        // Detect if the statusText itself indicates a failure even if status is not 'failed'
        final bool isImplicitFailure =
            statusText != null &&
            (statusText.toLowerCase().contains('failed') ||
                statusText.toLowerCase().contains('error'));

        final String? error = isImplicitFailure ? statusText : data['error'];
        final String? prompt = data['prompt'];
        final int? currentStep = data['currentStep'];
        final int? totalSteps = data['totalSteps'];

        final bool isFailed =
            status == 'failed' || status == 'error' || isImplicitFailure;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: global.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isFailed
                  ? global.errorColor
                  : global.primaryAccent.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.fingerprint_rounded,
                    size: 12,
                    color: global.labelColor,
                  ),
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
              _buildStatusIcon(isImplicitFailure ? 'failed' : status),
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
                (isImplicitFailure ? 'FAILURE' : status).toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isFailed ? global.errorColor : global.valueColor,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              if (statusText != null) ...[
                Text(
                  statusText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: isFailed
                        ? global.errorColor
                        : global.valueColor.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                _getStatusMessage(isImplicitFailure ? 'failed' : status, error),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: global.labelColor,
                  fontSize: 13,
                ),
              ),
              if (currentStep != null && totalSteps != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: global.primaryAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "QUESTION $currentStep OF $totalSteps",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: global.primaryAccent,
                    ),
                  ),
                ),
              ],
              if (status == 'completed' || status == 'ready') ...[
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _navigateToQuiz,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.description_rounded),
                    label: const Text(
                      "VIEW QUIZ →",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
              if (status != 'failed' &&
                  status != 'error' &&
                  status != 'completed' &&
                  status != 'ready') ...[
                const SizedBox(height: 32),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(6),
                      backgroundColor: global.borderColor,
                      valueColor: const AlwaysStoppedAnimation(
                        global.primaryAccent,
                      ),
                    ),
                    if (progress > 10)
                      Text(
                        "$progress%",
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                if (progress <= 10) ...[
                  const SizedBox(height: 8),
                  Text(
                    "$progress%",
                    style: GoogleFonts.poppins(
                      color: global.primaryAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                if (_isPolling)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: global.labelColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Syncing with live generation engine...",
                          style: GoogleFonts.poppins(
                            color: global.labelColor,
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              if (isFailed) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: global.borderColor,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text("RETRY"),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _trackingId = null;
                          _apiStatus = null;
                          _shellLogs.clear();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: global.borderColor),
                        foregroundColor: global.labelColor,
                      ),
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: const Text("NEW ID"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDebugInfo(quizId, error),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDebugInfo(String id, String? error) {
    return Container(
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "DEBUG INFO",
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: global.labelColor,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            "TrackingID: $id\nError: ${error ?? 'None'}",
            style: GoogleFonts.firaCode(fontSize: 9, color: global.labelColor),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutionShell() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.terminal_rounded,
              size: 14,
              color: global.primaryAccent,
            ),
            const SizedBox(width: 8),
            Text(
              "EXECUTION SHELL",
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: global.primaryAccent,
                letterSpacing: 1.1,
              ),
            ),
            const Spacer(),
            if (_isPolling)
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1,
                  color: global.primaryAccent,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 220,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: global.borderColor.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _shellLogs.isEmpty
              ? Center(
                  child: Text(
                    "Waiting for system output...",
                    style: GoogleFonts.firaCode(
                      color: global.hintColor,
                      fontSize: 11,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _shellLogs.length,
                  itemBuilder: (context, index) {
                    final log = _shellLogs[index];
                    final Color color = _getStatusColor(log['type']);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.firaCode(
                            fontSize: 11,
                            height: 1.4,
                          ),
                          children: [
                            TextSpan(
                              text: "[${log['module']}] ",
                              style: TextStyle(
                                color: color.withValues(alpha: 0.8),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: log['message'],
                              style: TextStyle(
                                color: global.valueColor.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatusIcon(String status) {
    final s = status.toLowerCase();
    if (s.contains('completed') || s.contains('ready')) {
      return const Icon(
        Icons.check_circle_rounded,
        color: Colors.greenAccent,
        size: 64,
      );
    }
    if (s.contains('failed') || s.contains('error')) {
      return const Icon(
        Icons.error_outline_rounded,
        color: global.errorColor,
        size: 64,
      );
    }
    // Active states (Generating, Processing, Validating, etc.)
    return Container(
      width: 80,
      height: 80,
      padding: const EdgeInsets.all(8),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 6,
            color: global.primaryAccent,
          ),
          Icon(Icons.auto_awesome_rounded, color: global.primaryAccent),
        ],
      ),
    );
  }

  String _getStatusMessage(String status, String? error) {
    final s = status.toLowerCase();
    final e = error?.toLowerCase() ?? '';

    if (s.contains('failed') || s.contains('error') || e.contains('failed')) {
      if (e.contains('fetch failed')) {
        return "The backend worker lost connection to the AI engine. This usually happens due to a server-side timeout or API rate limits.";
      }
      if (e.contains('quota')) {
        return "Daily AI generation limit reached. Please check your account usage.";
      }
      return error ?? "An unknown error occurred during generation.";
    }
    if (s.contains('completed') || s.contains('ready')) {
      return "Quiz is ready! Redirecting you now...";
    }
    if (s.contains('generating')) {
      return "AI is crafting your questions and explanations...";
    }
    if (s.contains('validating')) {
      return "ThinkFast is performing strict pedagogical validation...";
    }
    if (s.contains('saving')) {
      return "Ingesting quiz data and generating insights...";
    }
    if (s.contains('processing') || s.contains('queued')) {
      return "Waiting for a professional content developer instance...";
    }

    // If it's a descriptive status from the backend, we use it as is if needed,
    // otherwise fallback to a helpful generic message.
    return "Please stay on this screen while we prepare your session.";
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
        title: const Text(
          "Join Quiz",
          style: TextStyle(color: global.valueColor),
        ),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
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
}
