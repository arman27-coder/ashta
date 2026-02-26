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
  bool _isExporting = false; // Tracks export state to show a loading spinner

  Future<void> _callEmployee() async {
    final String phone = widget.employeePhone.replaceAll(RegExp(r'\D'), '');
    final Uri url = Uri.parse("tel:+$phone");
    try {
      await launchUrl(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch phone dialer.")),
        );
      }
    }
  }

  // ==========================================
  // RESTORED WHATSAPP FEATURE
  // ==========================================
  Future<void> _sendWhatsAppMessage(double daysUsed, double newBalance) async {
    final String message =
        "Hello ${widget.employeeName},\n\n"
        "Your leave request for *$daysUsed days* has been approved and recorded.\n"
        "Your remaining leave balance is *$newBalance days*.\n\n"
        "Regards,\nAdmin";

    String phone = widget.employeePhone.replaceAll(RegExp(r'\D'), '');
    if (phone.length == 10) {
      phone = '91$phone'; // Defaulting to India +91 code if 10 digits
    }

    final Uri url = Uri.parse(
      "https://wa.me/$phone?text=${Uri.encodeComponent(message)}",
    );

    // Bypassing canLaunchUrl to avoid Android 11+ visibility issues
    try {
      final bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception("Could not launch");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not open WhatsApp. Is it installed?"),
          ),
        );
      }
    }
  }

  // ==========================================
  // PDF EXPORT FEATURE
  // ==========================================
  Future<void> _exportToPDF() async {
    try {
      setState(() => _isExporting = true);

      // 1. Fetch the exact Employee data & Designation
      final empDoc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .get();
      final designation = empDoc.data()?['designation'] ?? 'N/A';

      // 2. Fetch the Leave Ledger History
      final leavesQuery = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .collection('leaves')
          .orderBy('timestamp', descending: true)
          .get();

      // 3. Create the PDF Document
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Leave Ledger',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 20),
                // Header Info
                pw.Text(
                  'Name: ${widget.employeeName}',
                  style: pw.TextStyle(fontSize: 16),
                ),
                pw.Text(
                  'Designation: $designation',
                  style: pw.TextStyle(fontSize: 16),
                ),
                pw.SizedBox(height: 30),

                // Ledger Table
                pw.TableHelper.fromTextArray(
                  context: context,
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey800,
                  ),
                  cellAlignment: pw.Alignment.centerLeft,
                  headers: [
                    'OB',
                    'From Date',
                    'To Date',
                    'Days Used',
                    'Reason',
                    'CB',
                  ],
                  data: leavesQuery.docs.map((doc) {
                    final data = doc.data();
                    final fDate = data['fromDate'] != null
                        ? (data['fromDate'] as Timestamp).toDate()
                        : (data['date'] != null
                              ? (data['date'] as Timestamp).toDate()
                              : DateTime.now());
                    final tDate = data['toDate'] != null
                        ? (data['toDate'] as Timestamp).toDate()
                        : (data['date'] != null
                              ? (data['date'] as Timestamp).toDate()
                              : DateTime.now());

                    return [
                      data['previousBalance']?.toString() ?? '-',
                      "${fDate.day}/${fDate.month}/${fDate.year}",
                      "${tDate.day}/${tDate.month}/${tDate.year}",
                      data['daysUsed']?.toString() ?? '-',
                      data['reason'] ?? '',
                      data['newBalance']?.toString() ?? '-',
                    ];
                  }).toList(),
                ),
              ],
            );
          },
        ),
      );

      // 4. Trigger the native Share/Save menu
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            'Leave_Ledger_${widget.employeeName.replaceAll(' ', '_')}.pdf',
      );
    } catch (e, stack) {
      debugPrint("PDF Export Error: $e\n$stack");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error generating PDF: $e")));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ==========================================
  // EXCEL EXPORT FEATURE
  // ==========================================
  Future<void> _exportToExcel() async {
    try {
      setState(() => _isExporting = true);

      // 1. Fetch Data
      final empDoc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .get();
      final designation = empDoc.data()?['designation'] ?? 'N/A';
      final leavesQuery = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .collection('leaves')
          .orderBy('timestamp', descending: true)
          .get();

      // 2. Initialize Excel Sheet
      var excel = Excel.createExcel();
      excel.rename(excel.getDefaultSheet() ?? 'Sheet1', 'Leave Ledger');
      Sheet sheetObject = excel['Leave Ledger'];

      // 3. Add Header Details
      sheetObject.appendRow([
        TextCellValue('Name:'),
        TextCellValue(widget.employeeName),
      ]);
      sheetObject.appendRow([
        TextCellValue('Designation:'),
        TextCellValue(designation),
      ]);
      sheetObject.appendRow([TextCellValue('')]); // Blank space

      // 4. Add Table Column Headers
      sheetObject.appendRow([
        TextCellValue('OB'),
        TextCellValue('From Date'),
        TextCellValue('To Date'),
        TextCellValue('Days Used'),
        TextCellValue('Reason'),
        TextCellValue('CB'),
      ]);

      // 5. Populate Data Rows
      for (var doc in leavesQuery.docs) {
        final data = doc.data();
        final fDate = data['fromDate'] != null
            ? (data['fromDate'] as Timestamp).toDate()
            : (data['date'] != null
                  ? (data['date'] as Timestamp).toDate()
                  : DateTime.now());
        final tDate = data['toDate'] != null
            ? (data['toDate'] as Timestamp).toDate()
            : (data['date'] != null
                  ? (data['date'] as Timestamp).toDate()
                  : DateTime.now());

        sheetObject.appendRow([
          TextCellValue(data['previousBalance']?.toString() ?? '-'),
          TextCellValue("${fDate.day}/${fDate.month}/${fDate.year}"),
          TextCellValue("${tDate.day}/${tDate.month}/${tDate.year}"),
          TextCellValue(data['daysUsed']?.toString() ?? '-'),
          TextCellValue(data['reason'] ?? ''),
          TextCellValue(data['newBalance']?.toString() ?? '-'),
        ]);
      }

      // 6. Save and Share File Temporarily
      var fileBytes = excel.save();
      if (fileBytes != null) {
        var directory = await getTemporaryDirectory();
        String filePath =
            '${directory.path}/Leave_Ledger_${widget.employeeName.replaceAll(' ', '_')}.xlsx';
        File file = File(filePath);
        await file.writeAsBytes(fileBytes);

        // Share the generated file natively
        await Share.shareXFiles([
          XFile(filePath),
        ], text: 'Leave Ledger for ${widget.employeeName}');
      }
    } catch (e, stack) {
      debugPrint("Excel Export Error: $e\n$stack");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error generating Excel: $e")));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showRecordLeaveSheet() {
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
          // Helper to calculate total days automatically
          double calculateDays() {
            int days = toDate.difference(fromDate).inDays + 1;
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
                  "Manual Leave Entry",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Date Selection Row
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
                          "From: ${fromDate.day}/${fromDate.month}/${fromDate.year}",
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
                          if (d != null) {
                            setSheetState(() => toDate = d);
                          }
                        },
                        icon: const Icon(Icons.date_range, size: 18),
                        label: Text(
                          "To: ${toDate.day}/${toDate.month}/${toDate.year}",
                        ),
                      ),
                    ),
                  ],
                ),

                // Half Day Toggle
                CheckboxListTile(
                  title: const Text(
                    "+ Include Half Day (Deducts 0.5)",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  value: isHalfDay,
                  activeColor: Colors.blue,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setSheetState(() => isHalfDay = val ?? false);
                  },
                ),

                // Reason TextField
                TextField(
                  controller: reasonCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: "Reason for Leave",
                    prefixIcon: const Icon(Icons.edit_note),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Live Calculation display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Total Days to Deduct: ${calculateDays()}",
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Please ensure days > 0 and a reason is provided.",
                                ),
                              ),
                            );
                            return;
                          }

                          setSheetState(() => isSubmitting = true);

                          try {
                            double newBalance = await _db.recordLeave(
                              employeeId: widget.employeeId,
                              daysUsed: days,
                              reason: reason,
                              fromDate: fromDate,
                              toDate: toDate,
                              isHalfDay: isHalfDay,
                            );

                            if (mounted) {
                              Navigator.pop(ctx);

                              // Show WhatsApp notification prompt after recording
                              showDialog(
                                context: context,
                                builder: (dialogCtx) => AlertDialog(
                                  title: const Text("Leave Recorded"),
                                  content: const Text(
                                    "Would you like to notify the employee via WhatsApp?",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(dialogCtx);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Leave recorded successfully!",
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        "Skip",
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(dialogCtx);
                                        _sendWhatsAppMessage(days, newBalance);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      icon: const Icon(Icons.message),
                                      label: const Text("WhatsApp"),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error: $e")),
                              );
                            }
                          } finally {
                            if (mounted)
                              setSheetState(() => isSubmitting = false);
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
                          "Submit",
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          widget.employeeName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        actions: [
          // Show a spinner in the app bar if it is actively generating the file
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
            ),

          if (!_isExporting) ...[
            IconButton(
              icon: const Icon(Icons.call, color: Colors.blue),
              tooltip: 'Call Employee',
              onPressed: _callEmployee,
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
              tooltip: 'Download PDF',
              onPressed: _exportToPDF,
            ),
            IconButton(
              icon: const Icon(Icons.table_view_outlined, color: Colors.green),
              tooltip: 'Download Excel',
              onPressed: _exportToExcel,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // 1. Header Section
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('employees')
                .doc(widget.employeeId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();

              final data = snapshot.data!.data() as Map<String, dynamic>?;
              final designation = data?['designation'] ?? 'N/A';
              final balance = (data?['leaveBalance'] ?? 0.0).toDouble();

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Designation & Phone
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
                                widget.employeePhone,
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
                    // Total Balance Box
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: balance <= 2
                            ? Colors.red.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: balance <= 2
                              ? Colors.red.shade200
                              : Colors.green.shade200,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Total Balance",
                            style: TextStyle(
                              fontSize: 12,
                              color: balance <= 2 ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "$balance",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: balance <= 2
                                  ? Colors.red.shade700
                                  : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // 2. Record Leave Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton.icon(
              onPressed: _showRecordLeaveSheet,
              icon: const Icon(Icons.add),
              label: const Text(
                "Record Leave",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

          const SizedBox(height: 16),
          const Divider(height: 1),

          // 3. Leave Ledger Title
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Leave Ledger",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
            ),
          ),

          // 4. Leave Ledger Table
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
                      "No leave history found.",
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
                          columnSpacing: 25,
                          horizontalMargin: 20,
                          columns: const [
                            DataColumn(
                              label: Text(
                                'OB',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'From Date',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'To Date',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Days Used',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Reason',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'CB',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          rows: leaves.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;

                            // Safe parsing of dates in case of legacy data
                            final fDate = data['fromDate'] != null
                                ? (data['fromDate'] as Timestamp).toDate()
                                : (data['date'] != null
                                      ? (data['date'] as Timestamp).toDate()
                                      : DateTime.now());
                            final tDate = data['toDate'] != null
                                ? (data['toDate'] as Timestamp).toDate()
                                : (data['date'] != null
                                      ? (data['date'] as Timestamp).toDate()
                                      : DateTime.now());

                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    data['previousBalance']?.toString() ?? '-',
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    "${fDate.day}/${fDate.month}/${fDate.year}",
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    "${tDate.day}/${tDate.month}/${tDate.year}",
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
  }
}
