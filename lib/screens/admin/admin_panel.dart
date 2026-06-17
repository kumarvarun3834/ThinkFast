import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/settings_service.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final SettingsService _settingsService = SettingsService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Admin Panel",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _settingsService.streamFeatureFlags(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text("Failed to load feature flags", style: TextStyle(color: Colors.white)),
            );
          }

          final flags = snapshot.data!;
          // Remove timestamps and numbers from toggle list
          final toggleKeys = flags.keys.where((k) => flags[k] is bool).toList();
          toggleKeys.sort();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSectionHeader("Feature Flags"),
              const SizedBox(height: 16),
              ...toggleKeys.map((key) => _buildFlagToggle(key, flags[key] as bool)),
              
              const SizedBox(height: 32),
              _buildSectionHeader("Rate Limits"),
              const SizedBox(height: 16),
              _buildRateLimitField(flags),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        color: const Color(0xFF3B82F6),
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildFlagToggle(String key, bool value) {
    // Convert snake_case to Title Case for display
    final displayTitle = key.split('_').map((word) {
      if (word.isEmpty) return "";
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: SwitchListTile(
        title: Text(
          displayTitle,
          style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 16),
        ),
        value: value,
        activeColor: const Color(0xFF3B82F6),
        onChanged: (newValue) async {
          try {
            await _settingsService.updateFeatureFlag(key, newValue);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error updating $key: $e")),
            );
          }
        },
      ),
    );
  }

  Widget _buildRateLimitField(Map<String, dynamic> flags) {
    final int currentVal = (flags['quiz_creation_rate_limit_minutes'] ?? 5).toInt();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              "Creation Rate Limit (Minutes)",
              style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 16),
            ),
          ),
          SizedBox(
            width: 80,
            child: TextField(
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
              ),
              controller: TextEditingController(text: currentVal.toString()),
              onSubmitted: (val) async {
                final newValue = int.tryParse(val);
                if (newValue != null) {
                  await _settingsService.updateFeatureFlag('quiz_creation_rate_limit_minutes', newValue);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
