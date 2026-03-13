import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_constants.dart';
import 'database_service.dart';
import 'app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseService _db = DatabaseService();
  bool _isResetting = false;
  bool _isAdmin = false;
  bool _isLoadingAdmin = true;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _db.isCurrentUserAdmin();
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
        _isLoadingAdmin = false;
      });
    }
  }

  void _confirmReset() {
    final textCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          AppLocalizations.get('reset_leaves'),
          style: const TextStyle(color: Colors.red),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Warning: This will reset every employee's leave balance to ${AppConstants.defaultAnnualLeaves} days. This action cannot be undone.",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              "Type '${AppConstants.resetConfirmationText}' below to confirm:",
            ),
            const SizedBox(height: 8),
            TextField(
              controller: textCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: AppConstants.resetConfirmationText,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.blueGrey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (textCtrl.text.trim() == AppConstants.resetConfirmationText) {
                Navigator.pop(ctx);
                _performReset();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("You must type exactly to confirm."),
                  ),
                );
              }
            },
            child: const Text("Reset"),
          ),
        ],
      ),
    );
  }

  Future<void> _performReset() async {
    setState(() => _isResetting = true);
    try {
      await _db.resetAllYearlyLeaves(
        defaultBalance: AppConstants.defaultAnnualLeaves,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Balance reset to ${AppConstants.defaultAnnualLeaves} days",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.get('log_out')),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.blueGrey),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout),
            label: Text(AppLocalizations.get('log_out')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.get('settings'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
      ),
      body: _isResetting || _isLoadingAdmin
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  AppLocalizations.get('preferences'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.language, color: Colors.blue),
                    ),
                    title: Text(
                      AppLocalizations.get('app_language'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: DropdownButton<String>(
                      value: AppLocalizations.currentLanguage.value,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text("English")),
                        DropdownMenuItem(
                          value: 'mr',
                          child: Text("मराठी (Marathi)"),
                        ),
                      ],
                      onChanged: (String? newValue) async {
                        if (newValue != null) {
                          setState(() {
                            AppLocalizations.currentLanguage.value = newValue;
                          });
                          await AppLocalizations.changeLanguage(newValue);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (_isAdmin) ...[
                  Text(
                    AppLocalizations.get('system_actions'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.red.shade200),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.refresh, color: Colors.red),
                      ),
                      title: Text(
                        AppLocalizations.get('reset_leaves'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(AppLocalizations.get('reset_leaves_sub')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _confirmReset,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                Text(
                  AppLocalizations.get('account'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.logout, color: Colors.blueGrey),
                    ),
                    title: Text(
                      AppLocalizations.get('log_out'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(AppLocalizations.get('log_out_sub')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _confirmLogout,
                  ),
                ),
              ],
            ),
    );
  }
}
