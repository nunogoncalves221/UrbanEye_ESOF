import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'report_model.dart';

class ReportService {
  const ReportService();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  /// Uploads a photo to Firebase Storage and returns its download URL.
  Future<String?> _uploadPhoto(File photo, String reportId) async {
    final ref = _storage.ref().child('reports/$reportId/photo.jpg');
    await ref.putFile(photo);
    return await ref.getDownloadURL();
  }

  /// Saves a report to Firestore, uploading the photo first if provided.
  Future<void> submitReport(ReportModel report, {File? photo}) async {
    // Create the document first to get an ID
    final docRef = _firestore.collection('reports').doc();

    String? photoUrl;
    if (photo != null) {
      photoUrl = await _uploadPhoto(photo, docRef.id);
    }

    // Build final report with photo URL and document ID
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

  /// Fetches all reports for a given user.
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
}