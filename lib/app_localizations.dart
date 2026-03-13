import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocalizations {
  static ValueNotifier<String> currentLanguage = ValueNotifier<String>('en');

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    currentLanguage.value = prefs.getString('app_lang') ?? 'en';
  }

  static Future<void> changeLanguage(String lang) async {
    currentLanguage.value = lang; // Change instantly for UI update
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_lang', lang);
  }

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'org_name': 'Zilha Parishad, Dharashiv',
      'sub_org_name': 'Panchayat Samiti, Bhoom',
      'dept1': 'Panchayat Samiti',
      'dept2': 'Grampanchayat',
      'employee_list': 'Employee List',
      'search_hint': 'Search by name or designation...',
      'all_departments': 'All Departments',
      'no_employees': 'No employees added yet.',
      'no_matches': 'No employees match your selection.',
      'add_new': 'Add New',
      'settings': 'Settings',
      'preferences': 'Preferences',
      'app_language': 'App Language',
      'system_actions': 'System Actions',
      'reset_leaves': 'Reset Annual Leaves',
      'reset_leaves_sub': 'Set everyone\'s leave balance to default',
      'account': 'Account',
      'log_out': 'Log Out',
      'log_out_sub': 'Exit the admin panel',
      'full_name': 'Full Name',
      'designation': 'Designation',
      'department': 'Department',
      'total_leaves': 'Total Leaves',
      'used_leaves': 'Used Leaves',
      'balance': 'Balance',
      'action': 'Action',
      'leave_ledger': 'Leave Ledger',
      'record_leave': 'Record Leave',
      'total_balance': 'Total Balance',
      'from': 'From',
      'to': 'To',
      'used_days': 'Used Days',
      'reason': 'Reason',
      'closing_balance': 'Closing Balance',
      'opening_balance': 'Opening Balance',
      'sr_no': 'Sr.No',
      'days': 'Days',
      'month': 'Month',
      'name': 'Name',
    },
    'mr': {
      'org_name': 'जिल्हा परिषद, धाराशिव',
      'sub_org_name': 'पंचायत समिती, भूम',
      'dept1': 'पंचायत समिती',
      'dept2': 'ग्रामपंचायत',
      'employee_list': 'कर्मचारी यादी',
      'search_hint': 'नाव किंवा पदनामाने शोधा...',
      'all_departments': 'सर्व विभाग',
      'no_employees': 'अद्याप कोणतेही कर्मचारी जोडलेले नाहीत.',
      'no_matches': 'तुमच्या निवडीशी जुळणारे कर्मचारी नाहीत.',
      'add_new': 'नवीन जोडा',
      'settings': 'सेटिंग्ज',
      'preferences': 'प्राधान्ये',
      'app_language': 'ॲपची भाषा',
      'system_actions': 'सिस्टम कृती',
      'reset_leaves': 'वार्षिक सुट्ट्या रीसेट करा',
      'reset_leaves_sub': 'सर्वांच्या सुट्ट्यांची शिल्लक डीफॉल्टवर सेट करा',
      'account': 'खाते',
      'log_out': 'बाहेर पडा',
      'log_out_sub': 'प्रशासक पॅनेलमधून बाहेर पडा',
      'full_name': 'पूर्ण नाव',
      'designation': 'पद',
      'department': 'विभाग',
      'total_leaves': 'एकूण रजा',
      'used_leaves': 'वापरलेल्या रजा',
      'balance': 'शिल्लक',
      'action': 'कृती',
      'leave_ledger': 'रजा नोंदवही',
      'record_leave': 'सुट्टी नोंदवा',
      'total_balance': 'एकूण शिल्लक',
      'from': 'पासून',
      'to': 'पर्यंत',
      'used_days': 'घेतलेले दिवस',
      'reason': 'कारण',
      'closing_balance': 'अंतिम शिल्लक',
      'opening_balance': 'प्रारंभिक शिल्लक',
      'sr_no': 'अ.क्र.',
      'days': 'दिवस',
      'month': 'महिना',
      'name': 'नाव',
    },
  };

  static String get(String key) {
    return _localizedValues[currentLanguage.value]?[key] ?? key;
  }
}
