import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project/features/main_screen.dart';
import 'package:project/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  final AuthService? authService;
  final VoidCallback? onSuccess;
  const RegisterScreen({super.key, this.authService, this.onSuccess});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final AuthService _authService = widget.authService ?? const AuthService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _emailError = '';
  String _message = '';

  DateTime? _parseBirthDate(String value) {
    final parts = value.split('-');

    if (parts.length != 3) return null;

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) return null;

    final date = DateTime(year, month, day);

    if (date.day != day || date.month != month || date.year != year) {
      return null;
    }

    return date;
  }

  Future<void> _register() async {
    setState(() {
      _emailError = '';
      _message = '';
    });

    final birthDate = _parseBirthDate(_birthDateController.text.trim());

    if (birthDate == null) {
      setState(() {
        _message = 'Birth date must be in dd-mm-yyyy format';
      });
      return;
    }

    try {
      await _authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        birthDate: birthDate,
      );

      setState(() {
        _message = 'Account created successfully';
      });

      if (widget.onSuccess != null) {
        widget.onSuccess!();
      } else {
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
      }
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
    return const InputDecoration(border: OutlineInputBorder());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _birthDateController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Name'),
            TextField(
              controller: _nameController,
              decoration: _inputDecoration(),
            ),

            const SizedBox(height: 12),

            const Text('Username'),
            TextField(
              controller: _usernameController,
              decoration: _inputDecoration(),
            ),

            const SizedBox(height: 12),

            const Text('Birth date'),
            TextField(
              controller: _birthDateController,
              decoration: _inputDecoration().copyWith(
                hintText: 'dd-mm-yyyy',
              ),
            ),

            const SizedBox(height: 12),

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