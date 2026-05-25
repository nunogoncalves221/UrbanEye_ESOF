import 'package:cloud_firestore/cloud_firestore.dart';

class PointsService {
  static const int resolvedPoints = 10;
  static const int invalidPenalty = 5;

  final FirebaseFirestore _firestore;

  PointsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Awards +10 points to the reporter when a report is resolved
  Future<void> onReportResolved(String reportId, String? reporterId) async {
    if (reporterId == null || reporterId.isEmpty) return;

    final reportRef = _firestore.collection('reports').doc(reportId);
    final userRef = _firestore.collection('users').doc(reporterId);

    await _firestore.runTransaction((transaction) async {
      final reportSnap = await transaction.get(reportRef);
      if (!reportSnap.exists) return;

      final alreadyAwarded =
          (reportSnap.data()?['points_awarded'] as bool?) ?? false;
      if (alreadyAwarded) return;

      final userSnap = await transaction.get(userRef);
      final currentPoints = (userSnap.data()?['points'] as int?) ?? 0;

      transaction.update(reportRef, {'points_awarded': true});
      transaction.update(userRef, {'points': currentPoints + resolvedPoints});
    });
  }

  // Deducts 5 points from the reporter when their report is rejected and deleted
  Future<void> onReportRejected(String? reporterId) async {
    if (reporterId == null || reporterId.isEmpty) return;

    final userRef = _firestore.collection('users').doc(reporterId);

    await _firestore.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      if (!userSnap.exists) return;

      final currentPoints = (userSnap.data()?['points'] as int?) ?? 0;
      final newPoints = (currentPoints - invalidPenalty).clamp(0, 999999);

      transaction.update(userRef, {'points': newPoints});
    });
  }
}
