import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project/features/report/report_screen.dart';
import 'package:project/features/auth/auth_screen.dart';
import 'package:project/features/auth/profile_screen.dart';
import 'package:project/features/map_screen.dart';
import 'package:project/services/report_service.dart';
import 'package:project/services/user_role.dart';
import 'package:project/services/user_role_service.dart';

class MainScreen extends StatefulWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore? firestore;
  final ReportServiceBase reportService;

  const MainScreen({
    super.key,
    required this.auth,
    this.firestore,
    this.reportService = const ReportService(),
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  UserRole _role = UserRole.citizen;

  FirebaseFirestore get _firestore =>
      widget.firestore ?? FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    widget.auth.authStateChanges().listen((user) {
      if (user != null) {
        const UserRoleService().getRole(user).then((role) {
          if (mounted) setState(() => _role = role);
        });
      } else {
        if (mounted) setState(() => _role = UserRole.citizen);
      }
    });
  }

  void _openReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReportScreen(auth: widget.auth)),
    );
  }

  void _goToAuth(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AuthScreen(service: widget.reportService),
      ),
    );
  }

  void _goToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          auth: widget.auth,
          firestore: _firestore,
          reportService: widget.reportService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAuthority = _role == UserRole.authority;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Screen'),
        automaticallyImplyLeading: false,
        actions: [
          StreamBuilder<User?>(
            stream: widget.auth.authStateChanges(),
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
          // Botão "Report a Problem" — só para citizens
          if (!isAuthority)
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