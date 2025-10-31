import 'package:flutter/material.dart';
import 'package:flutter_application_test/app/views/screens/common/auth_gate.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_application_test/utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

 
  AppLogger.initialize();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Thợ Sửa Khoá',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).primaryColor,
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}
