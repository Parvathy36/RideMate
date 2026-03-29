import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'lib/firebase_options.dart';
import 'lib/utils/location_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final snapshot = await FirebaseFirestore.instance
      .collection('rides')
      .get();
      
  print('Total rides found: ${snapshot.docs.length}');
  
  int centralRides = 0;
  for (var doc in snapshot.docs) {
    final data = doc.data();
    final location = data['pickupLocation'];
    final status = data['status'];
    final region = LocationUtils.getRegionFromLatLng(location);
    
    if (region == 'Central') {
      centralRides++;
      print('Ride ID: ${doc.id}, Status: $status, Location: $location');
    }
  }
  
  print('Total Central rides: $centralRides');
}
