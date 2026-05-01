import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project/features/main_screen.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:project/features/report/report_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const UrbanEyeApp());
}

class UrbanEyeApp extends StatelessWidget {
  const UrbanEyeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReportController(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'UrbanEye',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
        ),
        home: MainScreen(auth: FirebaseAuth.instance),
      ),
    );
  }
}