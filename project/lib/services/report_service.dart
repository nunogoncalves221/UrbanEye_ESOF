import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../features/report/report_model.dart';

class ReportService {
  const ReportService();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  Future<String?> _uploadPhoto(File photo, String reportId) async {
    final ref = _storage.ref().child('reports/$reportId/photo.jpg');
    await ref.putFile(photo).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Upload timed out. Check your connection or Firebase Storage rules.'),
    );
    return await ref.getDownloadURL();
  }

  Future<void> submitReport(ReportModel report, {File? photo}) async {
    final docRef = _firestore.collection('reports').doc();

    String? photoUrl;
    if (photo != null) {
      photoUrl = await _uploadPhoto(photo, docRef.id);
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
  }

  /// Stream em tempo real dos reports do utilizador
  Stream<List<ReportModel>> watchReportsByUser(String userId) {
    return _firestore
        .collection('reports')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReportModel.fromMap(doc.id, doc.data()))
            .toList());
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
  Future<void> deleteReport(ReportModel report) async {
    if (report.photoUrl != null) {
      try {
        final ref = _storage.refFromURL(report.photoUrl!);
        await ref.delete();
      } catch (_) {}
    }
    await _firestore.collection('reports').doc(report.id).delete();
  }
}