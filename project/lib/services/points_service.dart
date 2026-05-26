import 'package:cloud_firestore/cloud_firestore.dart';

class PointsService {
  static const int resolvedPoints = 10;
  static const int invalidPenalty = 5;
  static const int confirmReporterBonus = 2;
  static const int confirmConfirmerBonus = 1;

  final FirebaseFirestore _firestore;

  PointsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Awards +10 points to the reporter when a report is resolved
  Future<void> onReportResolved(String reportId, String? reporterId) async {
    if (reporterId == null || reporterId.isEmpty) return;

    final reportRef = _firestore.collection('reports').doc(reportId);
    final userRef = _firestore.collection('users').doc(reporterId);
    final historyRef = _firestore.collection('points_history').doc();

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
      transaction.set(historyRef, {
        'userId': reporterId,
        'amount': resolvedPoints,
        'reason': 'Report resolved',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Awards +2 to the reporter and +1 to the confirmer when a citizen confirms a report
  Future<void> onReportConfirmed({
    required String confirmerId,
    required String? reporterId,
  }) async {
    if (reporterId == null || reporterId.isEmpty) return;

    final confirmerRef = _firestore.collection('users').doc(confirmerId);
    final reporterRef = _firestore.collection('users').doc(reporterId);
    final confirmerHistoryRef = _firestore.collection('points_history').doc();
    final reporterHistoryRef = _firestore.collection('points_history').doc();

    await _firestore.runTransaction((transaction) async {
      final confirmerSnap = await transaction.get(confirmerRef);
      final confirmerPoints = (confirmerSnap.data()?['points'] as int?) ?? 0;
      transaction.update(confirmerRef, {
        'points': confirmerPoints + confirmConfirmerBonus,
      });
      transaction.set(confirmerHistoryRef, {
        'userId': confirmerId,
        'amount': confirmConfirmerBonus,
        'reason': 'Confirmed a report',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (confirmerId != reporterId) {
        final reporterSnap = await transaction.get(reporterRef);
        final reporterPoints = (reporterSnap.data()?['points'] as int?) ?? 0;
        transaction.update(reporterRef, {
          'points': reporterPoints + confirmReporterBonus,
        });
        transaction.set(reporterHistoryRef, {
          'userId': reporterId,
          'amount': confirmReporterBonus,
          'reason': 'Report confirmed by citizen',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // Deducts 5 points from the reporter when their report is rejected and deleted
  Future<void> onReportRejected(String? reporterId) async {
    if (reporterId == null || reporterId.isEmpty) return;

    final userRef = _firestore.collection('users').doc(reporterId);
    final historyRef = _firestore.collection('points_history').doc();

    await _firestore.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      if (!userSnap.exists) return;

      final currentPoints = (userSnap.data()?['points'] as int?) ?? 0;
      final newPoints = (currentPoints - invalidPenalty).clamp(0, 999999);

      transaction.update(userRef, {'points': newPoints});
      transaction.set(historyRef, {
        'userId': reporterId,
        'amount': -invalidPenalty,
        'reason': 'Report rejected',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
