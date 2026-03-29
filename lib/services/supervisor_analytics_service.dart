import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/location_utils.dart';

class AnalyticsData {
  final int totalRides;
  final int completedRides;
  final double totalRevenue;
  final double averageFare;
  final Map<String, int> statusDistribution;
  final List<ChartPoint> volumeTrend;
  final List<ChartPoint> revenueTrend;

  AnalyticsData({
    required this.totalRides,
    required this.completedRides,
    required this.totalRevenue,
    required this.averageFare,
    required this.statusDistribution,
    required this.volumeTrend,
    required this.revenueTrend,
  });

  double get completionRate => totalRides > 0 ? (completedRides / totalRides) * 100 : 0;
}

class ChartPoint {
  final DateTime label;
  final double value;

  ChartPoint(this.label, this.value);
}

class SupervisorAnalyticsService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static set firestore(FirebaseFirestore instance) => _firestore = instance;

  static Future<AnalyticsData> getRegionalAnalytics(String region, String timeRange) async {
    final now = DateTime.now();
    DateTime startDate;

    switch (timeRange) {
      case 'Today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'Week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'Month':
        startDate = now.subtract(const Duration(days: 30));
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }

    // Fetch rides
    final ridesSnapshot = await _firestore
        .collection('rides')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .get();

    // Fetch payments
    final paymentsSnapshot = await _firestore
        .collection('payments')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .get();

    final allRides = ridesSnapshot.docs.map((doc) => doc.data()).toList();
    final allPayments = paymentsSnapshot.docs.map((doc) => doc.data()).toList();

    // Filter by region and time range in memory to avoid complex queries
    final regionalRides = allRides.where((data) {
      if (region == 'All Regions') return true;
      final location = data['pickupLocation'];
      final rideRegion = LocationUtils.getRegionFromLatLng(location);
      return rideRegion == region;
    }).toList();

    final regionalPayments = allPayments.where((data) {
      if (region == 'All Regions') return true;
      // Payments usually contain rideId, we'd ideally filter by the ride's region
      // For now, let's assume we can filter by the payer's region if available or just by amount
      // Actually, let's match payments to regional rides for accuracy
      final rideId = data['rideId'];
      return regionalRides.any((ride) => ride['rideId'] == rideId);
    }).toList();

    // Aggregate statistics
    int completedCount = 0;
    double totalRevenue = 0;
    Map<String, int> statusDist = {};

    for (var ride in regionalRides) {
      final status = ride['status'] ?? 'unknown';
      statusDist[status] = (statusDist[status] ?? 0) + 1;
      if (status == 'completed') {
        completedCount++;
      }
    }

    for (var payment in regionalPayments) {
      totalRevenue += (payment['amount'] ?? 0.0);
    }

    // Generate trends
    final volumeTrend = _generateTrend(regionalRides, startDate, now, 'count');
    final revenueTrend = _generateTrend(regionalPayments, startDate, now, 'amount');

    return AnalyticsData(
      totalRides: regionalRides.length,
      completedRides: completedCount,
      totalRevenue: totalRevenue,
      averageFare: completedCount > 0 ? totalRevenue / completedCount : 0,
      statusDistribution: statusDist,
      volumeTrend: volumeTrend,
      revenueTrend: revenueTrend,
    );
  }

  static List<ChartPoint> _generateTrend(List<Map<String, dynamic>> items, DateTime start, DateTime end, String valueKey) {
    final Map<String, double> grouped = {};
    final isToday = end.difference(start).inDays < 1;

    for (var item in items) {
      final createdAt = item['createdAt'] as Timestamp?;
      if (createdAt == null) continue;
      
      final date = createdAt.toDate();
      String key;
      if (isToday) {
        key = '${date.hour}:00';
      } else {
        key = '${date.month}/${date.day}';
      }

      if (valueKey == 'count') {
        grouped[key] = (grouped[key] ?? 0) + 1;
      } else {
        grouped[key] = (grouped[key] ?? 0) + (item[valueKey] ?? 0.0);
      }
    }

    // Fill missing gaps to ensure chart looks continuous
    List<ChartPoint> points = [];
    DateTime current = start;
    while (current.isBefore(end)) {
      String key;
      if (isToday) {
        key = '${current.hour}:00';
        current = current.add(const Duration(hours: 1));
      } else {
        key = '${current.month}/${current.day}';
        current = current.add(const Duration(days: 1));
      }
      points.add(ChartPoint(current, grouped[key] ?? 0.0));
    }

    return points;
  }
}
