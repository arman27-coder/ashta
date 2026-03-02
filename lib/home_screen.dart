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

  String _getCurrentMonthYear() {
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
    return "${months[now.month - 1]} ${now.year}";
  }

  // ==========================================
  // PDF EXPORT FEATURE (Center Aligned + Professional Layout)
  // ==========================================
  Future<void> _exportToPDF() async {
    try {
      setState(() => _isExporting = true);

      final querySnapshot = await FirebaseFirestore.instance
          .collection('employees')
          .orderBy('name')
          .get();

      // Load fonts supporting English natively
      pw.Font ttf;
      pw.Font ttfBold;
      try {
        ttf = await PdfGoogleFonts.robotoRegular();
        ttfBold = await PdfGoogleFonts.robotoBold();
      } catch (e) {
        ttf = pw.Font.helvetica();
        ttfBold = pw.Font.helveticaBold();
      }

      final pdf = pw.Document();
      final monthYear = _getCurrentMonthYear();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Center(
                  child: pw.Text(
                    'Zilla Parishad, Dharashiv',
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
                    'Panchayat Samiti, Bhoom',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 16,
                      color: PdfColors.grey800,
                    ),
                  ),
                ),
                pw.SizedBox(height: 12),

                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.blue200, width: 1),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Employee List',
                        style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 18,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Date - $monthYear',
                        style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 13,
                          color: PdfColors.blueGrey700,
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
                  cellDecoration: (index, data, rowNum) {
                    return pw.BoxDecoration(
                      color: rowNum % 2 == 1
                          ? PdfColors.grey100
                          : PdfColors.white,
                    );
                  },
                  rowDecoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(
                        color: PdfColors.grey400,
                        width: 0.5,
                      ),
                    ),
                  ),
                  cellAlignment: pw.Alignment.centerLeft,
                  columnWidths: {
                    0: const pw.FixedColumnWidth(30),
                    1: const pw.FlexColumnWidth(3),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FixedColumnWidth(60),
                    4: const pw.FixedColumnWidth(65),
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
                  headerAlignments: {
                    0: pw.Alignment.center,
                    1: pw.Alignment.center,
                    2: pw.Alignment.center,
                    3: pw.Alignment.center,
                    4: pw.Alignment.center,
                    5: pw.Alignment.center,
                  },
                  headers: [
                    'Sr.No',
                    'Full Name',
                    'Designation',
                    'Total Leaves',
                    'Used Leaves',
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
                      data['designation'] ?? '-',
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
        filename: 'Employee_List_${DateTime.now().millisecondsSinceEpoch}.pdf',
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
  // EXCEL EXPORT FEATURE (Center Aligned)
  // ==========================================
  Future<void> _exportToExcel() async {
    try {
      setState(() => _isExporting = true);

      final querySnapshot = await FirebaseFirestore.instance
          .collection('employees')
          .orderBy('name')
          .get();

      var excel = Excel.createExcel();
      excel.rename(excel.getDefaultSheet() ?? 'Sheet1', 'Employee List');
      Sheet sheetObject = excel['Employee List'];

      sheetObject.setColumnWidth(0, 6.0);
      sheetObject.setColumnWidth(1, 25.0);
      sheetObject.setColumnWidth(2, 20.0);
      sheetObject.setColumnWidth(3, 12.0);
      sheetObject.setColumnWidth(4, 15.0);
      sheetObject.setColumnWidth(5, 12.0);

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

      void addMergeCentered(String text, int rowIndex, CellStyle style) {
        sheetObject.appendRow([TextCellValue(text)]);
        sheetObject.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
          CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex),
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

      final monthYear = _getCurrentMonthYear();

      addMergeCentered('Zilla Parishad, Dharashiv', 0, titleStyle);
      addMergeCentered('Panchayat Samiti, Bhoom', 1, subTitleStyle);
      addMergeCentered('Date - $monthYear', 2, subTitleStyle);
      sheetObject.appendRow([TextCellValue('')]);
      addMergeCentered('Employee List', 4, titleStyle);
      sheetObject.appendRow([TextCellValue('')]);

      sheetObject.appendRow([
        TextCellValue('Sr.No'),
        TextCellValue('Full Name'),
        TextCellValue('Designation'),
        TextCellValue('Total Leaves'),
        TextCellValue('Used Leaves'),
        TextCellValue('Balance'),
      ]);

      for (int i = 0; i <= 5; i++) {
        sheetObject
                .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 6))
                .cellStyle =
            headerStyle;
      }

      int currentRow = 7;
      int srNo = 1;
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final balance = (data['leaveBalance'] ?? 0.0).toDouble();
        const totalLeaves = 8.0;
        final usedLeaves = totalLeaves - balance;

        sheetObject.appendRow([
          TextCellValue((srNo++).toString()),
          TextCellValue(data['name'] ?? ''),
          TextCellValue(data['designation'] ?? '-'),
          TextCellValue(totalLeaves.toString()),
          TextCellValue(usedLeaves.toString()),
          TextCellValue(balance.toString()),
        ]);

        sheetObject
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 0,
                    rowIndex: currentRow,
                  ),
                )
                .cellStyle =
            normalCenter;
        sheetObject
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 1,
                    rowIndex: currentRow,
                  ),
                )
                .cellStyle =
            normalLeft;
        sheetObject
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 2,
                    rowIndex: currentRow,
                  ),
                )
                .cellStyle =
            normalLeft;
        sheetObject
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 3,
                    rowIndex: currentRow,
                  ),
                )
                .cellStyle =
            normalCenter;
        sheetObject
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 4,
                    rowIndex: currentRow,
                  ),
                )
                .cellStyle =
            normalCenter;
        sheetObject
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 5,
                    rowIndex: currentRow,
                  ),
                )
                .cellStyle =
            normalCenter;

        currentRow++;
      }

      var fileBytes = excel.save();
      if (fileBytes != null) {
        var directory = await getTemporaryDirectory();
        String filePath =
            '${directory.path}/Employee_List_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        File file = File(filePath);
        await file.writeAsBytes(fileBytes);

        await Share.shareXFiles([XFile(filePath)], text: 'Employee Directory');
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

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Employee"),
        content: Text(
          "Are you sure you want to delete $name? This action cannot be undone.",
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
              await _db.deleteEmployee(id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("$name deleted successfully."),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            icon: const Icon(Icons.delete),
            label: const Text("Delete"),
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
              isEditing ? "Edit Employee Details" : "Add New Employee",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: "Full Name",
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
                labelText: "Designation",
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
              child: Text(isEditing ? "Save Changes" : "Add Employee"),
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
          "Employee List",
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
              tooltip: 'Download PDF',
              onPressed: _exportToPDF,
            ),
            IconButton(
              icon: const Icon(Icons.table_view_outlined, color: Colors.green),
              tooltip: 'Download Excel',
              onPressed: _exportToExcel,
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.blueGrey),
              tooltip: 'Settings',
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
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
                  "Zilla Parishad, Dharashiv",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Panchayat Samiti, Bhoom",
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
                hintText: "Search by name or designation...",
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
                  return _buildEmptyState("No employees added yet.");
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
                  return _buildEmptyState("No employees match your search.");
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
                                      'Sr.No',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Full Name',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Designation',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Total Leaves',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Used Leaves',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Balance',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Action',
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
                                          data['designation'] ?? '-',
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
                                          tooltip: 'Delete Employee',
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
          "Add New",
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
