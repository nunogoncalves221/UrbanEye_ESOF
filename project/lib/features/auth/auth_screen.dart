import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project/features/auth/login_screen.dart';
import 'package:project/features/auth/register_screen.dart';
import 'package:project/features/main_screen.dart';
import 'package:project/services/report_service.dart';

class AuthScreen extends StatelessWidget {
  final FirebaseAuth? auth;
  final ReportServiceBase service;

  AuthScreen({
    super.key,
    this.auth,
    ReportServiceBase? service, // Transforma em opcional nulo
  }) : service = service ?? ReportService();

  FirebaseAuth get _auth => auth ?? FirebaseAuth.instance;

  // navigate to LoginScreen
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

  // navigate to RegisterScreen
  void _openRegister(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  // navigate to MainScreen (guest access)
  void _openMain(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MainScreen(
          auth: _auth,
          reportService: service, // Envia o fake service recebido no teste!
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('UrbanEye', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 60),
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
          ],
        ),
      ),
    );
  }
}
