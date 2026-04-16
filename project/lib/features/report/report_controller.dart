import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'report_model.dart';
import 'report_service.dart';

class ReportController extends ChangeNotifier {
  final ReportService _service;

  ReportController({ReportService? service})
      : _service = service ?? const ReportService();

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
      errorMessage = 'Location permission permanently denied. Please enable it in settings.';
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

  Future<void> pickPhoto() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
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
      final userId = FirebaseAuth.instance.currentUser?.uid;

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