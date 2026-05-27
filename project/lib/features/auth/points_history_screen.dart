import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PointsHistoryScreen extends StatelessWidget {
  final String userId;
  final FirebaseFirestore? firestore;
  final Stream<List<Map<String, dynamic>>>? entriesStream;

  const PointsHistoryScreen({
    super.key,
    required this.userId,
    this.firestore,
    this.entriesStream,
  });

  FirebaseFirestore get _firestore => firestore ?? FirebaseFirestore.instance;

  String _formatDate(dynamic createdAt) {
    DateTime? d;
    if (createdAt is Timestamp) {
      d = createdAt.toDate();
    } else if (createdAt is DateTime) {
      d = createdAt;
    }
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Stream<List<Map<String, dynamic>>> _buildStream() {
    return _firestore
        .collection('points_history')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final docs = snap.docs.map((d) => d.data()).toList()
            ..sort((a, b) {
              final aTime = a['createdAt'];
              final bTime = b['createdAt'];
              if (aTime is! Timestamp || bTime is! Timestamp) return 0;
              return bTime.compareTo(aTime);
            });
          return docs;
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Points History')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: entriesStream ?? _buildStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data!;

          if (entries.isEmpty) {
            return const Center(child: Text('No points history yet.'));
          }

          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = entries[index];
              final amount = (data['amount'] as int?) ?? 0;
              final reason = (data['reason'] as String?) ?? '';
              final createdAt = data['createdAt'];
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
