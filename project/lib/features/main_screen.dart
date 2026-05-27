import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project/features/notifications/notification_bell.dart';
import 'package:project/features/report/report_screen.dart';
import 'package:project/features/auth/auth_screen.dart';
import 'package:project/features/auth/profile_screen.dart';
import 'package:project/features/map_screen.dart';
import 'package:project/features/report/all_reports_screen.dart';
import 'package:project/services/report_service.dart';

class MainScreen extends StatelessWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore? firestore;
  final ReportServiceBase reportService;

  MainScreen({
    super.key,
    required this.auth,
    this.firestore,
    ReportServiceBase? reportService, // Transforma em opcional nulo
  }) : reportService = reportService ?? ReportService();

  FirebaseFirestore get _firestore => firestore ?? FirebaseFirestore.instance;

  void _goToAllReports(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AllReportsScreen()),
    );
  }

  void _openReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReportScreen(auth: auth)),
    );
  }

  void _goToAuth(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => AuthScreen(service: reportService)),
    );
  }

  void _goToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(auth: auth, firestore: _firestore),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Screen'),
        automaticallyImplyLeading: false,
        actions: [
          const NotificationBell(),
          StreamBuilder<User?>(
            stream: auth.authStateChanges(),
            builder: (context, snapshot) {
              final user = snapshot.data;

              if (user == null) {
                return TextButton(
                  onPressed: () => _goToAuth(context),
                  child: const Text('Login / Register'),
                );
              }

              return TextButton(
                onPressed: () => _goToProfile(context),
                child: const Text('Profile'),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          const MapScreen(),
          // all Reports button
          Positioned(
            left: 16,
            bottom: 100,
            child: FloatingActionButton(
              heroTag: 'allReports',
              onPressed: () => _goToAllReports(context),
              tooltip: 'All Reports',
              child: const Icon(Icons.list_alt),
            ),
          ),
          Positioned(
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
