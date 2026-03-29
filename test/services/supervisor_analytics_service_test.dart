import 'package:flutter_test/flutter_test.dart';
import 'package:ridemate/services/supervisor_analytics_service.dart';
import 'package:ridemate/utils/location_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('SupervisorAnalyticsService Tests', () {
    test('Should aggregate ride data correctly for a region', () async {
      // Inject fake firestore
      SupervisorAnalyticsService.firestore = fakeFirestore;

      // Add mock rides
      final now = DateTime.now();
      await fakeFirestore.collection('rides').add({
        'rideId': 'ride1',
        'status': 'completed',
        'pickupLocation': const GeoPoint(9.9816, 76.2999), // Central (Ernakulam)
        'createdAt': Timestamp.fromDate(now),
      });

      await fakeFirestore.collection('rides').add({
        'rideId': 'ride2',
        'status': 'request',
        'pickupLocation': const GeoPoint(9.9500, 76.3000), // Central
        'createdAt': Timestamp.fromDate(now),
      });

      await fakeFirestore.collection('rides').add({
        'rideId': 'ride3',
        'status': 'completed',
        'pickupLocation': const GeoPoint(8.5241, 76.9366), // South (Trivandrum)
        'createdAt': Timestamp.fromDate(now),
      });

      // Add mock payments
      await fakeFirestore.collection('payments').add({
        'paymentId': 'pay1',
        'rideId': 'ride1',
        'amount': 500.0,
        'createdAt': Timestamp.fromDate(now),
      });

      final analytics = await SupervisorAnalyticsService.getRegionalAnalytics('Central', 'Today');

      expect(analytics.totalRides, 2);
      expect(analytics.completedRides, 1);
      expect(analytics.totalRevenue, 500.0);
      expect(analytics.completionRate, 50.0);
      expect(analytics.averageFare, 500.0);
      expect(analytics.statusDistribution['completed'], 1);
      expect(analytics.statusDistribution['request'], 1);
    });

    test('Should filter by Today time range', () async {
      SupervisorAnalyticsService.firestore = fakeFirestore;
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      await fakeFirestore.collection('rides').add({
        'rideId': 'today_ride',
        'status': 'completed',
        'pickupLocation': const GeoPoint(9.9816, 76.2999),
        'createdAt': Timestamp.fromDate(now),
      });

      await fakeFirestore.collection('rides').add({
        'rideId': 'yesterday_ride',
        'status': 'completed',
        'pickupLocation': const GeoPoint(9.9816, 76.2999),
        'createdAt': Timestamp.fromDate(yesterday),
      });

      final analytics = await SupervisorAnalyticsService.getRegionalAnalytics('Central', 'Today');
      expect(analytics.totalRides, 1);
    });
  });
}
