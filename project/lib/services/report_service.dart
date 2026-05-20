import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../features/report/report_model.dart';

abstract class ReportServiceBase {
  const ReportServiceBase();
  Stream<List<ReportModel>> watchReportsByUser(String userId);
  Future<void> deleteReport(ReportModel report);
  Future<void> submitReport(ReportModel report, {File? photo});
  Future<bool> checkReportExists(String reportId);
  Future<void> confirmProblem(String reportId, String userId, bool confirmed);
  Future<bool> hasUserConfirmed(String reportId, String userId);
}

class ReportService extends ReportServiceBase {
  const ReportService();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  Future<String?> _uploadPhoto(File photo, String reportId) async {
    try {
      // check file exists
      if (!await photo.exists()) {
        throw Exception('Photo file does not exist');
      }

      final ref = _storage.ref().child('reports/$reportId/photo.jpg');

      // upload with detailed error logging
      final uploadTask = ref.putFile(photo);
      
      uploadTask.snapshotEvents.listen((taskSnapshot) {
        // log upload progress
        final progress = taskSnapshot.bytesTransferred / taskSnapshot.totalBytes;
        print('Photo upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });

      await uploadTask.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception(
          'Upload timed out. Check your connection or Firebase Storage rules.',
        ),
      );

      return await ref.getDownloadURL();
    } catch (e) {
      // log full error details
      print('Photo upload error: $e');
      print('Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      rethrow;
    }
  }

  @override
  Future<void> submitReport(ReportModel report, {File? photo}) async {
    try {
      final docRef = _firestore.collection('reports').doc();

      String? photoUrl;
      // check for photo
      if (photo != null) {
        print('Photo detected, uploading...');
        // photo taken
        photoUrl = await _uploadPhoto(photo, docRef.id);
        print('Photo uploaded successfully: $photoUrl');
      } else {
        // no photo taken
        print('No photo attached to report');
      }

      final finalReport = ReportModel(
        id: docRef.id,
        category: report.category,
        description: report.description,
        latitude: report.latitude,
        longitude: report.longitude,
        photoUrl: photoUrl,
        userId: report.userId,
        status: report.status,
        createdAt: report.createdAt,
      );

      await docRef.set(finalReport.toMap());
      print('Report saved to Firestore: ${docRef.id}');
    } catch (e) {
      print('Submit report error: $e');
      rethrow;
    }
  }

  /// Stream em tempo real dos reports do utilizador
  @override
  Stream<List<ReportModel>> watchReportsByUser(String userId) {
    return _firestore
        .collection('reports')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReportModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Fetch one-time dos reports do utilizador
  Future<List<ReportModel>> getReportsByUser(String userId) async {
    final snapshot = await _firestore
        .collection('reports')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ReportModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Apaga o report e a foto associada
  @override
  Future<void> deleteReport(ReportModel report) async {
    if (report.photoUrl != null) {
      try {
        final ref = _storage.refFromURL(report.photoUrl!);
        await ref.delete();
      } catch (_) {}
    }
    await _firestore.collection('reports').doc(report.id).delete();
  }

  // verify if a report exists in the database
  @override
  Future<bool> checkReportExists(String reportId) async {
    final doc = await _firestore.collection('reports').doc(reportId).get();
    return doc.exists;
  }

  // confirm whether a problem exists or not
  @override
  Future<void> confirmProblem(String reportId, String userId, bool confirmed) async {
    final confirmationDoc = _firestore.collection('problem_confirmations').doc('${reportId}_$userId');
    final doc = await confirmationDoc.get();
    if (doc.exists) return;

    await confirmationDoc.set({
      'reportId': reportId,
      'userId': userId,
      'confirmed': confirmed,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final reportRef = _firestore.collection('reports').doc(reportId);
    if (confirmed) {
      await reportRef.update({'exists_confirmations': FieldValue.increment(1)});
    } else {
      await reportRef.update({'not_exists_confirmations': FieldValue.increment(1)});

      final reportDoc = await reportRef.get();
      final data = reportDoc.data();
      if (data != null) {
        final existsCount = (data['exists_confirmations'] as int?) ?? 0;
        final notExistsCount = (data['not_exists_confirmations'] as int?) ?? 0;
        if (existsCount * 1.25 + 5 < notExistsCount) {
          final photoUrl = data['photoUrl'] as String?;
          if (photoUrl != null) {
            try {
              final ref = _storage.refFromURL(photoUrl);
              await ref.delete();
            } catch (_) {}
          }
          await reportRef.delete();
        }
      }
    }
  }

  // check if user has already confirmed a report
  @override
  Future<bool> hasUserConfirmed(String reportId, String userId) async {
    final doc = await _firestore
        .collection('problem_confirmations')
        .doc('${reportId}_$userId')
        .get();
    return doc.exists;
  }
}
