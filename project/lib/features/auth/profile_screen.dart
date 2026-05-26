import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project/features/auth/edit_profile_screen.dart';
import 'package:project/services/user_role.dart';
import 'package:project/services/user_role_service.dart';
import 'package:project/features/report/my_reports_screen.dart';

class ProfileScreen extends StatelessWidget {
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;

  const ProfileScreen({super.key, this.auth, this.firestore});

  FirebaseAuth get _auth => auth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => firestore ?? FirebaseFirestore.instance;

  String _formatDate(Timestamp ts) {
    final d = ts.toDate();
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data()!;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Hello, ${data['name']}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20),
                  ),

                  const SizedBox(height: 8),

                  // 🔵 Authority badge
                  FutureBuilder<UserRole>(
                    future: const UserRoleService().getRole(user),
                    builder: (context, snapshot) {
                      if (snapshot.data == UserRole.authority) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Autoridade',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      }

                      return const SizedBox.shrink();
                    },
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

                  ListTile(
                    leading: const Icon(Icons.emoji_events, color: Colors.amber),
                    title: const Text('Points'),
                    subtitle: Text('${(data['points'] as int?) ?? 0} pts'),
                  ),

                  const SizedBox(height: 12),

                  ListTile(
                    leading: const Icon(Icons.assignment_outlined),
                    title: const Text('My Reports'),
                    subtitle: const Text('View and manage your submissions'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MyReportsScreen(auth: _auth),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfileScreen(
                            auth: _auth,
                            firestore: _firestore,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit profile'),
                  ),

                  const SizedBox(height: 16),

                  OutlinedButton(
                    onPressed: () async {
                      await _auth.signOut();

                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
