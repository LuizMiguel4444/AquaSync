// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


class AquaSyncProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  User? user;
  int myWaterConsumption = 0;
  int partnerWaterConsumption = 0;
  Map<String, dynamic>? firebaseServiceAccount;

  AquaSyncProvider() {
    _checkUser();
    _loadFirebaseServiceAccount();
    _initializeLocalNotifications();
  }

  void _checkUser() {
    user = _auth.currentUser;
    if (user != null) {
      _initializeMessaging();
      _subscribeToUpdates();
    }
    notifyListeners();
  }

  Future<void> _loadFirebaseServiceAccount() async {
    // Carregar o arquivo JSON das credenciais do `assets`
    final data = await rootBundle.loadString('assets/firebase-service-account.json');
    firebaseServiceAccount = jsonDecode(data);
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      user = userCredential.user;

      await initializeData();
      notifyListeners();
    } catch (e) {
      throw Exception('Erro ao fazer login com Google: ${e.toString()}');
    }
  }

  Future<void> initializeData() async {
    if (user == null) return;

    final userDocRef = _firestore.collection('users').doc(user!.uid);
    final trackerDocRef = _firestore.collection('water_tracker').doc(user!.uid);
    final fcmToken = await _messaging.getToken();

    final userDoc = await userDocRef.get();
    if (!userDoc.exists) {
      await userDocRef.set({
        'myWaterConsumption': 0,
        'partnerWaterConsumption': 0,
        'fcmToken': fcmToken,
        'uid': user!.uid,
      });
    }

    final trackerDoc = await trackerDocRef.get();
    if (!trackerDoc.exists) {
      await trackerDocRef.set({
        'myWaterConsumption': 0,
        'partnerWaterConsumption': 0,
        'uid': user!.uid,
      });
    }
  }

  Future<void> addWater(int amount) async {
    if (user == null) return;

    myWaterConsumption += amount;

    // Receber minhas próprias notificações ou não
    bool notifySelf = true;

    // Atualizar o Firestore em `users`
    await _firestore.collection('users').doc(user!.uid).set({
      'myWaterConsumption': myWaterConsumption,
    }, SetOptions(merge: true));

    // Atualizar o Firestore com o novo consumo
    await _firestore.collection('water_tracker').doc(user!.uid).set({
      'myWaterConsumption': myWaterConsumption,
    }, SetOptions(merge: true));

    // Obter tokens FCM dos usuários e enviar notificações
    final userDocs = await _firestore.collection('users').get();
    for (var doc in userDocs.docs) {
      final data = doc.data();
      final token = data['fcmToken'];

      if (token != null && (notifySelf)) {
        // Enviar notificação para o dispositivo com o token correspondente
        await _sendPushNotificationV1(
          token,
          doc.id == user!.uid
              ? 'Seu consumo foi atualizado!'
              : 'Atualização no consumo de um amigo!',
          doc.id == user!.uid
              ? 'Você adicionou $amount ml ao seu consumo de água.'
              : '${user!.displayName ?? "Um usuário"} adicionou $amount ml ao consumo de água.',
        );
      }
    }

    notifyListeners();
  }

  void _subscribeToUpdates() {
    if (user == null) return;

    // Atualizações da coleção `water_tracker`
    _firestore.collection('water_tracker').doc(user!.uid).snapshots().listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        myWaterConsumption = data['myWaterConsumption'] ?? 0;
        notifyListeners();
      }
    });

    // Atualizações da coleção `users`
    _firestore.collection('users').doc(user!.uid).snapshots().listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        partnerWaterConsumption = data['partnerWaterConsumption'] ?? 0;
        notifyListeners();
      }
    });
  }

  Future<void> _initializeMessaging() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await _messaging.getToken();
      if (token != null && user != null) {
        await _firestore.collection('users').doc(user!.uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
      }

      // Configurar recebimento de mensagens
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          _showNotification(
            message.notification!.title ?? 'Nova Notificação',
            message.notification!.body ?? 'Você tem uma nova mensagem!',
          );
          print('Mensagem recebida: ${message.notification!.title}');
        }
      });

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }
  }

  Future<void> _sendPushNotificationV1(String token, String title, String body) async {
    if (firebaseServiceAccount == null) {
      print("Credenciais do Firebase não foram carregadas!");
      return;
    }
    
    // Carregar credenciais diretamente do JSON já decodificado
    final credentials = ServiceAccountCredentials.fromJson(firebaseServiceAccount!);

    // Escopo para o Firebase Cloud Messaging
    const scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

    // Obter o cliente autenticado
    final client = await clientViaServiceAccount(credentials, scopes);

    // Construir o payload da notificação
    final payload = {
      'message': {
        'token': token,
        'notification': {
          'title': title,
          'body': body,
        },
        'android': {
          'priority': 'HIGH',
        },
        'apns': {
          'headers': {
            'apns-priority': '10',
          },
        },
      },
    };

    // Fazer a solicitação HTTP POST para a API FCM V1
    final url = 'https://fcm.googleapis.com/v1/projects/aquasync-48758/messages:send';
    final response = await client.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    // Verificar o status da resposta
    if (response.statusCode == 200) {
      print('Notificação enviada com sucesso!');
    } else {
      print('Erro ao enviar notificação: ${response.body}');
    }

    // Fechar o cliente
    client.close();
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    user = null;
    notifyListeners();
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: androidSettings);

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'channel_id', // ID do canal
      'Canal de Notificações', // Nome do canal
      channelDescription: 'Este canal é usado para notificações do app.',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(
      0, // ID da notificação
      title, // Título
      body, // Corpo
      notificationDetails,
    );
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Mensagem recebida em background: ${message.notification?.title}');
}
