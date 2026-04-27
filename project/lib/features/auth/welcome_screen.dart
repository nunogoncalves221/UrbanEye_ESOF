// ============================================================
// THIS FILE IS NOT USED -> KEPT FOR REFERENCE
// Functionality split into:
//   - AuthScreen (unauthenticated)
//   - ProfileScreen (authenticated)
// ============================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project/features/auth/login_screen.dart';
import 'package:project/features/auth/register_screen.dart';
import 'package:project/features/main_screen.dart';
import 'package:project/features/report/my_reports_screen.dart';
import 'package:project/services/report_service.dart';
import 'package:project/services/user_role.dart';
import 'package:project/services/user_role_service.dart';

class WelcomeScreen extends StatelessWidget {
  final FirebaseAuth? auth;
  final ReportServiceBase service;

  const WelcomeScreen({
    super.key,
    this.auth,
    this.service = const ReportService(),
  });

  FirebaseAuth get _auth => auth ?? FirebaseAuth.instance;

  void _openLogin(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _openRegister(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  void _openMyReports(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyReportsScreen(auth: _auth, service: service),
      ),
    );
  }

  void _openMain(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MainScreen(auth: _auth)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: _auth.authStateChanges(),
        builder: (context, snapshot) {
          final user = snapshot.data;

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('UrbanEye', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                if (user != null) ...[
                  Text(
                    'Hello, ${user.email ?? 'user'}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  // Show authority badge if the user has the role
                  FutureBuilder<UserRole>(
                    future: const UserRoleService().getRole(user),
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
                ],
                const SizedBox(height: 60),

                if (user == null) ...[
                  ElevatedButton(
                    onPressed: () => _openLogin(context),
                    child: const Text('Sign in'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _openRegister(context),
                    child: const Text('Create account'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _openMain(context),
                    child: const Text('Sign in as guest'),
                  ),
                ] else ...[
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
                    onPressed: () => _auth.signOut(),
                    child: const Text('Sign out'),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
