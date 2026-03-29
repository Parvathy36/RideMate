import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'ridemate/firebase_options.dart'; // Ensure this path is correct

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .where('userType', isEqualTo: 'supervisor')
      .limit(5)
      .get();
      
  if (snapshot.docs.isEmpty) {
    print('No supervisor users found.');
  } else {
    for (var doc in snapshot.docs) {
      print('Supervisor: ${doc['email']}');
    }
  }
}
