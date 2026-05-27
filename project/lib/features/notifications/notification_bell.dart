import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import 'notification_model.dart';
import 'notifications_screen.dart';

class NotificationBell extends StatelessWidget {
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;

  const NotificationBell({super.key, this.auth, this.firestore});

  FirebaseAuth get _auth => auth ?? FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        if (user == null) return const SizedBox.shrink();

        // NotificationService is only created when user is logged in,
        // so FirebaseFirestore.instance is never called in tests with null user.
        final service = NotificationService(firestore: firestore);
        return StreamBuilder<List<NotificationModel>>(
          stream: service.watchNotificationsForUser(user.uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('NotificationBell error: ${snapshot.error}');
            }
            final unreadCount = (snapshot.data ?? [])
                .where((n) => !n.isRead)
                .length;

            return IconButton(
              tooltip: 'Notifications',
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_outlined),
                  if (unreadCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
            );
          },
        );
      },
    );
  }
}
