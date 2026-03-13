import 'package:flutter/material.dart';
import 'app_localizations.dart';

class AppColors {
  static const Color background = Color(0xFFF8F9FA);
  static const Color primaryText = Color(0xFF2C3E50);
}

class AppConstants {
  // Application Details
  static const String appName = 'ASHTA';
  static const String appSubtitle = 'Casual Leave Ledger';

  // Organization Details
  static const String orgName = 'Zilha Parishad, Dharashiv';
  static const String subOrgName = 'Panchayat Samiti, Bhoom';

  // Leave Configuration
  static const double defaultAnnualLeaves = 8.0;
  static const String resetConfirmationText = 'RESET';

  // Refined Department Constants
  static const String dept1 = 'Panchayat Samiti';
  static const String dept2 = 'Grampanchayat';

  static const List<String> allDepartments = [dept1, dept2];

  static const List<String> months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  // Helper to handle old database values seamlessly
  static String getNormalizedDeptName(String? rawDept) {
    if (rawDept == 'Panchayat Samiti' || rawDept == 'P.S') {
      return dept1;
    }

    if (rawDept == 'Unassigned' || rawDept == null || rawDept.isEmpty) {
      return 'Unassigned';
    }
    return rawDept;
  }

  // Helper to translate Department Names for UI display
  static String getLocalizedDeptName(String? rawDept) {
    final normalized = getNormalizedDeptName(rawDept);
    if (normalized == dept1) return AppLocalizations.get('dept1');
    if (normalized == dept2) return AppLocalizations.get('dept2');
    return normalized;
  }

  // Dynamic Header Helper
  static String getSubOrgName(String? department) {
    final normalized = getNormalizedDeptName(department);
    if (allDepartments.contains(normalized)) {
      return getLocalizedDeptName(normalized);
    }
    return AppLocalizations.get('sub_org_name');
  }

  // Short Name helper for UI Tables
  static String getShortDeptName(String? department) {
    return getLocalizedDeptName(department);
  }

  // RBAC Helper - Now completely relies on Firebase Firestore rules
  static List<String>? getAllowedDepartments() {
    return allDepartments;
  }

  // Shared Month-Year Formatter
  static String getCurrentMonthYear() {
    final now = DateTime.now();
    return "${months[now.month - 1]} ${now.year}";
  }

  // Shared WhatsApp Message Template
  static String buildWhatsAppMessage(
    String empName,
    double daysUsed,
    double newBalance,
  ) {
    return "Hello $empName,\n\nYour leave for *$daysUsed days* has been approved and recorded.\nYour remaining leave balance is *$newBalance days*.\n\nThank you,\nAdmin";
  }
}
