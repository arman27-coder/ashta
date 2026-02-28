import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Packages for Exporting
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'database_service.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  final String employeePhone;

  const EmployeeDetailsScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.employeePhone,
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

  Future<void> _callEmployee(String phoneString) async {
    final String phone = phoneString.replaceAll(RegExp(r'\D'), '');
    final Uri url = Uri.parse("tel:$phone");
    try {
      await launchUrl(url);
    } catch (e) {
      _safeSnackBar("फोन डायलर उघडू शकलो नाही.");
    }
  }

  String _getFormattedMonthYear() {
    final now = DateTime.now();
    const months = [
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
    return '${months[now.month - 1]} ${now.year}';
  }

  Future<void> _sendWhatsAppMessage(
    double daysUsed,
    double newBalance,
    String empName,
    String empPhone,
  ) async {
    final String message =
        "नमस्कार $empName,\n\n"
        "तुमची *$daysUsed दिवसांची* रजा मंजूर करून नोंदवली गेली आहे.\n"
        "तुमची उर्वरित रजा शिल्लक *$newBalance दिवस* आहे.\n\n"
        "धन्यवाद,\nॲडमिन";

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
      _safeSnackBar("व्हॉट्सॲप उघडू शकलो नाही. ते स्थापित आहे का?");
    }
  }

  void _confirmDeleteLeave(String leaveId, double daysUsed, String reason) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("रजा रेकॉर्ड हटवा"),
        content: Text(
          "तुम्हाला खात्री आहे का की तुम्हाला '$reason' साठीची रजा हटवायची आहे?\n\n"
          "हे हटवल्यास कर्मचाऱ्याच्या खात्यात $daysUsed दिवस परत जोडले जातील.",
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
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _db.deleteLeave(widget.employeeId, leaveId, daysUsed);
                _safeSnackBar(
                  "रजा हटवली आणि शिल्लक परत केली.",
                  backgroundColor: Colors.orange,
                );
              } catch (e) {
                _safeSnackBar("त्रुटी: $e", backgroundColor: Colors.red);
              }
            },
            icon: const Icon(Icons.delete),
            label: const Text("हटवा आणि परत करा"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ====================== EDIT EMPLOYEE ======================
  void _showEditEmployeeSheet(
    String currentName,
    String currentDesignation,
    String currentPhone,
  ) {
    final nameCtrl = TextEditingController(text: currentName);
    final desigCtrl = TextEditingController(text: currentDesignation);
    final phoneCtrl = TextEditingController(text: currentPhone);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
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
              "कर्मचारी माहिती बदला",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: "संपूर्ण नाव",
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
                labelText: "पद",
                prefixIcon: const Icon(Icons.work_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "व्हॉट्सॲप नंबर",
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
                );

                if (mounted) {
                  Navigator.pop(ctx);
                  _safeSnackBar(
                    "माहिती यशस्वीरित्या बदलली!",
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
                "बदल जतन करा",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====================== PDF EXPORT (Kept English) ======================
  Future<void> _exportToPDF() async {
    try {
      setState(() => _isExporting = true);

      final empDoc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .get();
      final currentName = empDoc.data()?['name'] ?? widget.employeeName;
      final designation = empDoc.data()?['designation'] ?? 'N/A';

      final leavesQuery = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .collection('leaves')
          .orderBy('timestamp', descending: false)
          .get();

      final pdf = pw.Document();
      final monthYear = _getFormattedMonthYear();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Jilha Parishad, Dharashiv',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Text(
                        'Panchayat Samiti, Bhum',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.grey800,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    monthYear,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Leave Ledger',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 15),
              pw.Text(
                'Name: $currentName',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Designation: $designation',
                style: pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 20),

              pw.TableHelper.fromTextArray(
                context: context,
                cellPadding: const pw.EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 6,
                ),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                ),
                cellAlignment: pw.Alignment.centerLeft,
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
                  0: const pw.FixedColumnWidth(40),
                  1: const pw.FixedColumnWidth(40),
                  2: const pw.FixedColumnWidth(70),
                  3: const pw.FixedColumnWidth(70),
                  4: const pw.FixedColumnWidth(50),
                  5: const pw.FlexColumnWidth(2),
                  6: const pw.FixedColumnWidth(40),
                },
                headers: [
                  'Sr No',
                  'OB',
                  'From Date',
                  'To Date',
                  'Days',
                  'Reason',
                  'CB',
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
                    fDate != null
                        ? "${fDate.toDate().day}/${fDate.toDate().month}/${fDate.toDate().year}"
                        : '-',
                    tDate != null
                        ? "${tDate.toDate().day}/${tDate.toDate().month}/${tDate.toDate().year}"
                        : '-',
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
      _safeSnackBar("PDF तयार करताना त्रुटी: $e");
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ====================== EXCEL EXPORT (Kept English) ======================
  Future<void> _exportToExcel() async {
    try {
      setState(() => _isExporting = true);

      final empDoc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .get();
      final currentName = empDoc.data()?['name'] ?? widget.employeeName;
      final designation = empDoc.data()?['designation'] ?? 'N/A';

      final leavesQuery = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .collection('leaves')
          .orderBy('timestamp', descending: false)
          .get();

      var excel = Excel.createExcel();
      excel.rename(excel.getDefaultSheet() ?? 'Sheet1', 'Leave Ledger');
      Sheet sheetObject = excel['Leave Ledger'];

      sheetObject.setColumnWidth(0, 10.0);
      sheetObject.setColumnWidth(1, 12.0);
      sheetObject.setColumnWidth(2, 18.0);
      sheetObject.setColumnWidth(3, 18.0);
      sheetObject.setColumnWidth(4, 15.0);
      sheetObject.setColumnWidth(5, 45.0);
      sheetObject.setColumnWidth(6, 12.0);

      final monthYear = _getFormattedMonthYear();
      sheetObject.appendRow([TextCellValue('Jilha Parishad, Dharashiv')]);
      sheetObject.appendRow([TextCellValue('Panchayat Samiti, Bhum')]);
      sheetObject.appendRow([TextCellValue('Date:'), TextCellValue(monthYear)]);
      sheetObject.appendRow([TextCellValue('')]);
      sheetObject.appendRow([TextCellValue('LEAVE LEDGER')]);
      sheetObject.appendRow([
        TextCellValue('Name:'),
        TextCellValue(currentName),
      ]);
      sheetObject.appendRow([
        TextCellValue('Designation:'),
        TextCellValue(designation),
      ]);
      sheetObject.appendRow([TextCellValue('')]);

      sheetObject.appendRow([
        TextCellValue('SR NO'),
        TextCellValue('OB'),
        TextCellValue('FROM DATE'),
        TextCellValue('TO DATE'),
        TextCellValue('DAYS USED'),
        TextCellValue('REASON'),
        TextCellValue('CB'),
      ]);

      int srNo = 1;
      for (var doc in leavesQuery.docs) {
        final data = doc.data();
        final fDate = (data['fromDate'] ?? data['date']) as Timestamp?;
        final tDate = (data['toDate'] ?? data['date']) as Timestamp?;

        sheetObject.appendRow([
          TextCellValue((srNo++).toString()),
          TextCellValue(data['previousBalance']?.toString() ?? '-'),
          TextCellValue(
            fDate != null
                ? "${fDate.toDate().day}/${fDate.toDate().month}/${fDate.toDate().year}"
                : '-',
          ),
          TextCellValue(
            tDate != null
                ? "${tDate.toDate().day}/${tDate.toDate().month}/${tDate.toDate().year}"
                : '-',
          ),
          TextCellValue(data['daysUsed']?.toString() ?? '-'),
          TextCellValue(data['reason'] ?? ''),
          TextCellValue(data['newBalance']?.toString() ?? '-'),
        ]);
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
        ], text: 'Leave Ledger for $currentName');
      }
    } catch (e) {
      _safeSnackBar("Excel तयार करताना त्रुटी: $e");
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ====================== RECORD LEAVE ======================
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
                const Text(
                  "रजा नोंदवा",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                          "पासून: ${fromDate.day}/${fromDate.month}/${fromDate.year}",
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
                          "पर्यंत: ${toDate.day}/${toDate.month}/${toDate.year}",
                        ),
                      ),
                    ),
                  ],
                ),

                CheckboxListTile(
                  title: const Text("+ अर्धा दिवस (०.५ वजा होईल)"),
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
                    labelText: "रजेचे कारण",
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
                    "एकूण वजा होणारे दिवस: ${calculateDays()}",
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
                            _safeSnackBar("कृपया कारण आणि वैध तारखा द्या");
                            return;
                          }

                          if (days > currentBalance) {
                            _safeSnackBar(
                              "पुरेशी रजा नाही! तुमच्याकडे फक्त $currentBalance दिवस शिल्लक आहेत.",
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
                              "रजा यशस्वीरित्या नोंदवली गेली!",
                              backgroundColor: Colors.green,
                            );

                            if (mounted) {
                              showDialog(
                                context: context,
                                builder: (dialogCtx) => AlertDialog(
                                  title: const Text("रजा नोंदवली गेली"),
                                  content: const Text(
                                    "तुम्हाला कर्मचाऱ्याला व्हॉट्सॲपवर कळवायचे आहे का?",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogCtx),
                                      child: const Text(
                                        "नको",
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
                                      label: const Text("व्हॉट्सॲपवर पाठवा"),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } catch (e) {
                            _safeSnackBar(
                              "त्रुटी: $e",
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
                          "जतन करा",
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
    // Wrapping the entire Scaffold in StreamBuilder ensures that edits to the
    // employee's name/phone update instantly in the AppBar and Body.
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
        final balance = (data['leaveBalance'] ?? 0.0).toDouble();

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            title: Text(
              currentName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF2C3E50),
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
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blueGrey),
                  tooltip: 'माहिती बदला',
                  onPressed: () => _showEditEmployeeSheet(
                    currentName,
                    designation,
                    currentPhone,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.call, color: Colors.blue),
                  tooltip: 'कॉल करा',
                  onPressed: () => _callEmployee(currentPhone),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.picture_as_pdf,
                    color: Colors.redAccent,
                  ),
                  tooltip: 'PDF डाउनलोड करा',
                  onPressed: _exportToPDF,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.table_view_outlined,
                    color: Colors.green,
                  ),
                  tooltip: 'Excel डाउनलोड करा',
                  onPressed: _exportToExcel,
                ),
              ],
            ],
          ),
          body: Column(
            children: [
              // ==============================
              // Official Organization Banner
              // ==============================
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
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "जिल्हा परिषद, धाराशिव",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "पंचायत समिती, भूम",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),

              // ==============================
              // Employee Stats
              // ==============================
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
                                "एकूण शिल्लक",
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ElevatedButton.icon(
                      onPressed: () => _showRecordLeaveSheet(
                        balance,
                        currentName,
                        currentPhone,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text(
                        "रजा नोंदवा",
                        style: TextStyle(
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

              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "रजा खातेवही",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
              ),

              // ==============================
              // Leave Ledger
              // ==============================
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
                          "कोणतीही रजा नोंदवलेली नाही.",
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
                              columns: const [
                                DataColumn(
                                  label: Text(
                                    'अ.क्र.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'आरंभीची शिल्लक',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'पासून',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'पर्यंत',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'घेतलेले दिवस',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'कारण',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'अखेरची शिल्लक',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'कृती',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
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
                                  cells: [
                                    DataCell(Text(index.toString())),
                                    DataCell(
                                      Text(
                                        data['previousBalance']?.toString() ??
                                            '-',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        fDate != null
                                            ? "${fDate.toDate().day}/${fDate.toDate().month}/${fDate.toDate().year}"
                                            : '-',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        tDate != null
                                            ? "${tDate.toDate().day}/${tDate.toDate().month}/${tDate.toDate().year}"
                                            : '-',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        data['daysUsed']?.toString() ?? '-',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(data['reason'] ?? '')),
                                    DataCell(
                                      Text(
                                        data['newBalance']?.toString() ?? '-',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.redAccent,
                                          size: 20,
                                        ),
                                        splashRadius: 20,
                                        tooltip: "रेकॉर्ड हटवा",
                                        onPressed: () => _confirmDeleteLeave(
                                          doc.id,
                                          (data['daysUsed'] ?? 0.0).toDouble(),
                                          data['reason'] ?? 'Unknown',
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
