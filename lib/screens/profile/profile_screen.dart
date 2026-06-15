import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';
import 'package:thinkfast/utils/global.dart' as global;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseService _dbService = DatabaseService();
  final User? _user = FirebaseAuth.instance.currentUser;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _uidController = TextEditingController();

  // Extended AI Profile Controllers
  final TextEditingController _classController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _interestsController = TextEditingController();
  final TextEditingController _learningTopicsController =
      TextEditingController();
  final TextEditingController _languageController = TextEditingController();
  final TextEditingController _studyHoursController = TextEditingController();
  String _preferredDifficulty = 'medium';

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (_user == null) return;

    try {
      // Refresh user to get latest info (like displayName from Google)
      await _user.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;

      _uidController.text = updatedUser?.uid ?? '';
      final profile = await _dbService.getUserProfile(updatedUser!.uid);

      if (profile != null) {
        // Load from Firestore, fallback to Auth DisplayName if Firestore name is empty
        _nameController.text =
            (profile['name'] != null && profile['name'].toString().isNotEmpty)
            ? profile['name']
            : (updatedUser.displayName ?? '');

        _classController.text = profile['class'] ?? '';
        _ageController.text = profile['age'] ?? '';
        _goalController.text = profile['goal'] ?? '';
        _interestsController.text = (profile['interests'] as List? ?? []).join(
          ', ',
        );
        _learningTopicsController.text =
            (profile['learningTopics'] as List? ?? []).join(', ');
        _languageController.text = profile['preferredLanguage'] ?? '';
        _studyHoursController.text = (profile['studyHoursPerWeek'] != null)
            ? profile['studyHoursPerWeek'].toString()
            : '';
        _preferredDifficulty = profile['preferredDifficulty'] ?? 'medium';
      } else {
        // New user fallback
        _nameController.text = updatedUser.displayName ?? '';
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    if (_user == null) return;

    // Name validation
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Full Name is required", style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Save Public Profile
      await _dbService.updateUserProfile(
        uid: _user!.uid,
        name: _nameController.text.trim(),
      );

      // Save Protected AI Details
      await _dbService.updateProtectedDetails(
        uid: _user!.uid,
        details: {
          'class': _classController.text.trim(),
          'age': _ageController.text.trim(),
          'goal': _goalController.text.trim(),
          'interests': _interestsController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          'learningTopics': _learningTopicsController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          'preferredDifficulty': _preferredDifficulty,
          'preferredLanguage': _languageController.text.trim(),
          'studyHoursPerWeek': int.tryParse(_studyHoursController.text) ?? 0,
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Profile updated successfully",
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
        ),
      );

      // If we came from login, we might want to navigate away after saving
      // Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Update failed: $e", style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: global.valueColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Complete Profile",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: global.valueColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "SKIP",
              style: GoogleFonts.poppins(
                color: global.primaryAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: global.primaryAccent),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: global.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: global.borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              const CircleAvatar(
                                radius: 50,
                                backgroundColor: global.bgColor,
                                child: Icon(
                                  Icons.person,
                                  size: 60,
                                  color: global.primaryAccent,
                                ),
                              ),
                              if (_user != null && !_user!.emailVerified)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: global.cardColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "UNVERIFIED",
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (_user != null && _user!.emailVerified)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: global.cardColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        _buildSectionHeader("Basic Information"),
                        const SizedBox(height: 16),
                        _buildLabel("Full Name *"),
                        const SizedBox(height: 8),
                        _buildTextField(
                          _nameController,
                          "Enter your name",
                          Icons.person_outline,
                        ),

                        const SizedBox(height: 24),
                        _buildLabel("User UID"),
                        const SizedBox(height: 8),
                        _buildTextField(
                          _uidController,
                          "User ID",
                          Icons.fingerprint_rounded,
                          readOnly: true,
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.copy_rounded,
                              color: global.primaryAccent,
                              size: 20,
                            ),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: _uidController.text),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("UID copied to clipboard"),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 32),
                        _buildSectionHeader("AI & Personalization"),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel("Class/Grade"),
                                  const SizedBox(height: 8),
                                  _buildTextField(
                                    _classController,
                                    "e.g. 12th",
                                    Icons.school_outlined,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel("Age"),
                                  const SizedBox(height: 8),
                                  _buildTextField(
                                    _ageController,
                                    "e.g. 18",
                                    Icons.cake_outlined,
                                    keyboardType: TextInputType.number,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        _buildLabel("Study Goal"),
                        const SizedBox(height: 8),
                        _buildTextField(
                          _goalController,
                          "e.g. Crack NEET 2025",
                          Icons.track_changes_rounded,
                        ),

                        const SizedBox(height: 20),
                        _buildLabel("Interests (comma separated)"),
                        const SizedBox(height: 8),
                        _buildTextField(
                          _interestsController,
                          "Physics, Space, Coding",
                          Icons.auto_awesome_outlined,
                        ),

                        const SizedBox(height: 20),
                        _buildLabel("Specific Learning Topics"),
                        const SizedBox(height: 8),
                        _buildTextField(
                          _learningTopicsController,
                          "e.g. Quantum Mechanics, Organic Chemistry",
                          Icons.book_outlined,
                        ),

                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel("Preferred Language"),
                                  const SizedBox(height: 8),
                                  _buildTextField(
                                    _languageController,
                                    "English / Hindi",
                                    Icons.translate_rounded,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel("Study Hours/Week"),
                                  const SizedBox(height: 8),
                                  _buildTextField(
                                    _studyHoursController,
                                    "e.g. 10",
                                    Icons.timer_outlined,
                                    keyboardType: TextInputType.number,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        _buildLabel("Difficulty Preference"),
                        const SizedBox(height: 8),
                        _buildDropdownField(),

                        const SizedBox(height: 32),
                        _buildSectionHeader("Private Information"),
                        const SizedBox(height: 16),
                        _buildLabel("Email Address (Private)"),
                        const SizedBox(height: 8),
                        _buildTextField(
                          TextEditingController(text: _user?.email ?? ""),
                          "Email",
                          Icons.email_outlined,
                          readOnly: true,
                        ),

                        const SizedBox(height: 40),
                        _isSaving
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: global.primaryAccent,
                                ),
                              )
                            : ElevatedButton(
                                onPressed: _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: global.btnColor,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 4,
                                ),
                                child: Text(
                                  "SAVE & CONTINUE",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: global.primaryAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: global.primaryAccent,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: global.labelColor,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool readOnly = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(color: global.valueColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
          color: global.labelColor.withOpacity(0.5),
        ),
        prefixIcon: Icon(icon, color: global.primaryAccent, size: 22),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: global.bgColor.withOpacity(0.5),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: global.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: global.primaryAccent, width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: global.bgColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: global.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _preferredDifficulty,
          dropdownColor: global.cardColor,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: global.primaryAccent,
          ),
          style: GoogleFonts.poppins(color: global.valueColor),
          decoration: const InputDecoration(
            border: InputBorder.none,
            prefixIcon: Icon(
              Icons.bar_chart_rounded,
              color: global.primaryAccent,
              size: 22,
            ),
          ),
          items: ['easy', 'medium', 'hard'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value.toUpperCase(),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            );
          }).toList(),
          onChanged: (newValue) {
            setState(() => _preferredDifficulty = newValue!);
          },
        ),
      ),
    );
  }
}
