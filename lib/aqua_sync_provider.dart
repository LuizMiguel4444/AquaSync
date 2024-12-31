import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AquaSyncProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  int myWaterConsumption = 0;
  int partnerWaterConsumption = 0;

  AquaSyncProvider() {
    _initializeMessaging();
    _subscribeToUpdates();
  }

  Future<void> _initializeMessaging() async {
    await _messaging.requestPermission();
  }

  Future<void> addWater(int amount) async {
    myWaterConsumption += amount;
    await _firestore.collection('water_tracker').doc('shared_data').set({
      'myWaterConsumption': myWaterConsumption,
      'partnerWaterConsumption': partnerWaterConsumption,
    });
    _sendNotification(amount);
    notifyListeners();
  }

  Future<void> _sendNotification(int amount) async {
    // Firebase Cloud Messaging logic to send notifications
    await _firestore.collection('notifications').add({
      'message': 'Seu parceiro(a) bebeu $amount ml de água!',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _subscribeToUpdates() {
    _firestore.collection('water_tracker').doc('shared_data').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        myWaterConsumption = data['myWaterConsumption'] ?? 0;
        partnerWaterConsumption = data['partnerWaterConsumption'] ?? 0;
        notifyListeners();
      }
    });
  }
}
