import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/admin_service.dart';
import 'package:thinkfast/utils/global.dart' as global;

class AdminPermissionsScreen extends StatefulWidget {
  final List<String> targetUids;
  final List<String>? initialPermissions;
  final bool initialIsSuper;

  const AdminPermissionsScreen({
    super.key,
    required this.targetUids,
    this.initialPermissions,
    this.initialIsSuper = false,
  });

  @override
  State<AdminPermissionsScreen> createState() => _AdminPermissionsScreenState();
}

class _AdminPermissionsScreenState extends State<AdminPermissionsScreen> {
  final AdminService _adminService = AdminService();
  List<String> _myPermissions = [];
  final List<String> _selectedPermissions = [];
  bool _isSuper = false;
  String _mode = "SET"; // SET, GRANT, REVOKE

  final Map<String, String> _availablePermissions = {
    'manage_admins': 'Manage App Admins',
    'moderate_users': 'Global User Moderation',
    'manage_all_quizzes': 'Master Quiz Control',
    'view_audit_logs': 'View Audit Logs',
    'manage_app_settings': 'Manage App Settings',
    'bypass_ai_quotas': 'Bypass AI Quotas',
    'manage_collaborators': 'Manage Quiz Collaborators',
  };

  @override
  void initState() {
    super.initState();
    _isSuper = widget.initialIsSuper;
    if (widget.initialPermissions != null) {
      _selectedPermissions.addAll(widget.initialPermissions!);
    }
    _fetchMyPermissions();
  }

  Future<void> _fetchMyPermissions() async {
    if (mounted) setState(() => _myPermissions = global.adminPermissions);
  }

  @override
  Widget build(BuildContext context) {
    final isBulk = widget.targetUids.length > 1;

    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          isBulk ? "Bulk Permissions" : "Manage Permissions",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 24),
            if (isBulk) ...[
              _buildSectionHeader("Update Mode"),
              const SizedBox(height: 12),
              _buildModeSelector(),
              const SizedBox(height: 24),
            ],
            if (global.adminLevel == 0) ...[
              _buildSectionHeader("Account Level"),
              const SizedBox(height: 12),
              _buildSuperToggle(),
              const SizedBox(height: 24),
            ],
            _buildSectionHeader("Permissions"),
            const SizedBox(height: 12),
            ..._availablePermissions.entries.map((entry) => _buildPermissionTile(entry)),
            const SizedBox(height: 40),
            _buildApplyButton(),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: global.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.targetUids.length == 1 ? "Target User" : "Target Users (${widget.targetUids.length})",
            style: const TextStyle(color: global.labelColor, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.targetUids.join(", "),
            style: const TextStyle(color: global.valueColor, fontSize: 13, fontFamily: 'monospace'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.poppins(
        color: global.primaryAccent,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: global.borderColor),
      ),
      child: Row(
        children: [
          _buildModeButton("SET", "Overwrite All"),
          _buildModeButton("GRANT", "Add Specific"),
          _buildModeButton("REVOKE", "Remove Specific"),
        ],
      ),
    );
  }

  Widget _buildModeButton(String mode, String label) {
    final isSelected = _mode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _mode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? global.primaryAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.black : global.labelColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuperToggle() {
    return Container(
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: global.borderColor),
      ),
      child: SwitchListTile(
        title: const Text("Super Admin", style: TextStyle(color: global.valueColor)),
        subtitle: const Text("Grant full system-wide access", style: TextStyle(color: global.labelColor, fontSize: 12)),
        value: _isSuper,
        activeColor: global.primaryAccent,
        onChanged: (val) => setState(() => _isSuper = val),
      ),
    );
  }

  Widget _buildPermissionTile(MapEntry<String, String> entry) {
    final bool hasPermissionToGrant = global.adminLevel == 0 || _myPermissions.contains(entry.key);
    final isSelected = _isSuper || _selectedPermissions.contains(entry.key);

    return Opacity(
      opacity: hasPermissionToGrant ? 1.0 : 0.4,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: global.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? global.primaryAccent.withOpacity(0.5) : global.borderColor,
          ),
        ),
        child: CheckboxListTile(
          title: Text(entry.value, style: const TextStyle(color: global.valueColor, fontSize: 14)),
          value: isSelected,
          activeColor: global.primaryAccent,
          onChanged: (_isSuper || !hasPermissionToGrant)
              ? null
              : (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedPermissions.add(entry.key);
                    } else {
                      _selectedPermissions.remove(entry.key);
                    }
                  });
                },
        ),
      ),
    );
  }

  Widget _buildApplyButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: global.primaryAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _applyChanges,
        child: Text(
          "APPLY TO ${widget.targetUids.length} USERS",
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
      ),
    );
  }

  Future<void> _applyChanges() async {
    try {
      final actorUid = FirebaseAuth.instance.currentUser!.uid;

      if (widget.targetUids.length == 1 && _mode == "SET") {
        // Use standard single update if only one user and in SET mode
        await _adminService.addOrUpdateAdmin(
          targetUid: widget.targetUids.first,
          selectedPermissions: _isSuper ? AdminService.allPermissions : _selectedPermissions,
          actorUid: actorUid,
          makeSuper: _isSuper,
        );
      } else {
        // Use bulk update
        await _adminService.bulkUpdateAdminPermissions(
          targetUids: widget.targetUids,
          actorUid: actorUid,
          setPermissions: _mode == "SET" ? (_isSuper ? AdminService.allPermissions : _selectedPermissions) : null,
          grantPermissions: _mode == "GRANT" ? _selectedPermissions : null,
          revokePermissions: _mode == "REVOKE" ? _selectedPermissions : null,
          makeSuper: _isSuper,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Permissions updated successfully")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: global.errorColor),
        );
      }
    }
  }
}
