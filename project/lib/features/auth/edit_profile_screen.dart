import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditProfileScreen extends StatefulWidget {
  final FirebaseAuth? auth;

  const EditProfileScreen({super.key, this.auth});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _birthDateController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  FirebaseAuth get _auth => widget.auth ?? FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _formatDate(Timestamp ts) {
    final d = ts.toDate();
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  DateTime _parse(String s) {
    final p = s.split('-');
    return DateTime(
      int.parse(p[2]),
      int.parse(p[1]),
      int.parse(p[0]),
    );
  }

  Future<void> _load() async {
    final user = _auth.currentUser!;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data()!;

    _nameController.text = data['name'];
    _usernameController.text = data['username'];
    _birthDateController.text = _formatDate(data['birthDate']);

    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final user = _auth.currentUser!;

    setState(() => _saving = true);

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'name': _nameController.text,
      'username': _usernameController.text,
      'birthDate': Timestamp.fromDate(_parse(_birthDateController.text)),
    });

    await user.updateDisplayName(_nameController.text);

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),

            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),

            TextField(
              controller: _birthDateController,
              decoration: const InputDecoration(
                labelText: 'Birth date (dd-mm-yyyy)',
              ),
            ),

            const SizedBox(height: 20),

            if (_saving)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
          ],
        ),
      ),
    );
  }
}