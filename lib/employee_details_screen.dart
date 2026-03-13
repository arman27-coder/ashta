import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'app_constants.dart';
import 'database_service.dart';
import 'app_localizations.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  final String employeePhone;
  final bool isAdmin;

  const EmployeeDetailsScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.employeePhone,
    required this.isAdmin,
  });

  @override
  State<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen> {
  final DatabaseService _db = DatabaseService();
  bool _isExporting = false;

  void _safeSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  // --- PHOTO UPLOAD LOGIC ---
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (pickedFile != null) {
      setState(() => _isExporting = true);
      try {
        File imageFile = File(pickedFile.path);
        String? downloadUrl = await _db.uploadProfilePhoto(
          widget.employeeId,
          imageFile,
        );

        if (downloadUrl != null) {
          await FirebaseFirestore.instance
              .collection('employees')
              .doc(widget.employeeId)
              .update({'photoUrl': downloadUrl});
          _safeSnackBar(
            "Photo updated successfully!",
            backgroundColor: Colors.green,
          );
        }
      } catch (e) {
        _safeSnackBar("Failed to upload photo.");
      } finally {
        if (mounted) setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _callEmployee(String phoneString) async {
    final String phone = phoneString.replaceAll(RegExp(r'\D'), '');
    final Uri url = Uri.parse("tel:$phone");
    try {
      await launchUrl(url);
    } catch (e) {
      _safeSnackBar("Could not open phone dialer.");
    }
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    final d = ts.toDate();
    return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
  }

  Future<void> _sendWhatsAppMessage(
    double daysUsed,
    double newBalance,
    String empName,
    String empPhone,
  ) async {
    final String message = AppConstants.buildWhatsAppMessage(
      empName,
      daysUsed,
      newBalance,
    );
    String phone = empPhone.replaceAll(RegExp(r'\D'), '');
    if (phone.length == 10) phone = '91$phone';

    final Uri url = Uri.parse(
      "https://wa.me/$phone?text=${Uri.encodeComponent(message)}",
    );

    try {
      final bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw Exception("Could not launch");
    } catch (e) {
      _safeSnackBar("Could not open WhatsApp. Is it installed?");
    }
  }

  void _confirmDeleteLeave(String leaveId, double daysUsed, String reason) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Leave Record"),
        content: Text(
          "Are you sure you want to delete the leave for '$reason'?\n\nDeleting this will add $daysUsed days back to the employee's balance.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.blueGrey),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _db.deleteLeave(widget.employeeId, leaveId, daysUsed);
                _safeSnackBar(
                  "Leave deleted and balance refunded.",
                  backgroundColor: Colors.orange,
                );
              } catch (e) {
                _safeSnackBar("Error: $e", backgroundColor: Colors.red);
              }
            },
            icon: const Icon(Icons.delete),
            label: const Text("Delete & Refund"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditEmployeeSheet(
    String currentName,
    String currentDesignation,
    String currentPhone,
    String currentDepartment,
    String? currentPhotoUrl,
  ) {
    final nameCtrl = TextEditingController(text: currentName);
    final desigCtrl = TextEditingController(text: currentDesignation);
    final phoneCtrl = TextEditingController(text: currentPhone);

    String selectedDept = AppConstants.getNormalizedDeptName(currentDepartment);
    List<String> dropdownOptions = AppConstants.allDepartments;

    if (!dropdownOptions.contains(selectedDept)) {
      selectedDept = dropdownOptions.first;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Edit Employee Details",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.get('full_name'),
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: desigCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.get('designation'),
                    prefixIcon: const Icon(Icons.work_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedDept,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.get('department'),
                    prefixIcon: const Icon(Icons.domain),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: dropdownOptions
                      .map(
                        (dept) => DropdownMenuItem(
                          value: dept,
                          child: Text(AppConstants.getLocalizedDeptName(dept)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setSheetState(() => selectedDept = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: "WhatsApp Number",
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
                    await _db.updateEmployee(
                      widget.employeeId,
                      nameCtrl.text.trim(),
                      desigCtrl.text.trim(),
                      phoneCtrl.text.trim(),
                      selectedDept,
                      photoUrl: currentPhotoUrl,
                    );
                    if (mounted) {
                      Navigator.pop(ctx);
                      _safeSnackBar(
                        "Details updated successfully!",
                        backgroundColor: Colors.green,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Save Changes",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _exportToPDF() async {
    try {
      setState(() => _isExporting = true);

      final empDoc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .get();
      final currentName = empDoc.data()?['name'] ?? widget.employeeName;
      final designation = empDoc.data()?['designation'] ?? '-';
      final rawDept = empDoc.data()?['department']?.toString();
      final department = AppConstants.getNormalizedDeptName(rawDept);

      final leavesQuery = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .collection('leaves')
          .orderBy('timestamp', descending: false)
          .get();

      pw.Font ttf;
      pw.Font ttfBold;
      try {
        ttf = await PdfGoogleFonts.notoSansDevanagariRegular();
        ttfBold = await PdfGoogleFonts.notoSansDevanagariBold();
      } catch (e) {
        ttf = pw.Font.helvetica();
        ttfBold = pw.Font.helveticaBold();
      }

      final pdf = pw.Document();
      final monthYear = AppConstants.getCurrentMonthYear();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Center(
                child: pw.Text(
                  AppLocalizations.get('org_name'),
                  style: pw.TextStyle(
                    font: ttfBold,
                    fontSize: 22,
                    color: PdfColors.blue900,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  AppLocalizations.get('sub_org_name'),
                  style: pw.TextStyle(
                    font: ttfBold,
                    fontSize: 18,
                    color: PdfColors.blue800,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  '${AppLocalizations.get('department')}: ${AppConstants.getSubOrgName(department)}',
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 14,
                    color: PdfColors.grey800,
                  ),
                ),
              ),
              pw.SizedBox(height: 25),

              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.blueGrey300,
                    width: 1.5,
                  ),
                  borderRadius: pw.BorderRadius.circular(8),
                  color: PdfColors.blue50,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          AppLocalizations.get('leave_ledger'),
                          style: pw.TextStyle(
                            font: ttfBold,
                            fontSize: 18,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          '${AppLocalizations.get('name')}: $currentName',
                          style: pw.TextStyle(font: ttfBold, fontSize: 14),
                        ),
                        pw.Text(
                          '${AppLocalizations.get('designation')}: $designation',
                          style: pw.TextStyle(font: ttf, fontSize: 13),
                        ),
                      ],
                    ),
                    pw.Text(
                      '${AppLocalizations.get('month')} - $monthYear',
                      style: pw.TextStyle(
                        font: ttfBold,
                        fontSize: 13,
                        color: PdfColors.blueGrey,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              pw.TableHelper.fromTextArray(
                context: context,
                cellPadding: const pw.EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 4,
                ),
                cellStyle: pw.TextStyle(font: ttf, fontSize: 10),
                headerStyle: pw.TextStyle(
                  font: ttfBold,
                  fontSize: 11,
                  color: PdfColors.blue900,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blue100,
                ),
                cellDecoration: (index, data, rowNum) => pw.BoxDecoration(
                  color: rowNum % 2 == 1 ? PdfColors.grey100 : PdfColors.white,
                ),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                  ),
                ),
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.center,
                  4: pw.Alignment.center,
                  5: pw.Alignment.centerLeft,
                  6: pw.Alignment.center,
                },
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FixedColumnWidth(70),
                  2: const pw.FixedColumnWidth(60),
                  3: const pw.FixedColumnWidth(60),
                  4: const pw.FixedColumnWidth(40),
                  5: const pw.FlexColumnWidth(2.5),
                  6: const pw.FixedColumnWidth(70),
                },
                headers: [
                  AppLocalizations.get('sr_no'),
                  AppLocalizations.get('opening_balance'),
                  AppLocalizations.get('from'),
                  AppLocalizations.get('to'),
                  AppLocalizations.get('days'),
                  AppLocalizations.get('reason'),
                  AppLocalizations.get('closing_balance'),
                ],
                data: leavesQuery.docs.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final data = entry.value.data();
                  final fDate =
                      (data['fromDate'] ?? data['date']) as Timestamp?;
                  final tDate = (data['toDate'] ?? data['date']) as Timestamp?;
                  return [
                    index.toString(),
                    data['previousBalance']?.toString() ?? '-',
                    _formatDate(fDate),
                    _formatDate(tDate),
                    data['daysUsed']?.toString() ?? '-',
                    data['reason'] ?? '',
                    data['newBalance']?.toString() ?? '-',
                  ];
                }).toList(),
              ),
            ],
          ),
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'Leave_Ledger_${currentName.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      _safeSnackBar("Error generating PDF: $e");
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportToExcel() async {
    try {
      setState(() => _isExporting = true);

      final empDoc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .get();
      final currentName = empDoc.data()?['name'] ?? widget.employeeName;
      final designation = empDoc.data()?['designation'] ?? '-';
      final rawDept = empDoc.data()?['department']?.toString();
      final department = AppConstants.getNormalizedDeptName(rawDept);

      final leavesQuery = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .collection('leaves')
          .orderBy('timestamp', descending: false)
          .get();

      var excel = Excel.createExcel();
      excel.rename(excel.getDefaultSheet() ?? 'Sheet1', 'Leave Ledger');
      Sheet sheetObject = excel['Leave Ledger'];

      sheetObject.setColumnWidth(0, 6.0);
      sheetObject.setColumnWidth(1, 15.0);
      sheetObject.setColumnWidth(2, 12.0);
      sheetObject.setColumnWidth(3, 12.0);
      sheetObject.setColumnWidth(4, 10.0);
      sheetObject.setColumnWidth(5, 30.0);
      sheetObject.setColumnWidth(6, 15.0);

      final titleStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        fontSize: 16,
      );
      final subTitleStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        fontSize: 14,
      );
      final headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
      final normalCenter = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
      final normalLeft = CellStyle(
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );
      final labelStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Right,
      );
      final valueStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Left,
      );

      void addMergeCentered(
        String text,
        int rowIndex,
        CellStyle style,
        int maxCol,
      ) {
        sheetObject.appendRow([TextCellValue(text)]);
        sheetObject.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
          CellIndex.indexByColumnRow(columnIndex: maxCol, rowIndex: rowIndex),
        );
        sheetObject
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 0,
                    rowIndex: rowIndex,
                  ),
                )
                .cellStyle =
            style;
      }

      final monthYear = AppConstants.getCurrentMonthYear();

      addMergeCentered(AppLocalizations.get('org_name'), 0, titleStyle, 6);
      addMergeCentered(
        AppLocalizations.get('sub_org_name'),
        1,
        subTitleStyle,
        6,
      );
      addMergeCentered(
        '${AppLocalizations.get('department')}: ${AppConstants.getSubOrgName(department)}',
        2,
        subTitleStyle,
        6,
      );
      addMergeCentered(
        '${AppLocalizations.get('leave_ledger')} - ${AppLocalizations.get('month')}: $monthYear',
        3,
        subTitleStyle,
        6,
      );
      sheetObject.appendRow([TextCellValue('')]);

      sheetObject.appendRow([
        TextCellValue('${AppLocalizations.get('name')}:'),
        TextCellValue(currentName),
      ]);
      sheetObject
              .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 5))
              .cellStyle =
          labelStyle;
      sheetObject
              .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 5))
              .cellStyle =
          valueStyle;

      sheetObject.appendRow([
        TextCellValue('${AppLocalizations.get('designation')}:'),
        TextCellValue(designation),
      ]);
      sheetObject
              .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 6))
              .cellStyle =
          labelStyle;
      sheetObject
              .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 6))
              .cellStyle =
          valueStyle;
      sheetObject.appendRow([TextCellValue('')]);

      sheetObject.appendRow([
        TextCellValue(AppLocalizations.get('sr_no')),
        TextCellValue(AppLocalizations.get('opening_balance')),
        TextCellValue(AppLocalizations.get('from')),
        TextCellValue(AppLocalizations.get('to')),
        TextCellValue(AppLocalizations.get('days')),
        TextCellValue(AppLocalizations.get('reason')),
        TextCellValue(AppLocalizations.get('closing_balance')),
      ]);
      for (int i = 0; i <= 6; i++) {
        sheetObject
                .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 8))
                .cellStyle =
            headerStyle;
      }

      int currentRow = 9;
      int srNo = 1;
      for (var doc in leavesQuery.docs) {
        final data = doc.data();
        final fDate = (data['fromDate'] ?? data['date']) as Timestamp?;
        final tDate = (data['toDate'] ?? data['date']) as Timestamp?;

        sheetObject.appendRow([
          TextCellValue((srNo++).toString()),
          TextCellValue(data['previousBalance']?.toString() ?? '-'),
          TextCellValue(_formatDate(fDate)),
          TextCellValue(_formatDate(tDate)),
          TextCellValue(data['daysUsed']?.toString() ?? '-'),
          TextCellValue(data['reason'] ?? ''),
          TextCellValue(data['newBalance']?.toString() ?? '-'),
        ]);

        for (int i = 0; i <= 6; i++) {
          sheetObject
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: i,
                  rowIndex: currentRow,
                ),
              )
              .cellStyle = (i == 5)
              ? normalLeft
              : normalCenter;
        }
        currentRow++;
      }

      var fileBytes = excel.save();
      if (fileBytes != null) {
        var directory = await getTemporaryDirectory();
        String filePath =
            '${directory.path}/Leave_Ledger_${currentName.replaceAll(' ', '_')}.xlsx';
        File file = File(filePath);
        await file.writeAsBytes(fileBytes);
        await Share.shareXFiles([
          XFile(filePath),
        ], text: 'Leave Ledger - $currentName');
      }
    } catch (e) {
      _safeSnackBar("Error generating Excel: $e");
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showRecordLeaveSheet(
    double currentBalance,
    String empName,
    String empPhone,
  ) {
    DateTime fromDate = DateTime.now();
    DateTime toDate = DateTime.now();
    bool isHalfDay = false;
    final reasonCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          double calculateDays() {
            final start = DateTime(fromDate.year, fromDate.month, fromDate.day);
            final end = DateTime(toDate.year, toDate.month, toDate.day);
            int days = end.difference(start).inDays + 1;
            double total = days.toDouble();
            if (isHalfDay) total -= 0.5;
            return total > 0 ? total : 0;
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppLocalizations.get('record_leave'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: fromDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (d != null) {
                            setSheetState(() {
                              fromDate = d;
                              if (toDate.isBefore(fromDate)) toDate = fromDate;
                            });
                          }
                        },
                        icon: const Icon(Icons.date_range, size: 18),
                        label: Text(
                          "${AppLocalizations.get('from')}: ${fromDate.day.toString().padLeft(2, '0')}/${fromDate.month.toString().padLeft(2, '0')}/${fromDate.year}",
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: toDate,
                            firstDate: fromDate,
                            lastDate: DateTime(2030),
                          );
                          if (d != null) setSheetState(() => toDate = d);
                        },
                        icon: const Icon(Icons.date_range, size: 18),
                        label: Text(
                          "${AppLocalizations.get('to')}: ${toDate.day.toString().padLeft(2, '0')}/${toDate.month.toString().padLeft(2, '0')}/${toDate.year}",
                        ),
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  title: const Text("+ Half Day (0.5 deducted)"),
                  value: isHalfDay,
                  activeColor: Colors.blue,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) =>
                      setSheetState(() => isHalfDay = val ?? false),
                ),
                TextField(
                  controller: reasonCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.get('reason'),
                    prefixIcon: const Icon(Icons.edit_note),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Total days to deduct: ${calculateDays()}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final days = calculateDays();
                          final reason = reasonCtrl.text.trim();

                          if (days <= 0 || reason.isEmpty) {
                            _safeSnackBar(
                              "Please provide a reason and valid dates",
                            );
                            return;
                          }
                          if (days > currentBalance) {
                            _safeSnackBar(
                              "Not enough leave! You only have $currentBalance days remaining.",
                              backgroundColor: Colors.red,
                            );
                            return;
                          }

                          setSheetState(() => isSubmitting = true);

                          try {
                            final newBalance = await _db.recordLeave(
                              employeeId: widget.employeeId,
                              daysUsed: days,
                              reason: reason,
                              fromDate: fromDate,
                              toDate: toDate,
                              isHalfDay: isHalfDay,
                            );

                            if (!mounted) return;
                            Navigator.pop(ctx);
                            _safeSnackBar(
                              "Leave recorded successfully!",
                              backgroundColor: Colors.green,
                            );

                            if (mounted) {
                              showDialog(
                                context: context,
                                builder: (dialogCtx) => AlertDialog(
                                  title: const Text("Leave Recorded"),
                                  content: const Text(
                                    "Do you want to notify the employee on WhatsApp?",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogCtx),
                                      child: const Text(
                                        "No",
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(dialogCtx);
                                        _sendWhatsAppMessage(
                                          days,
                                          newBalance,
                                          empName,
                                          empPhone,
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      icon: const Icon(Icons.message),
                                      label: const Text("Send via WhatsApp"),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } catch (e) {
                            _safeSnackBar(
                              "Error: $e",
                              backgroundColor: Colors.red,
                            );
                          } finally {
                            if (ctx.mounted) {
                              setSheetState(() => isSubmitting = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Save",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) {
          return const Scaffold(
            body: Center(child: Text("Employee not found")),
          );
        }

        final currentName = data['name'] ?? widget.employeeName;
        final currentPhone = data['phone'] ?? widget.employeePhone;
        final designation = data['designation'] ?? 'N/A';
        final rawDept = data['department']?.toString();
        final department = AppConstants.getNormalizedDeptName(rawDept);
        final balance = (data['leaveBalance'] ?? 0.0).toDouble();
        final photoUrl = data['photoUrl']?.toString();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              currentName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primaryText,
            elevation: 0,
            actions: [
              if (_isExporting)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else ...[
                if (widget.isAdmin)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blueGrey),
                    tooltip: 'Edit Details',
                    onPressed: () => _showEditEmployeeSheet(
                      currentName,
                      designation,
                      currentPhone,
                      department,
                      photoUrl,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.call, color: Colors.blue),
                  tooltip: 'Call',
                  onPressed: () => _callEmployee(currentPhone),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.picture_as_pdf,
                    color: Colors.redAccent,
                  ),
                  tooltip: 'Download PDF',
                  onPressed: _exportToPDF,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.table_view_outlined,
                    color: Colors.green,
                  ),
                  tooltip: 'Download Excel',
                  onPressed: _exportToExcel,
                ),
              ],
            ],
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade800, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: widget.isAdmin ? _pickAndUploadImage : null,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white24,
                            backgroundImage:
                                (photoUrl != null && photoUrl.isNotEmpty)
                                ? NetworkImage(photoUrl)
                                : null,
                            child: (photoUrl == null || photoUrl.isEmpty)
                                ? const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          if (widget.isAdmin)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.blue,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.get('org_name'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppConstants.getSubOrgName(department),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                designation,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.phone_android,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    currentPhone,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: balance <= 0
                                ? Colors.grey.shade200
                                : balance <= 2
                                ? Colors.red.shade50
                                : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: balance <= 0
                                  ? Colors.grey.shade400
                                  : balance <= 2
                                  ? Colors.red.shade200
                                  : Colors.green.shade200,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                AppLocalizations.get('total_balance'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: balance <= 0
                                      ? Colors.grey.shade700
                                      : balance <= 2
                                      ? Colors.red
                                      : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "$balance",
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: balance <= 0
                                      ? Colors.grey.shade800
                                      : balance <= 2
                                      ? Colors.red.shade700
                                      : Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.isAdmin)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: ElevatedButton.icon(
                        onPressed: () => _showRecordLeaveSheet(
                          balance,
                          currentName,
                          currentPhone,
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(
                          AppLocalizations.get('record_leave'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppLocalizations.get('leave_ledger'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _db.getEmployeeLeavesStream(widget.employeeId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          "No leaves recorded.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    final leaves = snapshot.data!.docs;

                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      physics: const BouncingScrollPhysics(),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                Colors.blueGrey.shade50,
                              ),
                              dataRowMinHeight: 55,
                              dataRowMaxHeight: 55,
                              columnSpacing: 20,
                              horizontalMargin: 20,
                              columns: [
                                DataColumn(
                                  label: Expanded(
                                    child: Center(
                                      child: Text(
                                        AppLocalizations.get('sr_no'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Expanded(
                                    child: Center(
                                      child: Text(
                                        AppLocalizations.get('opening_balance'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Expanded(
                                    child: Center(
                                      child: Text(
                                        AppLocalizations.get('from'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Expanded(
                                    child: Center(
                                      child: Text(
                                        AppLocalizations.get('to'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Expanded(
                                    child: Center(
                                      child: Text(
                                        AppLocalizations.get('used_days'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Expanded(
                                    child: Container(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        AppLocalizations.get('reason'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Expanded(
                                    child: Center(
                                      child: Text(
                                        AppLocalizations.get('closing_balance'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (widget.isAdmin)
                                  DataColumn(
                                    label: Expanded(
                                      child: Center(
                                        child: Text(
                                          AppLocalizations.get('action'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                              rows: leaves.asMap().entries.map((entry) {
                                final index = entry.key + 1;
                                final doc = entry.value;
                                final data = doc.data() as Map<String, dynamic>;
                                final fDate =
                                    (data['fromDate'] ?? data['date'])
                                        as Timestamp?;
                                final tDate =
                                    (data['toDate'] ?? data['date'])
                                        as Timestamp?;

                                return DataRow(
                                  color: WidgetStateProperty.all(
                                    index % 2 == 0
                                        ? Colors.white
                                        : Colors.grey.shade50,
                                  ),
                                  cells: [
                                    DataCell(
                                      Center(child: Text(index.toString())),
                                    ),
                                    DataCell(
                                      Center(
                                        child: Text(
                                          data['previousBalance']?.toString() ??
                                              '-',
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Center(child: Text(_formatDate(fDate))),
                                    ),
                                    DataCell(
                                      Center(child: Text(_formatDate(tDate))),
                                    ),
                                    DataCell(
                                      Center(
                                        child: Text(
                                          data['daysUsed']?.toString() ?? '-',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          data['reason'] ?? '',
                                          textAlign: TextAlign.left,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Center(
                                        child: Text(
                                          data['newBalance']?.toString() ?? '-',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (widget.isAdmin)
                                      DataCell(
                                        Center(
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.redAccent,
                                              size: 20,
                                            ),
                                            splashRadius: 20,
                                            tooltip: "Delete Record",
                                            onPressed: () =>
                                                _confirmDeleteLeave(
                                                  doc.id,
                                                  (data['daysUsed'] ?? 0.0)
                                                      .toDouble(),
                                                  data['reason'] ?? 'Unknown',
                                                ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
