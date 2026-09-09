import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/custom_cache_manager.dart';
import 'package:thinkfast/services/local_cache_service.dart';
import 'package:thinkfast/utils/global.dart' as global;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? _user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;
  int _cacheLimitMb = 500;

  @override
  void initState() {
    super.initState();
    _loadCacheSettings();
  }

  Future<void> _loadCacheSettings() async {
    final limit = await LocalCacheService().getCacheLimit();
    setState(() => _cacheLimitMb = limit);
  }

  void _updateCacheLimit(double value) async {
    final int newLimit = value.toInt();
    setState(() => _cacheLimitMb = newLimit);
    await LocalCacheService().saveCacheLimit(newLimit);
    CustomCacheManager.refreshConfig();
  }

  void _clearCache() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    try {
      final cache = await CustomCacheManager.getInstance();
      await cache.emptyCache();
      messenger.showSnackBar(
        const SnackBar(content: Text("Media cache cleared successfully!")),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("Failed to clear cache: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshUser() async {
    await _user?.reload();
    setState(() {
      _user = FirebaseAuth.instance.currentUser;
    });
  }

  void _linkGoogle() async {
    setState(() => _isLoading = true);
    try {
      await global.auth.linkWithGoogle();
      await _refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google account linked successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Linking failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _unlinkProvider(String providerId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: global.cardColor,
        title: const Text(
          "Unlink Account?",
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          "Are you sure you want to remove ${providerId == 'password' ? 'Email/Password' : 'Google'} as a login method?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("UNLINK"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await global.auth.unlinkProvider(providerId);
      await _refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${providerId == 'password' ? 'Email' : 'Google'} unlinked successfully!",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = "Unlinking failed: $e";
        if (e == 'cannot_unlink_last_provider') {
          msg = "You cannot unlink your only login method.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLinkEmailDialog() {
    final TextEditingController emailController = TextEditingController(
      text: _user?.email,
    );
    final TextEditingController passwordController = TextEditingController();
    bool isPending = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: global.cardColor,
          title: Text(
            "Add Email Login",
            style: GoogleFonts.poppins(color: global.valueColor),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Set a password to enable logging in with your email address.",
                style: GoogleFonts.poppins(
                  color: global.labelColor,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                readOnly: true,
                style: const TextStyle(color: global.valueColor),
                decoration: const InputDecoration(
                  labelText: "Email",
                  labelStyle: TextStyle(color: global.labelColor),
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: global.primaryAccent,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: global.valueColor),
                decoration: const InputDecoration(
                  labelText: "New Password",
                  labelStyle: TextStyle(color: global.labelColor),
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: global.primaryAccent,
                  ),
                ),
              ),
              if (isPending) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isPending ? null : () => Navigator.pop(context),
              child: const Text("CANCEL"),
            ),
            ElevatedButton(
              onPressed: isPending
                  ? null
                  : () async {
                      final password = passwordController.text.trim();
                      if (password.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Password must be at least 6 characters",
                            ),
                          ),
                        );
                        return;
                      }

                      setModalState(() => isPending = true);

                      try {
                        await global.auth.linkWithEmailPassword(
                          emailController.text.trim(),
                          password,
                        );
                        await _refreshUser();
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Email login enabled successfully!",
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setModalState(() => isPending = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Failed to link email: $e"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: const Text("ENABLE EMAIL LOGIN"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        title: Text(
          "SETTINGS",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: global.primaryAccent),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_user != null) ...[
                      _buildSectionHeader("Account"),
                      _buildSettingsTile(
                        icon: Icons.account_circle_outlined,
                        title: "Profile",
                        subtitle: "Manage your personal information",
                        onTap: () => Navigator.pushNamed(context, "/profile"),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionHeader("Login & Security"),
                      _buildProviderTile(
                        icon: Icons.email_outlined,
                        title: "Email & Password",
                        isLinked:
                            _user?.providerData.any(
                              (p) => p.providerId == 'password',
                            ) ??
                            false,
                        onLink: _showLinkEmailDialog,
                        onUnlink: () => _unlinkProvider('password'),
                      ),
                      const SizedBox(height: 12),
                      _buildProviderTile(
                        icon: Icons.account_circle_outlined,
                        title: "Google Account",
                        isLinked:
                            _user?.providerData.any(
                              (p) => p.providerId == 'google.com',
                            ) ??
                            false,
                        onLink: _linkGoogle,
                        onUnlink: () => _unlinkProvider('google.com'),
                      ),
                      const SizedBox(height: 24),
                    ],
                    _buildSectionHeader("App Performance"),
                    _buildCacheSettingsTile(),
                    const SizedBox(height: 24),
                    _buildSectionHeader("Information"),
                    _buildSettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: "About Us",
                      subtitle: "Learn more about ThinkFast",
                      onTap: () => Navigator.pushNamed(context, "/About Us"),
                    ),
                    _buildSettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: "Privacy Policy",
                      subtitle: "Read our privacy guidelines",
                      onTap: () =>
                          Navigator.pushNamed(context, "/Privacy Policy"),
                    ),
                    const SizedBox(height: 24),
                    if (_user != null) ...[
                      _buildSectionHeader("Session"),
                      _buildSettingsTile(
                        icon: Icons.logout_rounded,
                        title: "Logout",
                        subtitle: "Sign out of your account",
                        textColor: global.errorColor,
                        onTap: () async {
                          await global.auth.logout();
                          if (context.mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/login',
                              (route) => false,
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          color: global.primaryAccent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildCacheSettingsTile() {
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
          Row(
            children: [
              const Icon(Icons.storage_rounded, color: global.primaryAccent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Media Cache Limit",
                      style: TextStyle(
                        color: global.valueColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      "Current: $_cacheLimitMb MB",
                      style: const TextStyle(
                        color: global.labelColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _clearCache,
                child: const Text(
                  "CLEAR",
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Slider(
            value: _cacheLimitMb.toDouble(),
            min: 100,
            max: 2000,
            divisions: 19,
            activeColor: global.primaryAccent,
            inactiveColor: global.borderColor,
            label: "$_cacheLimitMb MB",
            onChanged: _updateCacheLimit,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "100 MB",
                style: TextStyle(color: global.labelColor, fontSize: 10),
              ),
              const Text(
                "2 GB",
                style: TextStyle(color: global.labelColor, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: global.borderColor),
      ),
      child: Material(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: global.primaryAccent),
          title: Text(
            title,
            style: TextStyle(
              color: textColor ?? global.valueColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: global.labelColor, fontSize: 12),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: global.labelColor,
          ),
        ),
      ),
    );
  }

  Widget _buildProviderTile({
    required IconData icon,
    required String title,
    required bool isLinked,
    required VoidCallback onLink,
    required VoidCallback onUnlink,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLinked
              ? global.primaryAccent.withValues(alpha: 0.5)
              : global.borderColor,
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isLinked ? global.primaryAccent : global.labelColor,
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: global.valueColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          isLinked ? "Connected" : "Not connected",
          style: GoogleFonts.poppins(
            color: isLinked ? global.primaryAccent : global.labelColor,
            fontSize: 12,
          ),
        ),
        trailing: isLinked
            ? TextButton(
                onPressed: onUnlink,
                child: const Text(
                  "UNLINK",
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              )
            : ElevatedButton(
                onPressed: onLink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: global.primaryAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(80, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "LINK",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
      ),
    );
  }
}
