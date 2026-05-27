import 'package:cloud_firestore/cloud_firestore.dart';
import '../features/notifications/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore;

  NotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Creates notifications for the report owner and all users who favourited the report.
  Future<void> notifyReportChange({
    required String reportId,
    required String reportCategory,
    required String type,
    required String message,
    String? reportOwnerId,
  }) async {
    final usersToNotify = <String>{};

    if (reportOwnerId != null) {
      usersToNotify.add(reportOwnerId);
    }

    final favouritesSnapshot = await _firestore
        .collection('user_favourites')
        .where('reportId', isEqualTo: reportId)
        .get();

    for (final doc in favouritesSnapshot.docs) {
      final userId = doc.data()['userId'] as String?;
      if (userId != null) usersToNotify.add(userId);
    }

    if (usersToNotify.isEmpty) return;

    final batch = _firestore.batch();
    for (final userId in usersToNotify) {
      final docRef = _firestore.collection('notifications').doc();
      batch.set(docRef, NotificationModel(
        userId: userId,
        reportId: reportId,
        reportCategory: reportCategory,
        type: type,
        message: message,
      ).toMap());
    }
    await batch.commit();
  }

  Stream<List<NotificationModel>> watchNotificationsForUser(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => NotificationModel.fromMap(d.id, d.data()))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead(String userId) async {
    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    if (snapshot.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
