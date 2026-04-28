import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project/features/auth/edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  final FirebaseAuth? auth;

  const ProfileScreen({super.key, this.auth});

  FirebaseAuth get _auth => auth ?? FirebaseAuth.instance;

  String _formatDate(Timestamp ts) {
    final d = ts.toDate();
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data()!;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'Hello, ${data['name']}',
                  style: const TextStyle(fontSize: 20),
                ),

                const SizedBox(height: 24),

                ListTile(
                  title: const Text('Username'),
                  subtitle: Text(data['username']),
                ),

                ListTile(
                  title: const Text('Birth date'),
                  subtitle: Text(_formatDate(data['birthDate'])),
                ),

                ListTile(
                  title: const Text('Email'),
                  subtitle: Text(data['email']),
                ),

                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditProfileScreen(auth: _auth),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit profile'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}