import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class Notification {
  final String id;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? rideId;
  final String? type;

  Notification({
    required this.id,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.rideId,
    this.type,
  });

  // Factory constructor to create a Notification from Firestore data
  factory Notification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Notification data is null');
    }

    return Notification(
      id: doc.id,
      message: data['message'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
      rideId: data['rideId'] as String?,
      type: data['type'] as String?,
    );
  }

  // Convert Notification to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'rideId': rideId,
      'type': type,
    };
  }
}

class NotificationService {
  static const String notificationsCollection = 'notifications';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new notification
  static Future<String?> createNotification({
    required String message,
    String? rideId,
    String? type,
    bool isRead = false,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not signed in');
      }

      final notificationRef = _firestore
          .collection(notificationsCollection)
          .doc(); // Auto-generated ID

      final notificationData = {
        'userId': user.uid,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': isRead,
        'rideId': rideId,
        'type': type ?? 'general',
      };

      await notificationRef.set(notificationData);
      return notificationRef.id;
    } catch (e) {
      print('Error creating notification: $e');
      return null;
    }
  }

  // Get all notifications for the current user
  static Stream<List<Notification>> getUserNotifications() {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not signed in');
      }

      return _firestore
          .collection(notificationsCollection)
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => Notification.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      print('Error getting notifications: $e');
      return Stream.value([]);
    }
  }

  // Get unread notifications count for the current user
  static Stream<int> getUnreadNotificationsCount() {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not signed in');
      }

      return _firestore
          .collection(notificationsCollection)
          .where('userId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    } catch (e) {
      print('Error getting unread notifications count: $e');
      return Stream.value(0);
    }
  }

  // Mark a specific notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not signed in');
      }

      await _firestore
          .collection(notificationsCollection)
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read for the current user
  static Future<void> markAllAsRead() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not signed in');
      }

      final notifications = await _firestore
          .collection(notificationsCollection)
          .where('userId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Delete a specific notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not signed in');
      }

      await _firestore
          .collection(notificationsCollection)
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Delete all notifications for the current user
  static Future<void> deleteAllNotifications() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not signed in');
      }

      final notifications = await _firestore
          .collection(notificationsCollection)
          .where('userId', isEqualTo: user.uid)
          .get();

      final batch = _firestore.batch();
      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error deleting all notifications: $e');
    }
  }

  // Create ride-related notifications
  static Future<String?> createRideNotification({
    required String rideId,
    required String message,
    required String type, // 'cancelled', 'accepted', 'completed', etc.
  }) async {
    return createNotification(
      message: message,
      rideId: rideId,
      type: 'ride_$type',
    );
  }
}