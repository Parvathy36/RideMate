import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

class AdminService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all pending driver registrations
  static Future<List<Map<String, dynamic>>> getPendingDrivers() async {
    return await FirestoreService.getPendingDrivers();
  }

  // Get all approved drivers
  static Future<List<Map<String, dynamic>>> getApprovedDrivers() async {
    return await FirestoreService.getApprovedDrivers();
  }

  // Approve a driver
  static Future<void> approveDriver({
    required String userId,
    String? adminNotes,
  }) async {
    try {
      await FirestoreService.updateDriverApprovalStatus(
        userId: userId,
        isApproved: true,
        adminNotes: adminNotes,
      );
      print('✅ Driver approved successfully');
    } catch (e) {
      print('❌ Error approving driver: $e');
      throw Exception('Failed to approve driver: $e');
    }
  }

  // Reject a driver
  static Future<void> rejectDriver({
    required String userId,
    String? adminNotes,
  }) async {
    try {
      await FirestoreService.updateDriverApprovalStatus(
        userId: userId,
        isApproved: false,
        adminNotes: adminNotes,
      );
      print('✅ Driver rejected successfully');
    } catch (e) {
      print('❌ Error rejecting driver: $e');
      throw Exception('Failed to reject driver: $e');
    }
  }

  // Get driver details by ID
  static Future<Map<String, dynamic>?> getDriverDetails(String userId) async {
    return await FirestoreService.getDriverData(userId);
  }

  // Get all users (drivers and regular users)
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('❌ Error getting all users: $e');
      return [];
    }
  }

  // Get system statistics
  static Future<Map<String, int>> getSystemStats() async {
    try {
      final futures = await Future.wait([
        _firestore
            .collection('users')
            .where('userType', isEqualTo: 'user')
            .get(),
        _firestore
            .collection('users')
            .where('userType', isEqualTo: 'driver')
            .get(),
        _firestore
            .collection('users')
            .where('userType', isEqualTo: 'driver')
            .where('isApproved', isEqualTo: true)
            .get(),
        _firestore
            .collection('users')
            .where('userType', isEqualTo: 'driver')
            .where('isApproved', isEqualTo: false)
            .get(),
      ]);

      return {
        'totalUsers': futures[0].docs.length,
        'totalDrivers': futures[1].docs.length,
        'approvedDrivers': futures[2].docs.length,
        'pendingDrivers': futures[3].docs.length,
      };
    } catch (e) {
      print('❌ Error getting system stats: $e');
      return {
        'totalUsers': 0,
        'totalDrivers': 0,
        'approvedDrivers': 0,
        'pendingDrivers': 0,
      };
    }
  }

  // Delete a user (admin only)
  static Future<void> deleteUser(String userId) async {
    try {
      // Delete from both collections
      await Future.wait([
        _firestore.collection('users').doc(userId).delete(),
        _firestore.collection('drivers').doc(userId).delete(),
      ]);
      print('✅ User deleted successfully');
    } catch (e) {
      print('❌ Error deleting user: $e');
      throw Exception('Failed to delete user: $e');
    }
  }

  // Update user data (admin only)
  static Future<void> updateUserData({
    required String userId,
    required Map<String, dynamic> updateData,
  }) async {
    try {
      updateData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('users').doc(userId).update(updateData);

      // If it's a driver, also update drivers collection
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data()?['userType'] == 'driver') {
        await _firestore.collection('drivers').doc(userId).update(updateData);
      }

      print('✅ User data updated successfully');
    } catch (e) {
      print('❌ Error updating user data: $e');
      throw Exception('Failed to update user data: $e');
    }
  }
}
