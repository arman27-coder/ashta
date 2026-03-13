import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'app_constants.dart';
import 'database_service.dart';
import 'employee_details_screen.dart';
import 'app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _db = DatabaseService();
  String _searchQuery = '';
  String _selectedTab = 'All Departments';
  bool _isExporting = false;

  bool _isAdmin = false;
  List<String>? _adminAllowedDepts;
  bool _isLoadingAdmin = true;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    bool isAdmin = await _db.isCurrentUserAdmin();
    List<String>? allowedDepts = AppConstants.getAllowedDepartments();

    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
        _adminAllowedDepts = allowedDepts;
        _isLoadingAdmin = false;
      });
    }
  }

  void _showExportOptions(bool isPdf) {
    List<String> options = ['All Departments', ...AppConstants.allDepartments];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isPdf ? "Export PDF Document" : "Export Excel Sheet",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Select which department list you want to generate:",
              style: TextStyle(color: Colors.blueGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: options.map((option) {
                final isAll = option == 'All Departments';
                final displayOption = isAll
                    ? AppLocalizations.get('all_departments')
                    : AppConstants.getLocalizedDeptName(option);

                return ActionChip(
                  label: Text(
                    displayOption,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isAll ? Colors.white : Colors.blue.shade700,
                    ),
                  ),
                  avatar: Icon(
                    isAll ? Icons.account_balance : Icons.domain,
                    size: 18,
                    color: isAll ? Colors.white : Colors.blue.shade700,
                  ),
                  backgroundColor: isAll
                      ? Colors.blue.shade700
                      : Colors.blue.shade50,
                  side: BorderSide(color: Colors.blue.shade200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    String? filter = isAll ? null : option;
                    if (isPdf) {
                      _exportToPDF(filter);
                    } else {
                      _exportToExcel(filter);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToPDF(String? filterDept) async {
    try {
      setState(() => _isExporting = true);

      final querySnapshot = await FirebaseFirestore.instance
          .collection('employees')
          .orderBy('name')
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

      final allDocs = querySnapshot.docs;
      final targetDocs = allDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final rawDept = data['department']?.toString();
        final dept = AppConstants.getNormalizedDeptName(rawDept);

        if (_adminAllowedDepts != null &&
            !_adminAllowedDepts!.contains(dept) &&
            dept != 'Unassigned') {
          return false;
        }

        if (filterDept != null && dept != filterDept) {
          return false;
        }
        return true;
      }).toList();

      if (targetDocs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No employees found for this selection."),
            ),
          );
        }
        setState(() => _isExporting = false);
        return;
      }

      final tableData = targetDocs.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final data = entry.value.data();
        final balance = (data['leaveBalance'] ?? 0.0).toDouble();
        final totalLeaves = AppConstants.defaultAnnualLeaves;
        final usedLeaves = totalLeaves - balance;
        final rawDept = data['department']?.toString();
        final dept = AppConstants.getNormalizedDeptName(rawDept);

        return [
          index.toString(),
          (data['name'] ?? '').toString(),
          (data['designation'] ?? '-').toString(),
          AppConstants.getLocalizedDeptName(dept),
          totalLeaves.toStringAsFixed(1),
          usedLeaves.toStringAsFixed(1),
          balance.toStringAsFixed(1),
        ];
      }).toList();

      String displayDept = filterDept == null
          ? AppLocalizations.get('all_departments')
          : AppConstants.getLocalizedDeptName(filterDept);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context context) {
            return pw.Column(
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
                    '${AppLocalizations.get('department')}: $displayDept',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 14,
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
                  child: pw.Text(
                    'Leave Master List - $monthYear',
                    style: pw.TextStyle(
                      font: ttfBold,
                      fontSize: 13,
                      color: PdfColors.blueGrey700,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
              ],
            );
          },
          build: (pw.Context context) {
            return [
              pw.TableHelper.fromTextArray(
                context: context,
                cellPadding: const pw.EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 6,
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
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.center,
                  5: pw.Alignment.center,
                  6: pw.Alignment.center,
                },
                columnWidths: {
                  0: const pw.FixedColumnWidth(35),
                  1: const pw.FlexColumnWidth(2.5),
                  2: const pw.FlexColumnWidth(1.8),
                  3: const pw.FlexColumnWidth(1.8),
                  4: const pw.FixedColumnWidth(60),
                  5: const pw.FixedColumnWidth(60),
                  6: const pw.FixedColumnWidth(55),
                },
                headers: [
                  AppLocalizations.get('sr_no'),
                  AppLocalizations.get('full_name'),
                  AppLocalizations.get('designation'),
                  AppLocalizations.get('department'),
                  AppLocalizations.get('total_leaves'),
                  AppLocalizations.get('used_leaves'),
                  AppLocalizations.get('balance'),
                ],
                data: tableData,
              ),
            ];
          },
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'Employee_List_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error generating PDF: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportToExcel(String? filterDept) async {
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
      sheetObject.setColumnWidth(1, 22.0);
      sheetObject.setColumnWidth(2, 18.0);
      sheetObject.setColumnWidth(3, 18.0);
      sheetObject.setColumnWidth(4, 12.0);
      sheetObject.setColumnWidth(5, 15.0);
      sheetObject.setColumnWidth(6, 12.0);

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
          CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex),
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
      String displayDept = filterDept == null
          ? AppLocalizations.get('all_departments')
          : AppConstants.getLocalizedDeptName(filterDept);

      addMergeCentered(AppLocalizations.get('org_name'), 0, titleStyle);
      addMergeCentered(AppLocalizations.get('sub_org_name'), 1, subTitleStyle);
      addMergeCentered(
        '${AppLocalizations.get('department')}: $displayDept',
        2,
        subTitleStyle,
      );
      addMergeCentered(
        'Leave Master List - ${AppLocalizations.get('month')}: $monthYear',
        3,
        subTitleStyle,
      );
      sheetObject.appendRow([TextCellValue('')]);
      sheetObject.appendRow([TextCellValue('')]);

      sheetObject.appendRow([
        TextCellValue(AppLocalizations.get('sr_no')),
        TextCellValue(AppLocalizations.get('full_name')),
        TextCellValue(AppLocalizations.get('designation')),
        TextCellValue(AppLocalizations.get('department')),
        TextCellValue(AppLocalizations.get('total_leaves')),
        TextCellValue(AppLocalizations.get('used_leaves')),
        TextCellValue(AppLocalizations.get('balance')),
      ]);

      for (int i = 0; i <= 6; i++) {
        sheetObject
                .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 6))
                .cellStyle =
            headerStyle;
      }

      final allDocs = querySnapshot.docs;
      final targetDocs = allDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final rawDept = data['department']?.toString();
        final dept = AppConstants.getNormalizedDeptName(rawDept);

        if (_adminAllowedDepts != null &&
            !_adminAllowedDepts!.contains(dept) &&
            dept != 'Unassigned') {
          return false;
        }
        if (filterDept != null && dept != filterDept) return false;
        return true;
      }).toList();

      if (targetDocs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No employees found for this selection."),
            ),
          );
        }
        setState(() => _isExporting = false);
        return;
      }

      int currentRow = 7;
      int srNo = 1;
      for (var doc in targetDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final balance = (data['leaveBalance'] ?? 0.0).toDouble();
        final totalLeaves = AppConstants.defaultAnnualLeaves;
        final usedLeaves = totalLeaves - balance;

        final rawDept = data['department']?.toString();
        final dept = AppConstants.getNormalizedDeptName(rawDept);

        sheetObject.appendRow([
          TextCellValue((srNo++).toString()),
          TextCellValue((data['name'] ?? '').toString()),
          TextCellValue((data['designation'] ?? '-').toString()),
          TextCellValue(AppConstants.getLocalizedDeptName(dept)),
          TextCellValue(totalLeaves.toStringAsFixed(1)),
          TextCellValue(usedLeaves.toStringAsFixed(1)),
          TextCellValue(balance.toStringAsFixed(1)),
        ]);

        for (int i = 0; i <= 6; i++) {
          sheetObject
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: i,
                  rowIndex: currentRow,
                ),
              )
              .cellStyle = (i == 1 || i == 2 || i == 3)
              ? normalLeft
              : normalCenter;
        }

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
    } catch (e) {
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

    List<String> dropdownOptions =
        _adminAllowedDepts ?? AppConstants.allDepartments;
    String selectedDept = dropdownOptions.first;

    if (isEditing) {
      final oldDept = employeeToEdit['department']?.toString();
      final normalizedDept = AppConstants.getNormalizedDeptName(oldDept);
      if (normalizedDept != 'Unassigned') selectedDept = normalizedDept;
    }

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
                Text(
                  isEditing ? "Edit Employee Details" : "Add New Employee",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
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
                    if (isEditing) {
                      await _db.updateEmployee(
                        employeeToEdit.id,
                        nameCtrl.text.trim(),
                        desigCtrl.text.trim(),
                        phoneCtrl.text.trim(),
                        selectedDept,
                        photoUrl:
                            employeeToEdit['photoUrl'], // Keep existing photo
                      );
                    } else {
                      await _db.addEmployee(
                        nameCtrl.text.trim(),
                        desigCtrl.text.trim(),
                        phoneCtrl.text.trim(),
                        selectedDept,
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAdmin) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    List<String> tabs = ['All Departments', ...AppConstants.allDepartments];

    // Helper method to display localized tab name
    String displayTabName(String tab) {
      return tab == 'All Departments'
          ? AppLocalizations.get('all_departments')
          : AppConstants.getLocalizedDeptName(tab);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          AppLocalizations.get('employee_list'),
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
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
              tooltip: 'Download PDF',
              onPressed: () => _showExportOptions(true),
            ),
            IconButton(
              icon: const Icon(Icons.table_view_outlined, color: Colors.green),
              tooltip: 'Download Excel',
              onPressed: () => _showExportOptions(false),
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
                  AppLocalizations.get('sub_org_name'),
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
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: AppLocalizations.get('search_hint'),
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search, color: Colors.blueGrey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          setState(() => _searchQuery = '');
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
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final isSelected = _selectedTab == tab;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(
                      displayTabName(tab),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : Colors.blueGrey.shade700,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedTab = tab);
                    },
                    selectedColor: Colors.blue,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? Colors.blue : Colors.grey.shade300,
                    ),
                  ),
                );
              },
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
                  return _buildEmptyState(AppLocalizations.get('no_employees'));
                }

                final allEmployees = snapshot.data!.docs;
                final filteredEmployees = allEmployees.where((emp) {
                  final data = emp.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final designation = (data['designation'] ?? '')
                      .toString()
                      .toLowerCase();
                  final rawDept = data['department']?.toString();
                  final dept = AppConstants.getNormalizedDeptName(rawDept);

                  bool matchesSearch =
                      name.contains(_searchQuery) ||
                      designation.contains(_searchQuery);
                  bool matchesTab =
                      _selectedTab == 'All Departments' || dept == _selectedTab;

                  return matchesSearch && matchesTab;
                }).toList();

                if (filteredEmployees.isEmpty) {
                  return _buildEmptyState(AppLocalizations.get('no_matches'));
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
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                                columns: [
                                  DataColumn(
                                    label: Expanded(
                                      child: Center(
                                        child: Text(
                                          AppLocalizations.get('sr_no'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blueGrey,
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
                                          AppLocalizations.get('full_name'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blueGrey,
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
                                          AppLocalizations.get('designation'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blueGrey,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Expanded(
                                      child: Center(
                                        child: Text(
                                          AppLocalizations.get('department'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blueGrey,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Expanded(
                                      child: Center(
                                        child: Text(
                                          AppLocalizations.get('total_leaves'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blueGrey,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Expanded(
                                      child: Center(
                                        child: Text(
                                          AppLocalizations.get('used_leaves'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blueGrey,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Expanded(
                                      child: Center(
                                        child: Text(
                                          AppLocalizations.get('balance'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blueGrey,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_isAdmin)
                                    DataColumn(
                                      label: Expanded(
                                        child: Center(
                                          child: Text(
                                            AppLocalizations.get('action'),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blueGrey,
                                            ),
                                          ),
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
                                  final totalLeaves =
                                      AppConstants.defaultAnnualLeaves;
                                  final usedLeaves = totalLeaves - balance;

                                  final rawDept = data['department']
                                      ?.toString();
                                  final department =
                                      AppConstants.getNormalizedDeptName(
                                        rawDept,
                                      );
                                  final displayDepartment =
                                      AppConstants.getShortDeptName(department);

                                  final photoUrl = data['photoUrl']?.toString();

                                  bool isLegacyOrUnassigned =
                                      department == 'Unassigned' ||
                                      !AppConstants.allDepartments.contains(
                                        department,
                                      );
                                  bool hasEditAccess =
                                      _isAdmin &&
                                      (_adminAllowedDepts == null ||
                                          _adminAllowedDepts!.contains(
                                            department,
                                          ) ||
                                          isLegacyOrUnassigned);

                                  return DataRow(
                                    color: WidgetStateProperty.all(
                                      index % 2 == 0
                                          ? Colors.white
                                          : Colors.grey.shade50,
                                    ),
                                    cells: [
                                      DataCell(
                                        Center(
                                          child: Text(
                                            index.toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          alignment: Alignment.centerLeft,
                                          child: InkWell(
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    EmployeeDetailsScreen(
                                                      employeeId: emp.id,
                                                      employeeName:
                                                          data['name'] ?? '',
                                                      employeePhone:
                                                          data['phone'] ?? '',
                                                      isAdmin: hasEditAccess,
                                                    ),
                                              ),
                                            ),
                                            onLongPress: hasEditAccess
                                                ? () =>
                                                      _showAddEmployeeSheet(emp)
                                                : null,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8.0,
                                                  ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  CircleAvatar(
                                                    radius: 14,
                                                    backgroundColor:
                                                        Colors.blue.shade100,
                                                    backgroundImage:
                                                        (photoUrl != null &&
                                                            photoUrl.isNotEmpty)
                                                        ? NetworkImage(photoUrl)
                                                        : null,
                                                    child:
                                                        (photoUrl == null ||
                                                            photoUrl.isEmpty)
                                                        ? Text(
                                                            data['name'] !=
                                                                        null &&
                                                                    data['name']
                                                                        .toString()
                                                                        .isNotEmpty
                                                                ? data['name'][0]
                                                                      .toString()
                                                                      .toUpperCase()
                                                                : '?',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .blue,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          )
                                                        : null,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    data['name'] ?? 'Unknown',
                                                    style: const TextStyle(
                                                      color: Colors.blue,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            data['designation'] ?? '-',
                                            style: const TextStyle(
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Center(
                                          child: Text(
                                            displayDepartment,
                                            style: TextStyle(
                                              color: Colors.blueGrey.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Center(
                                          child: Text(
                                            totalLeaves.toStringAsFixed(1),
                                            style: const TextStyle(
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Center(
                                          child: Text(
                                            usedLeaves.toStringAsFixed(1),
                                            style: const TextStyle(
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Center(
                                          child: Container(
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
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: balance <= 0
                                                    ? Colors.grey.shade400
                                                    : balance <= 2
                                                    ? Colors.red.shade200
                                                    : Colors.green.shade200,
                                              ),
                                            ),
                                            child: Text(
                                              balance.toStringAsFixed(1),
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
                                      ),
                                      if (_isAdmin)
                                        DataCell(
                                          Center(
                                            child: hasEditAccess
                                                ? IconButton(
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                      color: Colors.redAccent,
                                                    ),
                                                    tooltip: 'Delete Employee',
                                                    splashRadius: 24,
                                                    onPressed: () =>
                                                        _confirmDelete(
                                                          emp.id,
                                                          data['name'] ??
                                                              'Unknown',
                                                        ),
                                                  )
                                                : const SizedBox.shrink(),
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
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showAddEmployeeSheet(),
              backgroundColor: Colors.blue,
              elevation: 4,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                AppLocalizations.get('add_new'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            )
          : null,
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
