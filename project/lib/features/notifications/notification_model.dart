import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String? id;
  final String userId;
  final String reportId;
  final String reportCategory;
  final String type; // 'status_change', 'priority_change', 'authority_confirmed', 'authority_rejected'
  final String message;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    this.id,
    required this.userId,
    required this.reportId,
    required this.reportCategory,
    required this.type,
    required this.message,
    this.isRead = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'reportId': reportId,
      'reportCategory': reportCategory,
      'type': type,
      'message': message,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parsedDate;
    final raw = map['createdAt'];
    if (raw is Timestamp) {
      parsedDate = raw.toDate();
    } else {
      parsedDate = DateTime.now();
    }

    return NotificationModel(
      id: id,
      userId: map['userId'] ?? '',
      reportId: map['reportId'] ?? '',
      reportCategory: map['reportCategory'] ?? '',
      type: map['type'] ?? '',
      message: map['message'] ?? '',
      isRead: (map['isRead'] as bool?) ?? false,
      createdAt: parsedDate,
    );
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      userId: userId,
      reportId: reportId,
      reportCategory: reportCategory,
      type: type,
      message: message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
