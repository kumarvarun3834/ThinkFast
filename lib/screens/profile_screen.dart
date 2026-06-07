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

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (_user == null) return;

    _uidController.text = _user!.uid;
    final profile = await _dbService.getUserProfile(_user!.uid);
    if (profile != null) {
      _nameController.text = profile['name'] ?? '';
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    if (_user == null) return;

    setState(() => _isSaving = true);

    try {
      await _dbService.updateUserProfile(
        uid: _user!.uid,
        name: _nameController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Profile updated successfully", style: GoogleFonts.poppins()),
          backgroundColor: Colors.green,
        ),
      );
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
        title: Text(
          "My Profile",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: global.valueColor,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: global.primaryAccent))
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
                        const Center(
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: global.bgColor,
                            child: Icon(Icons.person, size: 60, color: global.primaryAccent),
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildLabel("Full Name"),
                        const SizedBox(height: 8),
                        _buildTextField(_nameController, "Enter your name", Icons.person_outline),
                        const SizedBox(height: 24),
                        _buildLabel("User UID"),
                        const SizedBox(height: 8),
                        _buildTextField(
                          _uidController, 
                          "User ID", 
                          Icons.fingerprint_rounded, 
                          readOnly: true,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy_rounded, color: global.primaryAccent, size: 20),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _uidController.text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("UID copied to clipboard")),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 40),
                        _isSaving
                            ? const Center(child: CircularProgressIndicator(color: global.primaryAccent))
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
                                  "SAVE CHANGES",
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
    IconData icon, 
    {bool readOnly = false, Widget? suffixIcon}
  ) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      style: GoogleFonts.poppins(color: global.valueColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: global.labelColor.withOpacity(0.5)),
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
}
