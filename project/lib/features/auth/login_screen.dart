import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../features/report/report_controller.dart';
import '../../services/user_role.dart';
import '../../features/main_screen.dart'; 
import '../authority/authority_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Por favor, preencha todos os campos.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Autenticação no Firebase
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Aceder ao ReportController via Provider
      if (!mounted) return;
      final reportController = Provider.of<ReportController>(context, listen: false);

      // 3. Sincronizar o Role (Claims do Firebase)
      await reportController.syncUserRole();

      // 4. Decisão de Navegação baseada no Role detetado
      if (!mounted) return;
      if (reportController.userRole == UserRole.authority) {
        // Se for autoridade, vai para o painel de gestão
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) =>  AuthorityScreen()),);
      } else {
        // Se for cidadão comum, vai para a lista/mapa geral
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MainScreen(auth: FirebaseAuth.instance)),);
      }

    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Erro ao fazer login.$e';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ocorreu um erro inesperado. $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _handleLogin,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Entrar'),
                  ),
          ],
        ),
      ),
    );
  }
}
