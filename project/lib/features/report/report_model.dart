import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String? id;
  final String category;
  final String description;
  final double latitude;
  final double longitude;
  final String? address;
  final String? priority;
  final String? photoUrl;
  final String? userId;
  final String status;
  final DateTime createdAt;
  final int existsConfirmations;
  final int notExistsConfirmations;

  ReportModel({
    this.id,
    required this.category,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.address,
    this.photoUrl,
    this.userId,
    this.priority,
    this.status = 'pending',
    DateTime? createdAt,
    this.existsConfirmations = 0,
    this.notExistsConfirmations = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'photoUrl': photoUrl,
      'userId': userId,
      'priority': priority,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'exists_confirmations': existsConfirmations,
      'not_exists_confirmations': notExistsConfirmations,
    };
  }

  factory ReportModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parsedDate;
    final raw = map['createdAt'];
    if (raw is Timestamp) {
      parsedDate = raw.toDate();
    } else if (raw is String) {
      parsedDate = DateTime.parse(raw);
    } else {
      parsedDate = DateTime.now();
    }

    return ReportModel(
      id: id,
      category: map['category'] ?? '',
      description: map['description'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      address: map['address'],
      photoUrl: map['photoUrl'],
      userId: map['userId'],
      priority: map['priority'],
      status: map['status'] ?? 'pending',
      createdAt: parsedDate,
      existsConfirmations: (map['exists_confirmations'] as int?) ?? 0,
      notExistsConfirmations: (map['not_exists_confirmations'] as int?) ?? 0,
    );
  }
}