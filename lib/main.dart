import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:aquasync/aqua_sync_provider.dart';
import 'package:aquasync/aqua_sync_screen.dart';
import 'package:aquasync/login_screen.dart';
import 'package:get/get.dart';
import 'package:aquasync/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final ThemeController themeController = Get.put(ThemeController());
  await themeController.loadTheme();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeController _themeController = Get.find();

    return Obx(() {
      return ChangeNotifierProvider(
        create: (_) => AquaSyncProvider(),
        child: GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Aqua Sync',
          themeMode: _themeController.isDarkMode.value ? ThemeMode.dark : ThemeMode.light,
          darkTheme: ThemeData.dark(),
          theme: ThemeData.light(),
          home: Consumer<AquaSyncProvider>(
            builder: (context, provider, _) {
              return provider.user == null ? LoginScreen() : AquaSyncScreen();
            },
          ),
        ),
      );
    });
  }
}
