import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project/features/main_screen.dart';
import 'package:project/features/report/my_reports_screen.dart';
import 'package:project/services/report_service.dart';
import 'package:project/services/user_role.dart';
import 'package:project/services/user_role_service.dart';

class ProfileScreen extends StatelessWidget {
  final FirebaseAuth auth;
  final ReportServiceBase service;

  const ProfileScreen({
    super.key,
    required this.auth,
    this.service = const ReportService(),
  });

  // navigate to MyReportsScreen
  void _openMyReports(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyReportsScreen(auth: auth, service: service),
      ),
    );
  }

  // navigate to MainScreen
  void _openMain(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MainScreen(auth: auth)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('UrbanEye', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(
              'Hello, ${user?.email ?? 'user'}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            FutureBuilder<UserRole>(
              future: const UserRoleService().getRole(user!),
              builder: (context, roleSnapshot) {
                if (roleSnapshot.data == UserRole.authority) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user,
                        size: 14,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Autoridade',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 60),
            FilledButton.icon(
              onPressed: () => _openMyReports(context),
              icon: const Icon(Icons.list_alt),
              label: const Text('My Reports'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openMain(context),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Report a problem'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => auth.signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}