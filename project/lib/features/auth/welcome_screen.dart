import 'package:flutter/material.dart';
import 'package:project/features/auth/login_screen.dart';
import 'package:project/features/auth/register_screen.dart';
import 'package:project/prototypes/prototype_list_page.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _openLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _openRegister(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  void _openPrototypes(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrototypeListPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'UrbanEye',
              style: TextStyle(fontSize: 40),
            ),
            const SizedBox(height: 80),

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

            TextButton(
              onPressed: () => _openPrototypes(context),
              child: const Text('View prototypes'),
            ),
          ],
        ),
      ),
    );
  }
}