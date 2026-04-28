import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project/features/report/report_screen.dart';
import 'package:project/features/auth/auth_screen.dart';
import 'package:project/features/auth/profile_screen.dart';
import 'package:project/features/map_screen.dart';
import 'package:project/services/report_service.dart';

class MainScreen extends StatelessWidget {
  final FirebaseAuth auth;
  final ReportServiceBase reportService;

  const MainScreen({
    super.key,
    required this.auth,
    this.reportService = const ReportService(),
  });

  // navigate to ReportScreen
  void _openReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReportScreen(auth: auth)),
    );
  }

  // navigate to AuthScreen
  void _goToAuth(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AuthScreen(service: reportService),
      ),
    );
  }

  // navigate to ProfileScreen
  void _goToProfile(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          auth: auth,
          service: reportService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // show map and report button
      appBar: AppBar(
        title: const Text('Home Screen'),
        automaticallyImplyLeading: false,
        actions: [
          StreamBuilder<User?>(
            stream: auth.authStateChanges(),
            builder: (context, snapshot) {
              final user = snapshot.data;

              if (user == null) {
                //not logged in
                return TextButton(
                  onPressed: () => _goToAuth(context),
                  child: const Text('Login / Register'),
                );
              } else {
                //logged in
                return TextButton(
                  onPressed: () => _goToProfile(context),
                  child: const Text('Profile'),
                );
              }
            },
          ),
        ],
      ),

      body: Stack(
        children: [
          const MapScreen(),

          Positioned(
            //report button
            left: 16,
            right: 16,
            bottom: 20,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _openReport(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: const Text(
                  'Report a Problem',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}