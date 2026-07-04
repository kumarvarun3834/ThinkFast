import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/screens/quiz/ai_quiz_generator.dart';
import 'package:thinkfast/screens/quiz/form/attempt_limits_panel.dart';
import 'package:thinkfast/screens/quiz/form/form_data_helpers.dart';
import 'package:thinkfast/screens/quiz/form/marking_scheme_panel.dart';
import 'package:thinkfast/screens/quiz/form/modules_panel.dart';
import 'package:thinkfast/screens/quiz/form/questions_list_section.dart';
import 'package:thinkfast/screens/quiz/form/quiz_form_controller.dart';
import 'package:thinkfast/screens/quiz/form/quiz_header_section.dart';
import 'package:thinkfast/screens/quiz/form/scheduling_panel.dart';
import 'package:thinkfast/screens/quiz/form/timing_config_panel.dart';
import 'package:thinkfast/services/quiz_data_processor.dart';
import 'package:thinkfast/utils/global.dart' as global;
import 'package:thinkfast/widgets/drawer_data.dart';
import 'package:thinkfast/widgets/quiz_widgets.dart';

class QuizPage extends StatefulWidget {
  final String docId;

  const QuizPage(this.docId, {super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  User? user;
  bool _isAdmin = false,
      _importEnabled = false,
      _isLoading = false,
      _hasError = false,
      _isAiGenerated = false;
  String _errorMessage = "";
  late String _currentDocId;
  late final TextEditingController _titleController,
      _descriptionController,
      _examController,
      _timeController,
      _perQuestionTimeController,
      _allowedUsersController;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _moduleController = TextEditingController();

  String visibility = "private",
      timingType = "global",
      attemptLimitType = "none",
      markingType = "default";
  bool allowMultipleAttempts = true,
      completeRandomShuffle = false,
      shuffleModules = false,
      shuffleQuestionsWithinModules = false,
      disableModuleSwitchingUntilTimeout = false,
      forceWaitUntilTimeout = false;
  DateTime? _scheduledTime;
  bool _isRestricted = false;

  final Map<String, Map<String, TextEditingController>>
  _moduleTimingControllers = {},
  _moduleLimitControllers = {};
  final Map<String, TextEditingController> _typeTimingControllers = {
        "Single Choice": TextEditingController(text: "0"),
        "Multiple Choice": TextEditingController(text: "0"),
        "Integer": TextEditingController(text: "0"),
      },
      _moduleTagControllers = {},
      _globalLimitControllers = {
        "Single Choice": TextEditingController(),
        "Multiple Choice": TextEditingController(),
        "Integer": TextEditingController(),
      };

  final TextEditingController _globalCorrectController = TextEditingController(
        text: "4",
      ),
      _globalWrongController = TextEditingController(text: "-1");
  final TextEditingController _scCorrectController = TextEditingController(
        text: "4",
      ),
      _scWrongController = TextEditingController(text: "-1");
  final TextEditingController _mcCorrectController = TextEditingController(
        text: "4",
      ),
      _mcWrongController = TextEditingController(text: "-1");
  final TextEditingController _intCorrectController = TextEditingController(
        text: "4",
      ),
      _intWrongController = TextEditingController(text: "-1");

  final List<String> modulesList = ["General"];
  final List<Map<String, Object>> questions = [];
  final Map<String, GlobalKey> _moduleKeys = {};
  final Map<int, GlobalKey> _questionKeys = {};

  bool _isFirstLoad = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isFirstLoad) {
      _isFirstLoad = false;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.isNotEmpty) {
        // If arguments is a non-empty string, it's a JSON string from AI Dialog
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _importQuizData(args);
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _currentDocId = widget.docId;
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _examController = TextEditingController();
    _timeController = TextEditingController();
    _perQuestionTimeController = TextEditingController(text: "0");
    _allowedUsersController = TextEditingController();
    user = FirebaseAuth.instance.currentUser;
    _isAdmin = global.isAdmin;
    _importEnabled = global.featureFlags?['enable_import'] ?? false;
    _updateModuleLimitControllers();
    if (_currentDocId.isNotEmpty) {
      _fetchQuiz(_currentDocId);
    } else {
      questions.add({"subject": "General"});
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _examController.dispose();
    _timeController.dispose();
    _perQuestionTimeController.dispose();
    _allowedUsersController.dispose();
    _moduleController.dispose();
    _globalCorrectController.dispose();
    _globalWrongController.dispose();
    _scCorrectController.dispose();
    _scWrongController.dispose();
    _mcCorrectController.dispose();
    _mcWrongController.dispose();
    _intCorrectController.dispose();
    _intWrongController.dispose();
    _globalLimitControllers.forEach((_, c) => c.dispose());
    _moduleLimitControllers.forEach((_, m) => m.forEach((_, c) => c.dispose()));
    _moduleTagControllers.forEach((_, c) => c.dispose());
    super.dispose();
  }

  void _updateModuleLimitControllers() {
    for (var m in modulesList) {
      _moduleLimitControllers.putIfAbsent(
        m,
        () => {
          "Single Choice": TextEditingController(),
          "Multiple Choice": TextEditingController(),
          "Integer": TextEditingController(),
        },
      );
      _moduleTagControllers.putIfAbsent(m, () => TextEditingController());
    }
  }

  void _updateModuleTimingControllers() {
    for (var m in modulesList) {
      _moduleTimingControllers.putIfAbsent(
        m,
        () => {
          "total": TextEditingController(text: "0"),
          "perQuestion": TextEditingController(text: "0"),
        },
      );
    }
  }

  void _moveModule(int oldIdx, int newIdx) {
    if (newIdx >= 0 && newIdx < modulesList.length)
      setState(() => modulesList.insert(newIdx, modulesList.removeAt(oldIdx)));
  }

  void _showImportDialog({bool append = false}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: global.cardColor,
        title: Text(
          append ? "Append Data" : "Import Data",
          style: GoogleFonts.poppins(color: global.valueColor),
        ),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(hintText: "Enter JSON..."),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _importQuizData(controller.text.trim(), append: append);
            },
            child: const Text("IMPORT"),
          ),
        ],
      ),
    );
  }

  Future<void> _importQuizData(String input, {bool append = false}) async {
    try {
      final res = await QuizDataProcessor.processImportData(input);
      setState(() => _isAiGenerated = true);
      await QuizFormController.importQuizData(
        result: res,
        append: append,
        titleController: _titleController,
        descriptionController: _descriptionController,
        examController: _examController,
        timeController: _timeController,
        perQuestionTimeController: _perQuestionTimeController,
        allowedUsersController: _allowedUsersController,
        moduleTagControllers: _moduleTagControllers,
        globalLimitControllers: _globalLimitControllers,
        moduleLimitControllers: _moduleLimitControllers,
        moduleTimingControllers: _moduleTimingControllers,
        typeTimingControllers: _typeTimingControllers,
        globalCorrectController: _globalCorrectController,
        globalWrongController: _globalWrongController,
        scCorrectController: _scCorrectController,
        scWrongController: _scWrongController,
        mcCorrectController: _mcCorrectController,
        mcWrongController: _mcWrongController,
        intCorrectController: _intCorrectController,
        intWrongController: _intWrongController,
        modulesList: modulesList,
        questions: questions,
        updateState: (k, v) => setState(() {
          if (k == 'allowMultipleAttempts') {
            allowMultipleAttempts = v;
          } else if (k == 'completeRandomShuffle') {
            completeRandomShuffle = v;
          } else if (k == 'shuffleModules') {
            shuffleModules = v;
          } else if (k == 'shuffleQuestionsWithinModules') {
            shuffleQuestionsWithinModules = v;
          } else if (k == 'disableModuleSwitchingUntilTimeout') {
            disableModuleSwitchingUntilTimeout = v;
          } else if (k == 'forceWaitUntilTimeout') {
            forceWaitUntilTimeout = v;
          } else if (k == 'isRestricted') {
            _isRestricted = v;
          } else if (k == 'timingType') {
            timingType = v;
          } else if (k == 'markingType') {
            markingType = v;
          } else if (k == 'attemptLimitType') {
            attemptLimitType = v;
          }
        }),
        updateModuleLimitControllers: _updateModuleLimitControllers,
        updateModuleTimingControllers: _updateModuleTimingControllers,
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Import error: $e")));
    }
  }

  Future<void> _importFromQuizId(String docId) async {
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not authenticated");
      await QuizFormController.importFromQuizId(
        docId: docId,
        uid: uid,
        modulesList: modulesList,
        questions: questions,
        updateModuleLimitControllers: _updateModuleLimitControllers,
        updateState: (k, v) => setState(() {
          if (k == 'isAiGenerated') _isAiGenerated = v;
        }),
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Wizard data appended successfully")),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Import error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchQuiz(String docId) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = "";
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw "Authentication failed. Please login again.";
      await QuizFormController.fetchQuiz(
        docId: docId,
        uid: uid,
        titleController: _titleController,
        descriptionController: _descriptionController,
        examController: _examController,
        timeController: _timeController,
        perQuestionTimeController: _perQuestionTimeController,
        allowedUsersController: _allowedUsersController,
        moduleTagControllers: _moduleTagControllers,
        globalLimitControllers: _globalLimitControllers,
        moduleLimitControllers: _moduleLimitControllers,
        globalCorrectController: _globalCorrectController,
        globalWrongController: _globalWrongController,
        scCorrectController: _scCorrectController,
        scWrongController: _scWrongController,
        mcCorrectController: _mcCorrectController,
        mcWrongController: _mcWrongController,
        intCorrectController: _intCorrectController,
        intWrongController: _intWrongController,
        modulesList: modulesList,
        questions: questions,
        updateState: (k, v) => setState(() {
          if (k == 'scheduledTime') {
            _scheduledTime = v as DateTime?;
          } else if (k == 'visibility') {
            visibility = v as String;
          } else if (k == 'allowMultipleAttempts') {
            allowMultipleAttempts = v as bool;
          } else if (k == 'completeRandomShuffle') {
            completeRandomShuffle = v as bool;
          } else if (k == 'shuffleModules') {
            shuffleModules = v as bool;
          } else if (k == 'shuffleQuestionsWithinModules') {
            shuffleQuestionsWithinModules = v as bool;
          } else if (k == 'disableModuleSwitchingUntilTimeout') {
            disableModuleSwitchingUntilTimeout = v as bool;
          } else if (k == 'forceWaitUntilTimeout') {
            forceWaitUntilTimeout = v as bool;
          } else if (k == 'isRestricted') {
            _isRestricted = v as bool;
          } else if (k == 'markingType') {
            markingType = v as String;
          } else if (k == 'attemptLimitType') {
            attemptLimitType = v as String;
          }
        }),
        updateModuleLimitControllers: _updateModuleLimitControllers,
        updateModuleTimingControllers: _updateModuleTimingControllers,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = "Failed to load quiz for editing. Please check your connection.";
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Load error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveQuiz() async {
    if (user == null) return;
    final markingScheme = FormDataHelpers.prepareMarkingScheme(
      markingType: markingType,
      globalCorrectController: _globalCorrectController,
      globalWrongController: _globalWrongController,
      scCorrectController: _scCorrectController,
      scWrongController: _scWrongController,
      mcCorrectController: _mcCorrectController,
      mcWrongController: _mcWrongController,
      intCorrectController: _intCorrectController,
      intWrongController: _intWrongController,
    );
    final attemptLimits = FormDataHelpers.prepareAttemptLimits(
      attemptLimitType: attemptLimitType,
      globalLimitControllers: _globalLimitControllers,
      moduleLimitControllers: _moduleLimitControllers,
    );
    final timingScheme = FormDataHelpers.prepareTimingScheme(
      timingType: timingType,
      time: int.tryParse(_timeController.text) ?? 0,
      perQuestionTime: int.tryParse(_perQuestionTimeController.text) ?? 0,
      typeTimingControllers: _typeTimingControllers,
      moduleTimingControllers: _moduleTimingControllers,
    );
    final mTagsMap = FormDataHelpers.parseModuleTags(
      _moduleTagControllers,
      questions,
    );
    try {
      if (_currentDocId.isEmpty) {
        _currentDocId = await global.qDb.createDatabase(
          creatorId: user!.uid,
          user: user!.displayName ?? user!.uid,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          visibility: visibility,
          data: questions,
          time: int.tryParse(_timeController.text),
          timingScheme: timingScheme,
          markingScheme: markingScheme,
          attemptLimits: attemptLimits,
          allowMultipleAttempts: allowMultipleAttempts,
          completeRandomShuffle: completeRandomShuffle,
          shuffleModules: shuffleModules,
          shuffleQuestionsWithinModules: shuffleQuestionsWithinModules,
          disableModuleSwitchingUntilTimeout:
              disableModuleSwitchingUntilTimeout,
          forceWaitUntilTimeout: forceWaitUntilTimeout,
          perQuestionTime: int.tryParse(_perQuestionTimeController.text) ?? 0,
          activeAt: _scheduledTime,
          isRestricted: _isRestricted,
          allowedParticipants: FormDataHelpers.parseAllowedParticipants(
            _allowedUsersController.text,
          ),
          isAiGenerated: _isAiGenerated,
          tags: mTagsMap.values.expand((e) => e).toList(),
          moduleTags: mTagsMap,
          examTag: _examController.text.trim(),
          moduleOrder: modulesList,
        );
      } else {
        await global.qDb.updateDatabase(
          docId: _currentDocId,
          currentUserId: user!.uid,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          visibility: visibility,
          data: questions,
          time: int.tryParse(_timeController.text),
          timingScheme: timingScheme,
          markingScheme: markingScheme,
          attemptLimits: attemptLimits,
          allowMultipleAttempts: allowMultipleAttempts,
          completeRandomShuffle: completeRandomShuffle,
          shuffleModules: shuffleModules,
          shuffleQuestionsWithinModules: shuffleQuestionsWithinModules,
          disableModuleSwitchingUntilTimeout:
              disableModuleSwitchingUntilTimeout,
          forceWaitUntilTimeout: forceWaitUntilTimeout,
          perQuestionTime: int.tryParse(_perQuestionTimeController.text) ?? 0,
          activeAt: _scheduledTime,
          isRestricted: _isRestricted,
          allowedParticipants: FormDataHelpers.parseAllowedParticipants(
            _allowedUsersController.text,
          ),
          isAiGenerated: _isAiGenerated,
          tags: mTagsMap.values.expand((e) => e).toList(),
          moduleTags: mTagsMap,
          examTag: _examController.text.trim(),
          moduleOrder: modulesList,
        );
      }
      global.id = _currentDocId;
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Quiz saved")));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Save error: $e")));
    }
  }

  void _addNewForm() => setState(() => questions.add({"subject": "General"}));

  void _removeForm(int idx) => setState(() {
    questions.removeAt(idx);
    if (questions.isEmpty) questions.add({"subject": "General"});
  });

  void _updateFormData(int idx, Map<String, Object> data) {
    setState(() => questions[idx] = data);
  }

  void _scrollToModule(String m) {
    final key = _moduleKeys[m];
    if (key?.currentContext != null)
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 500),
      );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledTime ?? DateTime.now()),
    );
    if (time == null) return;
    setState(
      () => _scheduledTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          global.isAdmin ? "Quiz Editor (ADMIN)" : "Quiz Editor",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          if (global.isAdmin) const AdminBadge(),
          if (global.featureFlags?['enable_ai'] == true)
            TextButton.icon(
              icon: const Icon(
                Icons.auto_awesome_rounded,
                color: global.primaryAccent,
                size: 20,
              ),
              label: Text(
                "QUIZ WIZARD",
                style: GoogleFonts.poppins(
                  color: global.primaryAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              onPressed: () async {
                final id = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (c) => const AiQuizGenerator(forEditor: true),
                  ),
                );
                if (id != null) _importFromQuizId(id);
              },
            ),
          if (_importEnabled)
            IconButton(
              icon: const Icon(
                Icons.file_download_outlined,
                color: global.primaryAccent,
              ),
              onPressed: () => _showImportDialog(),
              tooltip: "Import",
            ),
          IconButton(
            icon: const Icon(Icons.save_rounded, color: global.primaryAccent),
            onPressed: _saveQuiz,
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: global.cardColor,
        child: Column(
          children: [Expanded(child: SidebarMenu(user: user))],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: global.primaryAccent),
            )
          : _hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: global.errorColor,
                          size: 64,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: global.valueColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () => _fetchQuiz(_currentDocId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: global.btnColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(200, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text(
                            "RETRY LOADING",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("GO BACK"),
                        ),
                      ],
                    ),
                  ),
                )
              : Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: InputDecorationTheme(
                  labelStyle: const TextStyle(color: global.labelColor),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: global.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: global.primaryAccent),
                  ),
                ),
              ),
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    QuizHeaderSection(
                      titleController: _titleController,
                      descriptionController: _descriptionController,
                      examController: _examController,
                      timeController: _timeController,
                      perQuestionTimeController: _perQuestionTimeController,
                      visibility: visibility,
                      onVisibilityChanged: (v) =>
                          setState(() => visibility = v!),
                      allowMultipleAttempts: allowMultipleAttempts,
                      onAllowMultipleAttemptsChanged: (v) =>
                          setState(() => allowMultipleAttempts = v),
                      disableModuleSwitchingUntilTimeout:
                          disableModuleSwitchingUntilTimeout,
                      onDisableModuleSwitchingChanged: (v) => setState(
                        () => disableModuleSwitchingUntilTimeout = v,
                      ),
                      forceWaitUntilTimeout: forceWaitUntilTimeout,
                      onForceWaitUntilTimeoutChanged: (v) =>
                          setState(() => forceWaitUntilTimeout = v),
                    ),
                    const SizedBox(height: 16),
                    SchedulingPanel(
                      scheduledTime: _scheduledTime,
                      onPickDateTime: _pickDateTime,
                      onClearDateTime: () =>
                          setState(() => _scheduledTime = null),
                      isRestricted: _isRestricted,
                      onRestrictedChanged: (v) =>
                          setState(() => _isRestricted = v),
                      allowedUsersController: _allowedUsersController,
                    ),
                    const SizedBox(height: 16),
                    ModulesPanel(
                      modulesList: modulesList,
                      moduleController: _moduleController,
                      moduleTagControllers: _moduleTagControllers,
                      importEnabled: _importEnabled,
                      onShowImportDialog: () => _showImportDialog(append: true),
                      onAddModule: () {
                        final m = _moduleController.text.trim();
                        if (m.isNotEmpty && !modulesList.contains(m))
                          setState(() {
                            modulesList.add(m);
                            _moduleController.clear();
                            _updateModuleLimitControllers();
                          });
                      },
                      onMoveModule: _moveModule,
                      onRemoveModule: (m) => setState(() {
                        modulesList.remove(m);
                        _moduleTagControllers.remove(m);
                        _moduleLimitControllers.remove(m);
                      }),
                      onScrollToModule: _scrollToModule,
                      completeRandomShuffle: completeRandomShuffle,
                      onCompleteRandomShuffleChanged: (v) =>
                          setState(() => completeRandomShuffle = v),
                      shuffleModules: shuffleModules,
                      onShuffleModulesChanged: (v) =>
                          setState(() => shuffleModules = v),
                      shuffleQuestionsWithinModules:
                          shuffleQuestionsWithinModules,
                      onShuffleQuestionsWithinModulesChanged: (v) =>
                          setState(() => shuffleQuestionsWithinModules = v),
                    ),
                    const SizedBox(height: 24),
                    MarkingSchemePanel(
                      isAdmin: _isAdmin,
                      markingType: markingType,
                      onTypeChanged: (v) => setState(() => markingType = v),
                      globalCorrectController: _globalCorrectController,
                      globalWrongController: _globalWrongController,
                      scCorrectController: _scCorrectController,
                      scWrongController: _scWrongController,
                      mcCorrectController: _mcCorrectController,
                      mcWrongController: _mcWrongController,
                      intCorrectController: _intCorrectController,
                      intWrongController: _intWrongController,
                    ),
                    const SizedBox(height: 24),
                    TimingConfigPanel(
                      timingType: timingType,
                      onTypeChanged: (v) => setState(() {
                        timingType = v;
                        if (v == "per_module") _updateModuleTimingControllers();
                      }),
                      timeController: _timeController,
                      perQuestionTimeController: _perQuestionTimeController,
                      modulesList: modulesList,
                      moduleTimingControllers: _moduleTimingControllers,
                      typeTimingControllers: _typeTimingControllers,
                    ),
                    const SizedBox(height: 24),
                    AttemptLimitsPanel(
                      attemptLimitType: attemptLimitType,
                      onTypeChanged: (v) => setState(() {
                        attemptLimitType = v;
                        if (v == "per_module") _updateModuleLimitControllers();
                      }),
                      modulesList: modulesList,
                      globalLimitControllers: _globalLimitControllers,
                      moduleLimitControllers: _moduleLimitControllers,
                    ),
                    const SizedBox(height: 24),
                    QuestionsListSection(
                      modulesList: modulesList,
                      questions: questions,
                      moduleKeys: _moduleKeys,
                      questionKeys: _questionKeys,
                      markingType: markingType,
                      onUpdateFormData: _updateFormData,
                      onRemoveForm: _removeForm,
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 40,
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: global.btnColor,
        foregroundColor: Colors.white,
        onPressed: _addNewForm,
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }
}
