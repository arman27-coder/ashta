import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Packages for Exporting
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// Relative Imports
import 'database_service.dart';
import 'employee_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _db = DatabaseService();
  String _searchQuery = '';
  bool _isExporting = false;

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

  // ==========================================
  // PDF EXPORT FEATURE (Kept in English to avoid font rendering issues in PDF)
  // ==========================================
  Future<void> _exportToPDF() async {
    try {
      setState(() => _isExporting = true);

      final querySnapshot = await FirebaseFirestore.instance
          .collection('employees')
          .orderBy('name')
          .get();

      final pdf = pw.Document();
      final monthYear = _getFormattedMonthYear();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
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
                  'Employee Directory',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
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
                      bottom: pw.BorderSide(
                        color: PdfColors.grey300,
                        width: 0.5,
                      ),
                    ),
                  ),
                  cellAlignment: pw.Alignment.centerLeft,
                  columnWidths: {
                    0: const pw.FixedColumnWidth(40),
                    1: const pw.FlexColumnWidth(3),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FixedColumnWidth(80),
                    4: const pw.FixedColumnWidth(60),
                    5: const pw.FixedColumnWidth(60),
                  },
                  cellAlignments: {
                    0: pw.Alignment.center,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.center,
                    4: pw.Alignment.center,
                    5: pw.Alignment.center,
                  },
                  headers: [
                    'Sr No',
                    'Full Name',
                    'Designation',
                    'Total Leaves',
                    'Used',
                    'Balance',
                  ],
                  data: querySnapshot.docs.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final data = entry.value.data();
                    final balance = (data['leaveBalance'] ?? 0.0).toDouble();
                    const totalLeaves = 8.0;
                    final usedLeaves = totalLeaves - balance;

                    return [
                      index.toString(),
                      data['name'] ?? '',
                      data['designation'] ?? 'N/A',
                      totalLeaves.toString(),
                      usedLeaves.toString(),
                      balance.toString(),
                    ];
                  }).toList(),
                ),
              ],
            );
          },
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'Employee_Directory.pdf',
      );
    } catch (e, stack) {
      debugPrint("PDF Export Error: $e\n$stack");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("PDF तयार करताना त्रुटी: $e")));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ==========================================
  // EXCEL EXPORT FEATURE (Also kept in English)
  // ==========================================
  Future<void> _exportToExcel() async {
    try {
      setState(() => _isExporting = true);

      final querySnapshot = await FirebaseFirestore.instance
          .collection('employees')
          .orderBy('name')
          .get();

      var excel = Excel.createExcel();
      excel.rename(excel.getDefaultSheet() ?? 'Sheet1', 'Directory');
      Sheet sheetObject = excel['Directory'];

      sheetObject.setColumnWidth(0, 10.0);
      sheetObject.setColumnWidth(1, 35.0);
      sheetObject.setColumnWidth(2, 28.0);
      sheetObject.setColumnWidth(3, 18.0);
      sheetObject.setColumnWidth(4, 15.0);
      sheetObject.setColumnWidth(5, 15.0);

      final monthYear = _getFormattedMonthYear();
      sheetObject.appendRow([TextCellValue('Jilha Parishad, Dharashiv')]);
      sheetObject.appendRow([TextCellValue('Panchayat Samiti, Bhum')]);
      sheetObject.appendRow([TextCellValue('Date:'), TextCellValue(monthYear)]);
      sheetObject.appendRow([TextCellValue('')]);
      sheetObject.appendRow([TextCellValue('EMPLOYEE DIRECTORY')]);
      sheetObject.appendRow([TextCellValue('')]);

      sheetObject.appendRow([
        TextCellValue('SR NO'),
        TextCellValue('FULL NAME'),
        TextCellValue('DESIGNATION'),
        TextCellValue('TOTAL LEAVES'),
        TextCellValue('USED'),
        TextCellValue('BALANCE'),
      ]);

      int srNo = 1;
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final balance = (data['leaveBalance'] ?? 0.0).toDouble();
        const totalLeaves = 8.0;
        final usedLeaves = totalLeaves - balance;

        sheetObject.appendRow([
          TextCellValue((srNo++).toString()),
          TextCellValue(data['name'] ?? ''),
          TextCellValue(data['designation'] ?? 'N/A'),
          TextCellValue(totalLeaves.toString()),
          TextCellValue(usedLeaves.toString()),
          TextCellValue(balance.toString()),
        ]);
      }

      var fileBytes = excel.save();
      if (fileBytes != null) {
        var directory = await getTemporaryDirectory();
        String filePath = '${directory.path}/Employee_Directory.xlsx';
        File file = File(filePath);
        await file.writeAsBytes(fileBytes);

        await Share.shareXFiles([
          XFile(filePath),
        ], text: 'Employee Directory Export');
      }
    } catch (e, stack) {
      debugPrint("Excel Export Error: $e\n$stack");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Excel तयार करताना त्रुटी: $e")));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("कर्मचारी हटवा"),
        content: Text(
          "तुम्हाला खात्री आहे का की तुम्हाला $name ला हटवायचे आहे? ही कृती पूर्ववत केली जाऊ शकत नाही.",
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
              await _db.deleteEmployee(id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("$name यशस्वीरित्या हटवले."),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            icon: const Icon(Icons.delete),
            label: const Text("हटवा"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEmployeeSheet([DocumentSnapshot? employeeToEdit]) {
    final isEditing = employeeToEdit != null;
    final nameCtrl = TextEditingController(
      text: isEditing ? employeeToEdit['name'] : '',
    );
    final desigCtrl = TextEditingController(
      text: isEditing ? employeeToEdit['designation'] : '',
    );
    final phoneCtrl = TextEditingController(
      text: isEditing ? employeeToEdit['phone'] : '',
    );

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
            Text(
              isEditing ? "कर्मचारी माहिती बदला" : "नवीन कर्मचारी जोडा",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

                if (isEditing) {
                  await _db.updateEmployee(
                    employeeToEdit.id,
                    nameCtrl.text.trim(),
                    desigCtrl.text.trim(),
                    phoneCtrl.text.trim(),
                  );
                } else {
                  await _db.addEmployee(
                    nameCtrl.text.trim(),
                    desigCtrl.text.trim(),
                    phoneCtrl.text.trim(),
                  );
                }
                if (mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(isEditing ? "बदल जतन करा" : "कर्मचारी जोडा"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "कर्मचारी यादी",
          style: TextStyle(fontWeight: FontWeight.bold),
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
              icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
              tooltip: 'PDF डाउनलोड करा',
              onPressed: _exportToPDF,
            ),
            IconButton(
              icon: const Icon(Icons.table_view_outlined, color: Colors.green),
              tooltip: 'Excel डाउनलोड करा',
              onPressed: _exportToExcel,
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.blueGrey),
              tooltip: 'सेटिंग्ज',
              onPressed: () => Navigator.pushNamed(context, '/settings'),
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
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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

          // Search Bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: "नाव किंवा पदाने शोधा...",
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search, color: Colors.blueGrey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.getEmployeesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState("अद्याप कर्मचारी जोडलेले नाहीत.");
                }

                final allEmployees = snapshot.data!.docs;
                final filteredEmployees = allEmployees.where((emp) {
                  final data = emp.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final designation = (data['designation'] ?? '')
                      .toString()
                      .toLowerCase();

                  return name.contains(_searchQuery) ||
                      designation.contains(_searchQuery);
                }).toList();

                if (filteredEmployees.isEmpty) {
                  return _buildEmptyState(
                    "तुमच्या शोधाशी जुळणारे कर्मचारी नाहीत.",
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      physics: const BouncingScrollPhysics(),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  Colors.blue.shade50,
                                ),
                                dataRowMinHeight: 65,
                                dataRowMaxHeight: 65,
                                columnSpacing: 30,
                                horizontalMargin: 20,
                                border: TableBorder(
                                  horizontalInside: BorderSide(
                                    color: Colors.grey.shade100,
                                    width: 1,
                                  ),
                                ),
                                columns: const [
                                  DataColumn(
                                    label: Text(
                                      'अ.क्र.',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'संपूर्ण नाव',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'पद',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'एकूण रजा',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'वापरलेल्या',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'शिल्लक',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'कृती',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ),
                                ],
                                rows: filteredEmployees.asMap().entries.map((
                                  entry,
                                ) {
                                  final index = entry.key + 1;
                                  final emp = entry.value;
                                  final data =
                                      emp.data() as Map<String, dynamic>;
                                  final balance = (data['leaveBalance'] ?? 0.0)
                                      .toDouble();
                                  const totalLeaves = 8.0;
                                  final usedLeaves = totalLeaves - balance;

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          index.toString(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        InkWell(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    EmployeeDetailsScreen(
                                                      employeeId: emp.id,
                                                      employeeName:
                                                          data['name'],
                                                      employeePhone:
                                                          data['phone'],
                                                    ),
                                              ),
                                            );
                                          },
                                          onLongPress: () =>
                                              _showAddEmployeeSheet(emp),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8.0,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor:
                                                      Colors.blue.shade100,
                                                  child: Text(
                                                    data['name'][0]
                                                        .toUpperCase(),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.blue,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  data['name'],
                                                  style: const TextStyle(
                                                    color: Colors.blue,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          data['designation'] ?? 'N/A',
                                          style: const TextStyle(
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          totalLeaves.toString(),
                                          style: const TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          usedLeaves.toString(),
                                          style: const TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: balance <= 0
                                                ? Colors.grey.shade200
                                                : balance <= 2
                                                ? Colors.red.shade50
                                                : Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: balance <= 0
                                                  ? Colors.grey.shade400
                                                  : balance <= 2
                                                  ? Colors.red.shade200
                                                  : Colors.green.shade200,
                                            ),
                                          ),
                                          child: Text(
                                            balance.toString(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: balance <= 0
                                                  ? Colors.grey.shade700
                                                  : balance <= 2
                                                  ? Colors.red.shade700
                                                  : Colors.green.shade700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent,
                                          ),
                                          tooltip: 'कर्मचारी हटवा',
                                          splashRadius: 24,
                                          onPressed: () => _confirmDelete(
                                            emp.id,
                                            data['name'],
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
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEmployeeSheet(),
        backgroundColor: Colors.blue,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "नवीन जोडा",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
