import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PointsHistoryScreen extends StatelessWidget {
  final String userId;
  final FirebaseFirestore? firestore;

  const PointsHistoryScreen({super.key, required this.userId, this.firestore});

  FirebaseFirestore get _firestore => firestore ?? FirebaseFirestore.instance;

  String _formatDate(Timestamp ts) {
    final d = ts.toDate();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Points History')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('points_history')
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data!.docs
            ..sort((a, b) {
              final aTime = a.data()['createdAt'] as Timestamp?;
              final bTime = b.data()['createdAt'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });

          if (entries.isEmpty) {
            return const Center(child: Text('No points history yet.'));
          }

          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = entries[index].data();
              final amount = (data['amount'] as int?) ?? 0;
              final reason = (data['reason'] as String?) ?? '';
              final createdAt = data['createdAt'] as Timestamp?;
              final isPositive = amount >= 0;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isPositive
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  child: Text(
                    isPositive ? '+$amount' : '$amount',
                    style: TextStyle(
                      color: isPositive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                title: Text(reason),
                trailing: createdAt != null
                    ? Text(
                        _formatDate(createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
