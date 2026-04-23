import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthPage extends StatefulWidget {
  final AuthService authService;

  const AuthPage({super.key, AuthService? authService})
    : authService = authService ?? const AuthService();

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late final AuthService _authService;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _message = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService;
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      final userCredential = await _authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );

      setState(() {
        _message = 'Login successful: ${userCredential.user?.email ?? ''}';
      });
    } catch (e) {
      setState(() {
        _message = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      final userCredential = await _authService.register(
        email: _emailController.text,
        password: _passwordController.text,
      );

      setState(() {
        _message =
            'Account created successfully: ${userCredential.user?.email ?? ''}';
      });
    } catch (e) {
      setState(() {
        _message = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await _authService.signOut();

    setState(() {
      _message = 'Logged out.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Login / Register Prototype')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (user != null) Text('Current user: ${user.email ?? ''}'),

            const SizedBox(height: 16),

            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),

            const SizedBox(height: 16),

            if (_isLoading)
              const CircularProgressIndicator()
            else ...[
              ElevatedButton(onPressed: _login, child: const Text('Login')),
              ElevatedButton(
                onPressed: _register,
                child: const Text('Register'),
              ),
              ElevatedButton(onPressed: _logout, child: const Text('Logout')),
            ],

            const SizedBox(height: 16),

            Text(_message),
          ],
        ),
      ),
    );
  }
}
