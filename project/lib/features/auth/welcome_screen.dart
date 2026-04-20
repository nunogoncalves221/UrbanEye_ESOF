import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project/features/auth/login_screen.dart';
import 'package:project/features/auth/register_screen.dart';
import 'package:project/prototypes/prototype_list_page.dart';
import 'package:project/features/report/report_screen.dart';
import 'package:project/features/report/my_reports_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _openLogin(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // This creates a simple Fade transition
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        // Optional: Adjust the speed of the fade (300-500ms is usually best)
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _openRegister(BuildContext context) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const RegisterScreen()));
  }

  void _openReport(BuildContext context) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ReportScreen()));
  }

  void _openMyReports(BuildContext context) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const MyReportsScreen()));
  }

  void _openPrototypes(BuildContext context) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const PrototypeListPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          final user = snapshot.data;

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('UrbanEye', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                if (user != null)
                  Text('Hello, ${user.email ?? 'user'}',
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade600)),
                const SizedBox(height: 60),

                if (user == null) ...[
                  ElevatedButton(
                      onPressed: () => _openLogin(context),
                      child: const Text('Sign in')),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: () => _openRegister(context),
                      child: const Text('Create account')),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: () => _openReport(context),
                      child: const Text('Report a problem')),
                ] else ...[
                  FilledButton.icon(
                      onPressed: () => _openMyReports(context),
                      icon: const Icon(Icons.list_alt),
                      label: const Text('My Reports')),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                      onPressed: () => _openReport(context),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Report a problem')),
                  const SizedBox(height: 16),
                  OutlinedButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: const Text('Sign out')),
                  const SizedBox(height: 16),
                ],

                /*TextButton(
                    onPressed: () => _openPrototypes(context),
                    child: const Text('View prototypes')), */
              ],
            ),
          );
        },
      ),
    );
  }
}