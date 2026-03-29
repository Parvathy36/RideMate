import 'package:flutter_test/flutter_test.dart';
import 'package:ridemate/utils/location_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('LocationUtils Tests', () {
    test('Should return South for Thiruvananthapuram coordinates', () {
      final location = {'latitude': 8.5241, 'longitude': 76.9366};
      expect(LocationUtils.getRegionFromLatLng(location), 'South');
    });

    test('Should return Central for Ernakulam coordinates', () {
      final location = {'latitude': 9.9816, 'longitude': 76.2999};
      expect(LocationUtils.getRegionFromLatLng(location), 'Central');
    });

    test('Should return North for Kozhikode coordinates', () {
      final location = {'latitude': 11.2588, 'longitude': 75.7804};
      expect(LocationUtils.getRegionFromLatLng(location), 'North');
    });

    test('Should return North for Kasaragod coordinates', () {
      final location = {'latitude': 12.5101, 'longitude': 74.9852};
      expect(LocationUtils.getRegionFromLatLng(location), 'North');
    });

    test('Should handle GeoPoint object', () {
      final location = GeoPoint(9.4981, 76.3329); // Alappuzha (South)
      expect(LocationUtils.getRegionFromLatLng(location), 'South');
    });

    test('Should return Unknown for null or invalid coordinates', () {
      expect(LocationUtils.getRegionFromLatLng(null), 'Unknown');
      expect(LocationUtils.getRegionFromLatLng({}), 'Unknown');
      expect(LocationUtils.getRegionFromLatLng({'lat': 0.0, 'lng': 0.0}), 'Unknown');
    });

    test('Should map Palakkad to Central', () {
      final location = {'lat': 10.7867, 'lng': 76.6547};
      expect(LocationUtils.getRegionFromLatLng(location), 'Central');
    });

    test('Should map Wayanad to North', () {
      final location = {'lat': 11.6050, 'lng': 76.0828};
      expect(LocationUtils.getRegionFromLatLng(location), 'North');
    });
  });
}
