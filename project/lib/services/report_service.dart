// Report Service
//
// Handles all report-related database operations:
// - Submit/delete reports to/from Firestore
// - Upload/delete photos to/from Cloudinary
// - Track problem confirmations from users

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../features/report/report_model.dart';
import 'cloudinary_service.dart';

abstract class ReportServiceBase {
  Future<void> submitReport(ReportModel report, {File? photo});
  Stream<List<ReportModel>> watchReportsByUser(String userId);
  Future<void> deleteReport(ReportModel report);
  Future<bool> checkReportExists(String reportId);
  Future<void> confirmProblem(String reportId, String userId, bool confirmed);
  Future<bool> hasUserConfirmed(String reportId, String userId);
  Future<void> confirmReportByAuthority(String reportId);
}

class ReportService extends ReportServiceBase {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final CloudinaryService _cloudinary = const CloudinaryService();

  @override
  Future<void> submitReport(ReportModel report, {File? photo}) async {
    try {
      final docRef = _firestore.collection('reports').doc();

      String? photoUrl;
      // check for photo
      if (photo != null) {
        print('Photo detected, uploading...');
        // photo taken
        photoUrl = await _cloudinary.uploadPhoto(photo, docRef.id);
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

  @override
  Stream<List<ReportModel>> watchReportsByUser(String userId) {
    return _firestore
        .collection('reports')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (s) =>
              s.docs.map((d) => ReportModel.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<List<ReportModel>> getReportsByUser(String userId) async {
    final snapshot = await _firestore
        .collection('reports')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((d) => ReportModel.fromMap(d.id, d.data()))
        .toList();
  }

  @override
  Future<void> deleteReport(ReportModel report) async {
    if (report.photoUrl != null) {
      final publicId = CloudinaryService.extractPublicIdFromUrl(report.photoUrl!);
      if (publicId.isNotEmpty) {
        try {
          await _cloudinary.deletePhoto(publicId);
        } catch (_) {}
      }
    }
    await _firestore.collection('reports').doc(report.id).delete();
  }

  @override
  Future<bool> checkReportExists(String reportId) async {
    final doc = await _firestore.collection('reports').doc(reportId).get();
    return doc.exists;
  }

  @override
  Future<void> confirmProblem(
    String reportId,
    String userId,
    bool confirmed,
  ) async {
    final confirmationDoc = _firestore
        .collection('problem_confirmations')
        .doc('${reportId}_$userId');
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
      await reportRef.update({
        'not_exists_confirmations': FieldValue.increment(1),
      });
      final reportDoc = await reportRef.get();
      final data = reportDoc.data();
      if (data != null) {
        final existsCount = (data['exists_confirmations'] as int?) ?? 0;
        final notExistsCount = (data['not_exists_confirmations'] as int?) ?? 0;
        if (existsCount * 1.25 + 5 < notExistsCount) {
          final photoUrl = data['photoUrl'] as String?;
          if (photoUrl != null) {
            final publicId = CloudinaryService.extractPublicIdFromUrl(photoUrl);
            if (publicId.isNotEmpty) {
              try {
                await _cloudinary.deletePhoto(publicId);
              } catch (_) {}
            }
          }
          await reportRef.delete();
        }
      }
    }
  }

  @override
  Future<bool> hasUserConfirmed(String reportId, String userId) async {
    final doc = await _firestore
        .collection('problem_confirmations')
        .doc('${reportId}_$userId')
        .get();
    return doc.exists;
  }

  @override
  Future<void> confirmReportByAuthority(String reportId) async {
    await _firestore.collection('reports').doc(reportId).update({
      'authority_confirmed': true,
    });
  }

  Future<Set<String>> getUserFavouriteIds(String userId) async {
    final snapshot = await _firestore
        .collection('user_favourites')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs.map((d) => d.data()['reportId'] as String).toSet();
  }

  Future<void> toggleFavourite(String reportId, String userId) async {
    final docRef = _firestore
        .collection('user_favourites')
        .doc('${userId}_$reportId');
    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.delete();
    } else {
      await docRef.set({
        'reportId': reportId,
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
