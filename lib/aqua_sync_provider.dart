import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
  String? partnerDisplayName;
  String? partnerUid;
  Map<String, dynamic>? firebaseServiceAccount;
  final int dailyGoal = 3000;

  var isDarkMode = false.obs;

  AquaSyncProvider() {
    _checkUser();
    _loadFirebaseServiceAccount();
    _initializeLocalNotifications();
    _loadThemePreferences();
    _checkAndResetDailyConsumption();
  }

  void toggleTheme() async {
    isDarkMode.value = !isDarkMode.value;
    await _saveThemePreference();
    Get.changeThemeMode(isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> _loadThemePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    isDarkMode.value = prefs.getBool('isDarkMode') ?? false;
    Get.changeThemeMode(isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> _saveThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode.value);
  }

  void _checkUser() async {
    user = _auth.currentUser;
    if (user != null) {
      _loadUserData();
      _initializeMessaging();
      _subscribeToUpdates();
    }
    notifyListeners();
  }

  Future<void> _loadFirebaseServiceAccount() async {
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
    final fcmToken = await _messaging.getToken();

    final userDoc = await userDocRef.get();
    if (!userDoc.exists) {
      await userDocRef.set({
        'uid': user!.uid,
        'email': user!.email,
        'displayName': user!.displayName ?? 'Usuário',
        'myWaterConsumption': 0,
        'partnerUid': null,
        'fcmToken': fcmToken,
      });
    }
  }

  Future<void> addWater(int amount) async {
    if (user == null) return;

    if (amount <= 0) {
      Get.snackbar(
        "Valor Inválido",
        "O consumo de água deve ser um valor maior que zero.",
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    myWaterConsumption += amount;

    final now = DateTime.now();
    final today = now.toIso8601String().split('T').first;
    final timestamp = now.toIso8601String();
    final userDocRef = _firestore.collection('users').doc(user!.uid);
    final dailyRef = userDocRef.collection(today);

    // Atualiza o consumo do usuário
    await userDocRef.update({'myWaterConsumption': myWaterConsumption});

    // Atualiza a subcoleção do dia
    await dailyRef.doc('consumption').set({'amount': myWaterConsumption}, SetOptions(merge: true));

    // Salva um novo registro com o horário exato
    await dailyRef.doc(now.hour.toString().padLeft(2, '0') + now.minute.toString().padLeft(2, '0')).set({
      'amount': amount,
      'timestamp': timestamp,
    });

    // Notificar parceiro, se vinculado
    final partnerSnapshot = await _firestore.collection('users').doc(user!.uid).get();
    final partnerUid = partnerSnapshot.data()?['partnerUid'];

    if (partnerUid != null) {
      final partnerDoc = await _firestore.collection('users').doc(partnerUid).get();
      final partnerFcmToken = partnerDoc.data()?['fcmToken'];

      if (partnerFcmToken != null) {
        if (myWaterConsumption >= dailyGoal) {
          await _sendPushNotificationV1(
            partnerFcmToken,
            'Seu parceiro está de Parabéns! 🎉',
            '${user!.displayName ?? "Seu parceiro"} atingiu a meta diária de $dailyGoal ml de água!',
          );
        } else {
          await _sendPushNotificationV1(
            partnerFcmToken,
            'Seu parceiro bebeu água!',
            '${user!.displayName ?? "Um usuário"} adicionou $amount ml ao consumo de água.',
          );
        }
      }
    }

    notifyListeners();
  }

  Future<bool> setPartner(String partnerEmail) async {
    if (user == null) return false;

    try {
      // Impedir vínculo com a própria conta
      if (partnerEmail == user!.email) {
        return false;
      }

      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: partnerEmail)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return false;
      }

      final partnerDoc = querySnapshot.docs.first;
      partnerUid = partnerDoc.id;

      // Salvar o UID do parceiro no documento do usuário
      await _firestore.collection('users').doc(user!.uid).update({
        'partnerUid': partnerUid,
      });

      // Salvar o UID do usuário no documento do parceiro
      await _firestore.collection('users').doc(partnerUid).update({
        'partnerUid': user!.uid,
      });

      // Carregar informações do parceiro
      partnerDisplayName = partnerDoc.data()['displayName'];
      partnerWaterConsumption = partnerDoc.data()['myWaterConsumption'] ?? 0;

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getPartnerData() async {
    final partnerSnapshot = await _firestore.collection('partners').doc(user!.uid).get();
    final partnerUid = partnerSnapshot.data()?['partnerUid'];
    if (partnerUid == null) return null;

    final partnerDoc = await _firestore.collection('users').doc(partnerUid).get();
    return partnerDoc.data();
  }

  Future<void> removePartner() async {
    if (partnerUid == null || user == null) return;

    // Remover vínculo no Firestore
    await _firestore.collection('users').doc(user!.uid).update({
      'partnerUid': null,
    });

    await _firestore.collection('users').doc(partnerUid).update({
      'partnerUid': null,
    });

    partnerUid = null;
    partnerDisplayName = null;
    partnerWaterConsumption = 0;

    notifyListeners();
  }

  Future<void> _loadUserData() async {
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user!.uid).get();
    if (userDoc.exists) {
      final data = userDoc.data()!;
      myWaterConsumption = data['myWaterConsumption'] ?? 0;

      // Carregar dados do parceiro, se vinculado
      final partnerUid = data['partnerUid'];
      if (partnerUid != null) {
        final partnerDoc = await _firestore.collection('users').doc(partnerUid).get();
        if (partnerDoc.exists) {
          partnerWaterConsumption = partnerDoc.data()?['myWaterConsumption'] ?? 0;
          partnerDisplayName = partnerDoc.data()?['displayName'];
        }
      } else {
        partnerWaterConsumption = 0;
        partnerDisplayName = null;
      }

      notifyListeners();
    }
  }

  void _subscribeToUpdates() {
    if (user == null) return;

    // Atualizar consumo do usuário
    _firestore.collection('users').doc(user!.uid).snapshots().listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        myWaterConsumption = data['myWaterConsumption'] ?? 0;
        
        // Atualizar dados do parceiro se ele estiver vinculado
        final newPartnerUid = data['partnerUid'];
        if (newPartnerUid != null && newPartnerUid != partnerUid) {
          partnerUid = newPartnerUid;
          _loadUserData(); // Recarregar dados do parceiro
        }

        notifyListeners();
      }
    });

    // Atualizar dados do parceiro
    _firestore.collection('users').doc(user!.uid).snapshots().listen((snapshot) async {
      final partnerUid = snapshot.data()?['partnerUid'];
      if (partnerUid != null) {
        final partnerDoc = await _firestore.collection('users').doc(partnerUid).get();
        if (partnerDoc.exists) {
          partnerWaterConsumption = partnerDoc.data()?['myWaterConsumption'] ?? 0;
          partnerDisplayName = partnerDoc.data()?['displayName'];
          notifyListeners();
        }
      }
    });
  }

  Future<void> _ensureDailyConsumptionSaved(String date) async {
    if (user == null) return;

    final userDocRef = _firestore.collection('users').doc(user!.uid);
    final dailyRef = userDocRef.collection(date);

    final existingDoc = await dailyRef.doc('consumption').get();

    if (!existingDoc.exists) {
      // **Se o dia ainda não foi salvo, salva o consumo antes de zerar**
      await dailyRef.doc('consumption').set({'amount': myWaterConsumption}, SetOptions(merge: true));
    }
  }

  Future<void> _checkAndResetDailyConsumption() async {
    if (user == null) return;

    final now = DateTime.now();
    final today = now.toIso8601String().split('T').first;
    final yesterday = now.subtract(const Duration(days: 1)).toIso8601String().split('T').first;

    final prefs = await SharedPreferences.getInstance();
    String? lastSavedDate = prefs.getString('lastSavedDate');

    if (lastSavedDate != today) {
      // **Antes de zerar, verifica se o consumo do dia anterior já foi salvo**
      await _ensureDailyConsumptionSaved(yesterday);

      // **Zera apenas `myWaterConsumption` no documento principal do usuário**
      await _firestore.collection('users').doc(user!.uid).update({'myWaterConsumption': 0});
      myWaterConsumption = 0;

      // **Salva a nova data no SharedPreferences**
      await prefs.setString('lastSavedDate', today);
      notifyListeners();
    }
  }

  Future<Map<String, int>> getLast7DaysConsumption() async {
    if (user == null) return {};

    final now = DateTime.now();
    final last7Days = List.generate(7, (i) => now.subtract(Duration(days: i + 1)));
    final formattedDates = last7Days.map((date) => date.toIso8601String().split('T').first).toList();

    Map<String, int> history = {for (var date in formattedDates) date: 0};

    for (var date in formattedDates) {
      final doc = await _firestore
          .collection('users')
          .doc(user!.uid)
          .collection(date)
          .doc('consumption')
          .get();

      if (doc.exists) {
        history[date] = doc.data()?['amount'] ?? 0;
      }
    }

    return history;
  }

  Future<Map<String, int>> getLast7DaysPartnerConsumption() async {
    if (partnerUid == null) return {};

    final now = DateTime.now();
    final last7Days = List.generate(7, (i) => now.subtract(Duration(days: i + 1)));
    final formattedDates = last7Days.map((date) => date.toIso8601String().split('T').first).toList();

    Map<String, int> history = {for (var date in formattedDates) date: 0};

    for (var date in formattedDates) {
      final doc = await _firestore
          .collection('users')
          .doc(partnerUid)
          .collection(date)
          .doc('consumption')
          .get();

      if (doc.exists) {
        history[date] = doc.data()?['amount'] ?? 0;
      }
    }

    return history;
  }

  Future<List<Map<String, dynamic>>> getDailyConsumptionRecords(String date) async {
    if (user == null) return [];

    final dailyRef = _firestore.collection('users').doc(user!.uid).collection(date);
    final querySnapshot = await dailyRef.orderBy('timestamp', descending: true).get();

    return querySnapshot.docs.map((doc) {
      return {
        'amount': doc.data()['amount'] ?? 0,
        'timestamp': doc.data()['timestamp'] ?? '',
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getDailyConsumptionRecordsForPartner(String date) async {
    if (partnerUid == null) return [];

    final dailyRef = _firestore.collection('users').doc(partnerUid).collection(date);
    final querySnapshot = await dailyRef.orderBy('timestamp', descending: true).get();

    return querySnapshot.docs.map((doc) {
      return {
        'amount': doc.data()['amount'] ?? 0,
        'timestamp': doc.data()['timestamp'] ?? '',
      };
    }).toList();
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
        }
      });

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }
  }

  Future<void> _sendPushNotificationV1(String token, String title, String body) async {
    if (firebaseServiceAccount == null) {
      return;
    }
    
    // Carregar credenciais diretamente do JSON já decodificado
    final credentials = ServiceAccountCredentials.fromJson(firebaseServiceAccount!);

    // Escopo para o Firebase Cloud Messaging
    const scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

    // Obter o cliente autenticado
    final client = await clientViaServiceAccount(credentials, scopes, baseClient: http.Client());

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
    await client.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    client.close();
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();

    user = null;
    myWaterConsumption = 0;
    partnerWaterConsumption = 0;
    partnerDisplayName = null;
    partnerUid = null;

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

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}