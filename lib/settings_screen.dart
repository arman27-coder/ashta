import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseService _db = DatabaseService();
  bool _isResetting = false;

  void _confirmReset() {
    final textCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "वार्षिक रजा रीसेट करा",
          style: TextStyle(color: Colors.red),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "चेतावणी: यामुळे प्रत्येक कर्मचाऱ्याची रजा शिल्लक ८.० दिवसांवर रीसेट होईल. ही कृती पूर्ववत केली जाऊ शकत नाही.",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text("पुष्टी करण्यासाठी खाली 'RESET' टाइप करा:"),
            const SizedBox(height: 8),
            TextField(
              controller: textCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "RESET",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "रद्द करा",
              style: TextStyle(color: Colors.blueGrey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (textCtrl.text.trim() == "RESET") {
                Navigator.pop(ctx);
                _performReset();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "तुम्हाला पुष्टी करण्यासाठी RESET टाइप करावे लागेल.",
                    ),
                  ),
                );
              }
            },
            child: const Text("रीसेट करा"),
          ),
        ],
      ),
    );
  }

  Future<void> _performReset() async {
    setState(() => _isResetting = true);
    try {
      await _db.resetAllYearlyLeaves(defaultBalance: 8.0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "सर्वांची रजा शिल्लक ८.० दिवस यशस्वीरित्या रीसेट झाली",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("त्रुटी: $e"), backgroundColor: Colors.red),
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
        title: const Text("लॉग आउट"),
        content: const Text(
          "तुम्हाला नक्की ॲडमिन पॅनेलमधून बाहेर पडायचे आहे का?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "रद्द करा",
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
            label: const Text("लॉग आउट"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "सेटिंग्ज",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C3E50),
        elevation: 0,
      ),
      body: _isResetting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("सर्व कर्मचाऱ्यांची रजा रीसेट करत आहे..."),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  "सिस्टम कृती",
                  style: TextStyle(
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
                    title: const Text(
                      "वार्षिक रजा रीसेट करा",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text("सर्वांची रजा शिल्लक ८.० दिवस करा"),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _confirmReset,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "खाते",
                  style: TextStyle(
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
                    title: const Text(
                      "लॉग आउट",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text("ॲडमिन पॅनेलमधून बाहेर पडा"),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _confirmLogout,
                  ),
                ),
              ],
            ),
    );
  }
}
