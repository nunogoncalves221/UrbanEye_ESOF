import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'report_model.dart';
import '../../services/report_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportController extends ChangeNotifier {
  final ReportServiceBase _service;
  final FirebaseAuth _auth;

  ReportController({ReportServiceBase? service, FirebaseAuth? auth})
    : _service = service ?? const ReportService(),
      _auth = auth ?? FirebaseAuth.instance;

  // Form state
  String? selectedCategory;
  String description = '';
  File? photo;
  double? latitude;
  double? longitude;

  // UI state
  bool isLoading = false;
  String? errorMessage;
  bool submitted = false;

  final ImagePicker _picker = ImagePicker();

  // ─── Location ───────────────────────────────────────────────

  Future<void> fetchLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      errorMessage = 'Location services are disabled.';
      notifyListeners();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        errorMessage = 'Location permission denied.';
        notifyListeners();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      errorMessage =
          'Location permission permanently denied. Please enable it in settings.';
      await Geolocator.openAppSettings();
      notifyListeners();
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    latitude = position.latitude;
    longitude = position.longitude;
    errorMessage = null;
    notifyListeners();
  }

  // ─── Photo ──────────────────────────────────────────────────

  Future<void> pickPhoto(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(source: source);
      if (picked != null) {
        photo = File(picked.path);
        notifyListeners();
      }
    } catch (e) {
      errorMessage = 'Error picking image: $e';
      notifyListeners();
    }
  }

  // ─── Validation ─────────────────────────────────────────────

  String? validate() {
    if (selectedCategory == null || selectedCategory!.isEmpty) {
      return 'Please select a category.';
    }
    if (description.trim().isEmpty) {
      return 'Please enter a description.';
    }
    if (latitude == null || longitude == null) {
      return 'Please fetch your location before submitting.';
    }
    return null;
  }

  // ─── Submit ─────────────────────────────────────────────────

  Future<bool> submitReport() async {
    final validationError = validate();
    if (validationError != null) {
      errorMessage = validationError;
      notifyListeners();
      return false;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final userId = _auth.currentUser?.uid;

      final report = ReportModel(
        category: selectedCategory!,
        description: description.trim(),
        latitude: latitude!,
        longitude: longitude!,
        userId: userId,
      );

      await _service.submitReport(report, photo: photo);

      submitted = true;
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to submit report. Please try again.';
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Authority Methods (Limpas e sem duplicação) ────────────

  /// Stream que retorna os reports ordenados por confirmações.
  Stream<List<ReportModel>> watchAuthorityReports() {
    return FirebaseFirestore.instance
        .collection('reports')
        .orderBy('exists_confirmations', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReportModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Alterna o estado de prioridade de um report.
  Future<void> togglePriority(String reportId, bool currentPriority) async {
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .update({'isPriority': !currentPriority});
      notifyListeners();
    } catch (e) {
      errorMessage = 'Failed to update priority: $e';
      notifyListeners();
    }
  }

  // ─── Reset ──────────────────────────────────────────────────

  void reset() {
    selectedCategory = null;
    description = '';
    photo = null;
    latitude = null;
    longitude = null;
    isLoading = false;
    errorMessage = null;
    submitted = false;
    notifyListeners();
  }
}
