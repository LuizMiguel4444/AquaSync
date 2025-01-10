import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:aquasync/aqua_sync_provider.dart';
import 'package:aquasync/aqua_sync_screen.dart';
import 'package:aquasync/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AquaSyncProvider(),
      child: MaterialApp(
        title: 'Water Tracker',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: Consumer<AquaSyncProvider>(
          builder: (context, provider, _) {
            return provider.user == null ? LoginScreen() : AquaSyncScreen();
          },
        ),
      ),
    );
  }
}
