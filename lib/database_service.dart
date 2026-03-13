import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'app_constants.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _employees => _db.collection('employees');
  CollectionReference get _users => _db.collection('users');

  // ==========================================
  // 1. EMPLOYEE MANAGEMENT & PHOTOS
  // ==========================================

  Stream<QuerySnapshot> getEmployeesStream() {
    return _employees.orderBy('name').snapshots();
  }

  // Upload Photo to Firebase Storage
  Future<String?> uploadProfilePhoto(String employeeId, File imageFile) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('employee_photos')
          .child('$employeeId.jpg');

      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> addEmployee(
    String name,
    String designation,
    String phone,
    String department, {
    String? photoUrl,
  }) async {
    await _employees.add({
      'name': name,
      'designation': designation,
      'phone': phone,
      'department': department,
      'photoUrl': photoUrl,
      'leaveBalance': AppConstants.defaultAnnualLeaves,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateEmployee(
    String id,
    String name,
    String designation,
    String phone,
    String department, {
    String? photoUrl,
  }) async {
    Map<String, dynamic> dataToUpdate = {
      'name': name,
      'designation': designation,
      'phone': phone,
      'department': department,
    };

    if (photoUrl != null) {
      dataToUpdate['photoUrl'] = photoUrl;
    }

    await _employees.doc(id).update(dataToUpdate);
  }

  Future<void> deleteEmployee(String id) async {
    await _employees.doc(id).delete();
  }

  // ==========================================
  // 2. LEAVE MANAGEMENT
  // ==========================================

  Stream<QuerySnapshot> getEmployeeLeavesStream(String employeeId) {
    return _employees
        .doc(employeeId)
        .collection('leaves')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

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
      if (!empSnap.exists) throw Exception("Employee does not exist!");

      double currentBalance =
          (empSnap.data() as Map<String, dynamic>)['leaveBalance']
              ?.toDouble() ??
          0.0;

      newBalance = currentBalance - daysUsed;

      if (newBalance < 0) {
        throw Exception(
          "Not enough leave balance. Only $currentBalance days remaining.",
        );
      }

      transaction.update(empRef, {'leaveBalance': newBalance});
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

  Future<void> deleteLeave(
    String employeeId,
    String leaveId,
    double daysRefund,
  ) async {
    final empRef = _employees.doc(employeeId);
    final leaveRef = empRef.collection('leaves').doc(leaveId);

    await _db.runTransaction((transaction) async {
      final empSnap = await transaction.get(empRef);
      if (!empSnap.exists) throw Exception("Employee does not exist!");

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

  Future<void> resetAllYearlyLeaves({double? defaultBalance}) async {
    final targetBalance = defaultBalance ?? AppConstants.defaultAnnualLeaves;
    final snapshot = await _employees.get();
    final batch = _db.batch();

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'leaveBalance': targetBalance});
    }

    await batch.commit();
  }

  // ==========================================
  // 4. ADMIN & USER MANAGEMENT
  // ==========================================

  Future<bool> isCurrentUserAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final doc = await _users.doc(user.uid).get();
      if (doc.exists) {
        return (doc.data() as Map<String, dynamic>)['isAdmin'] ?? false;
      }
    } catch (e) {
      // Ignore error
    }
    return false;
  }

  Stream<QuerySnapshot> getUsersStream() {
    return _users.orderBy('email').snapshots();
  }

  Future<void> updateAdminStatus(String userId, bool isAdmin) async {
    await _users.doc(userId).set({'isAdmin': isAdmin}, SetOptions(merge: true));
  }
}
