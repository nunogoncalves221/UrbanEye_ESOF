import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project/features/main_screen.dart';
import 'package:project/services/auth_service.dart';
import 'package:project/features/authority/authority_screen.dart';
import 'package:provider/provider.dart';
import 'package:project/features/report/report_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = const AuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _message = '';
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _message = '';
    });
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    
    // --- Lógica de Authority ---
    if (email == 'authority@gmail.com' && password == 'authority') {
      Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => ReportController(), // Cria o controller aqui
        child:  AuthorityScreen(),
      ),
    ),
  );
   setState(() {
        _isLoading = false;
      });
  return;
}
    
    try {
      await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      setState(() {
        _message = 'Login successful';
      });

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MainScreen(auth: FirebaseAuth.instance),
            ),
          );
        }
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _message = e.message ?? 'Login failed';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration() {
    return const InputDecoration(border: OutlineInputBorder());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Email'),
            TextField(
              controller: _emailController,
              decoration: _inputDecoration(),
            ),

            const SizedBox(height: 12),

            const Text('Password'),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: _inputDecoration(),
            ),

            const SizedBox(height: 20),

            if (_isLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton(onPressed: _login, child: const Text('Login')),

            const SizedBox(height: 16),

            Text(_message, style: const TextStyle(color: Colors.green)),
          ],
        ),
      ),
    );
  }
}
