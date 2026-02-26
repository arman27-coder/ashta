import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  bool _isExporting = false; // Tracks export state for loading spinner

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  // ==========================================
  // PDF EXPORT FEATURE
  // ==========================================
  Future<void> _exportToPDF() async {
    try {
      setState(() => _isExporting = true);

      // Fetch all employees ordered by name
      final querySnapshot = await FirebaseFirestore.instance
          .collection('employees')
          .orderBy('name')
          .get();

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Employee Directory',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 20),

                // Directory Table
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
                    'Full Name',
                    'Designation',
                    'Total Leaves',
                    'Used',
                    'Balance',
                  ],
                  data: querySnapshot.docs.map((doc) {
                    final data = doc.data();
                    final balance = (data['leaveBalance'] ?? 0.0).toDouble();
                    const totalLeaves = 8.0;
                    final usedLeaves = totalLeaves - balance;

                    return [
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

      // Trigger the native Share/Save menu
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'Employee_Directory.pdf',
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

      // Fetch all employees
      final querySnapshot = await FirebaseFirestore.instance
          .collection('employees')
          .orderBy('name')
          .get();

      // Initialize Excel Sheet
      var excel = Excel.createExcel();
      // Rename default sheet so we don't have an empty "Sheet1"
      excel.rename(excel.getDefaultSheet() ?? 'Sheet1', 'Directory');
      Sheet sheetObject = excel['Directory'];

      // Add Table Column Headers
      sheetObject.appendRow([
        TextCellValue('Full Name'),
        TextCellValue('Designation'),
        TextCellValue('Total Leaves'),
        TextCellValue('Used'),
        TextCellValue('Balance'),
      ]);

      // Populate Data Rows
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final balance = (data['leaveBalance'] ?? 0.0).toDouble();
        const totalLeaves = 8.0;
        final usedLeaves = totalLeaves - balance;

        sheetObject.appendRow([
          TextCellValue(data['name'] ?? ''),
          TextCellValue(data['designation'] ?? 'N/A'),
          TextCellValue(totalLeaves.toString()),
          TextCellValue(usedLeaves.toString()),
          TextCellValue(balance.toString()),
        ]);
      }

      // Save and Share File
      var fileBytes = excel.save();
      if (fileBytes != null) {
        var directory = await getTemporaryDirectory();
        String filePath = '${directory.path}/Employee_Directory.xlsx';
        File file = File(filePath);
        await file.writeAsBytes(fileBytes);

        // Share the generated file natively
        await Share.shareXFiles([
          XFile(filePath),
        ], text: 'Employee Directory Export');
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
              isEditing ? "Edit Employee" : "Add New Employee",
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
                labelText: "WhatsApp Phone Number",
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
          "Employee Directory",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        actions: [
          // Show spinner if exporting, otherwise show the action buttons
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
              icon: const Icon(Icons.logout, color: Colors.blueGrey),
              tooltip: 'Logout',
              onPressed: _signOut,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Sleek Search Bar
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

          // Employee Table List
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

                // Filter logic based on search query
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
                            margin: const EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              80,
                            ), // extra bottom margin for FAB
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
                                      'Used',
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
                                rows: filteredEmployees.map((emp) {
                                  final data =
                                      emp.data() as Map<String, dynamic>;
                                  final balance = (data['leaveBalance'] ?? 0.0)
                                      .toDouble();
                                  const totalLeaves =
                                      8.0; // Default baseline allocation
                                  final usedLeaves = totalLeaves - balance;

                                  return DataRow(
                                    cells: [
                                      // 1. Hyperlinked Name
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
                                      // 2. Designation
                                      DataCell(
                                        Text(
                                          data['designation'] ?? 'N/A',
                                          style: const TextStyle(
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      // 3. Total Leaves
                                      DataCell(
                                        Text(
                                          totalLeaves.toString(),
                                          style: const TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                      // 4. Used
                                      DataCell(
                                        Text(
                                          usedLeaves.toString(),
                                          style: const TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                      // 5. Balance (Color coded)
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: balance <= 2
                                                ? Colors.red.shade50
                                                : Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: balance <= 2
                                                  ? Colors.red.shade200
                                                  : Colors.green.shade200,
                                            ),
                                          ),
                                          child: Text(
                                            balance.toString(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: balance <= 2
                                                  ? Colors.red.shade700
                                                  : Colors.green.shade700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // 6. Action (Delete)
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
          "Employee",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // Helper widget for empty states
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
