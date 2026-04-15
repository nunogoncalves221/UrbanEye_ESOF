import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = const AuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _emailError = '';
  String _message = '';

  Future<void> _register() async {
    setState(() {
      _emailError = '';
      _message = '';
    });

    try {
      await _authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      setState(() {
        _message = 'Account created successfully';
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        setState(() {
          _emailError = 'Try again, email already registered';
        });
      } else {
        setState(() {
          _message = e.message ?? 'Register failed';
        });
      }
    }
  }

  InputDecoration _inputDecoration() {
    return const InputDecoration(
      border: OutlineInputBorder(),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Email'),
            TextField(
              controller: _emailController,
              decoration: _inputDecoration(),
            ),

            if (_emailError.isNotEmpty)
              Text(
                _emailError,
                style: const TextStyle(color: Colors.red),
              ),

            const SizedBox(height: 12),

            const Text('Password'),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: _inputDecoration(),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _register,
              child: const Text('Register'),
            ),

            const SizedBox(height: 16),

            Text(
              _message,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}