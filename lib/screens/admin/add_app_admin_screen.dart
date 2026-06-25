import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/utils/global.dart' as global;
import 'admin_permissions_screen.dart';

class AddAppAdminScreen extends StatefulWidget {
  const AddAppAdminScreen({super.key});

  @override
  State<AddAppAdminScreen> createState() => _AddAppAdminScreenState();
}

class _AddAppAdminScreenState extends State<AddAppAdminScreen> {
  final TextEditingController _uidController = TextEditingController();

  void _onNext() {
    final input = _uidController.text.trim();
    if (input.isNotEmpty) {
      final uids = input
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminPermissionsScreen(targetUids: uids),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Add New App Admins",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: global.valueColor,
          ),
        ),
        iconTheme: const IconThemeData(color: global.valueColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "User UIDs",
              style: GoogleFonts.poppins(
                color: global.primaryAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _uidController,
              autofocus: true,
              style: const TextStyle(color: global.valueColor),
              decoration: InputDecoration(
                hintText: "Enter UIDs, comma separated",
                hintStyle: const TextStyle(color: global.labelColor),
                filled: true,
                fillColor: global.cardColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: global.borderColor),
                ),
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
            const SizedBox(height: 16),
            Text(
              "UIDs can be found in User Management or Firebase Console.",
              style: GoogleFonts.poppins(
                color: global.labelColor,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: global.primaryAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  "NEXT: CONFIGURE PERMISSIONS",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}
