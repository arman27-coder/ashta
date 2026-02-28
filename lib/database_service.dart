import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection References
  CollectionReference get _employees => _db.collection('employees');

  // ==========================================
  // 1. EMPLOYEE MANAGEMENT
  // ==========================================

  // Stream all employees (ordered by name)
  Stream<QuerySnapshot> getEmployeesStream() {
    return _employees.orderBy('name').snapshots();
  }

  // Add a new employee
  Future<void> addEmployee(
    String name,
    String designation,
    String phone,
  ) async {
    await _employees.add({
      'name': name,
      'designation': designation,
      'phone': phone,
      'leaveBalance': 8.0, // Default starting balance
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Update an existing employee
  Future<void> updateEmployee(
    String id,
    String name,
    String designation,
    String phone,
  ) async {
    await _employees.doc(id).update({
      'name': name,
      'designation': designation,
      'phone': phone,
    });
  }

  // Delete an employee
  Future<void> deleteEmployee(String id) async {
    await _employees.doc(id).delete();
  }

  // ==========================================
  // 2. LEAVE MANAGEMENT
  // ==========================================

  // Stream leave history for a specific employee
  Stream<QuerySnapshot> getEmployeeLeavesStream(String employeeId) {
    return _employees
        .doc(employeeId)
        .collection('leaves')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Record a leave and automatically update balance
  Future<double> recordLeave({
    required String employeeId,
    required double daysUsed,
    required String reason,
    required DateTime fromDate,
    required DateTime toDate,
    required bool isHalfDay,
  }) async {
    final empRef = _employees.doc(employeeId);
    final leaveRef = empRef.collection('leaves').doc();

    double newBalance = 0.0;

    await _db.runTransaction((transaction) async {
      final empSnap = await transaction.get(empRef);

      if (!empSnap.exists) {
        throw Exception("कर्मचारी अस्तित्वात नाही!");
      }

      double currentBalance =
          (empSnap.data() as Map<String, dynamic>)['leaveBalance']
              ?.toDouble() ??
          0.0;

      newBalance = currentBalance - daysUsed;

      // Prevent balance from dropping below 0
      if (newBalance < 0) {
        throw Exception(
          "पुरेशी रजा शिल्लक नाही. फक्त $currentBalance दिवस शिल्लक आहेत.",
        );
      }

      // 1. Update Employee Balance
      transaction.update(empRef, {'leaveBalance': newBalance});

      // 2. Add Leave Record
      transaction.set(leaveRef, {
        'fromDate': Timestamp.fromDate(fromDate),
        'toDate': Timestamp.fromDate(toDate),
        'isHalfDay': isHalfDay,
        'daysUsed': daysUsed,
        'reason': reason,
        'previousBalance': currentBalance,
        'newBalance': newBalance,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });

    return newBalance;
  }

  // Delete a mistakenly added leave and refund balance
  Future<void> deleteLeave(
    String employeeId,
    String leaveId,
    double daysRefund,
  ) async {
    final empRef = _employees.doc(employeeId);
    final leaveRef = empRef.collection('leaves').doc(leaveId);

    await _db.runTransaction((transaction) async {
      final empSnap = await transaction.get(empRef);
      if (!empSnap.exists) throw Exception("कर्मचारी अस्तित्वात नाही!");

      // Refund the days back to current balance
      double currentBalance =
          (empSnap.data() as Map<String, dynamic>)['leaveBalance']
              ?.toDouble() ??
          0.0;
      double newBalance = currentBalance + daysRefund;

      transaction.update(empRef, {'leaveBalance': newBalance});
      transaction.delete(leaveRef);
    });
  }

  // ==========================================
  // 3. SETTINGS & BATCH ACTIONS
  // ==========================================

  // Reset ALL employees back to a default balance (e.g. 8.0 for new year)
  Future<void> resetAllYearlyLeaves({double defaultBalance = 8.0}) async {
    final snapshot = await _employees.get();
    final batch = _db.batch();

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'leaveBalance': defaultBalance});
    }

    await batch.commit();
  }
}
