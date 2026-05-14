import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/features/report/report_model.dart';

void main() {
  group('ReportModel constructor', () {
    test('sets defaults for optional fields', () {
      final report = ReportModel(
        category: 'Pothole',
        description: 'Big hole in the road',
        latitude: 41.1,
        longitude: -8.6,
      );

      expect(report.id, isNull);
      expect(report.address, isNull);
      expect(report.photoUrl, isNull);
      expect(report.userId, isNull);
      expect(report.status, equals('pending'));
    });

    test('accepts all fields', () {
      final date = DateTime(2024, 6, 15);
      final report = ReportModel(
        id: 'abc123',
        category: 'Streetlight',
        description: 'Light is broken',
        latitude: 38.7,
        longitude: -9.1,
        address: 'Rua X, Lisboa',
        photoUrl: 'https://example.com/photo.jpg',
        userId: 'user1',
        status: 'resolved',
        createdAt: date,
      );

      expect(report.id, equals('abc123'));
      expect(report.category, equals('Streetlight'));
      expect(report.description, equals('Light is broken'));
      expect(report.latitude, equals(38.7));
      expect(report.longitude, equals(-9.1));
      expect(report.address, equals('Rua X, Lisboa'));
      expect(report.photoUrl, equals('https://example.com/photo.jpg'));
      expect(report.userId, equals('user1'));
      expect(report.status, equals('resolved'));
      expect(report.createdAt, equals(date));
    });

    test('uses DateTime.now() when createdAt is not provided', () {
      final before = DateTime.now();
      final report = ReportModel(
        category: 'Trash',
        description: 'Garbage',
        latitude: 0,
        longitude: 0,
      );
      final after = DateTime.now();

      expect(
        report.createdAt.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        report.createdAt.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });
  });

  group('ReportModel.toMap', () {
    test('converts all fields to map correctly', () {
      final date = DateTime(2024, 1, 10);
      final report = ReportModel(
        category: 'Pothole',
        description: 'Test description',
        latitude: 38.72,
        longitude: -9.14,
        address: 'Rua A',
        photoUrl: 'https://photo.url',
        userId: 'user123',
        status: 'in_progress',
        createdAt: date,
      );

      final map = report.toMap();

      expect(map['category'], equals('Pothole'));
      expect(map['description'], equals('Test description'));
      expect(map['latitude'], equals(38.72));
      expect(map['longitude'], equals(-9.14));
      expect(map['address'], equals('Rua A'));
      expect(map['photoUrl'], equals('https://photo.url'));
      expect(map['userId'], equals('user123'));
      expect(map['status'], equals('in_progress'));
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('does not include id field', () {
      final report = ReportModel(
        id: 'myid',
        category: 'Trash',
        description: 'Garbage',
        latitude: 0,
        longitude: 0,
      );

      final map = report.toMap();

      expect(map.containsKey('id'), isFalse);
    });

    test('toMap and fromMap roundtrip preserves data', () {
      final date = DateTime(2024, 3, 20, 14, 30);
      final original = ReportModel(
        id: 'r1',
        category: 'Vandalism',
        description: 'Graffiti',
        latitude: 40.0,
        longitude: -8.0,
        address: 'Rua B',
        userId: 'u1',
        status: 'pending',
        createdAt: date,
      );

      final map = original.toMap();
      final restored = ReportModel.fromMap('r1', map);

      expect(restored.id, equals('r1'));
      expect(restored.category, equals('Vandalism'));
      expect(restored.description, equals('Graffiti'));
      expect(restored.latitude, equals(40.0));
      expect(restored.longitude, equals(-8.0));
      expect(restored.address, equals('Rua B'));
      expect(restored.userId, equals('u1'));
      expect(restored.status, equals('pending'));
      expect(restored.createdAt.year, equals(2024));
      expect(restored.createdAt.month, equals(3));
      expect(restored.createdAt.day, equals(20));
    });
  });

  group('ReportModel.fromMap', () {
    test('parses map with Timestamp createdAt', () {
      final date = DateTime(2024, 3, 20);
      final map = {
        'category': 'Vandalism',
        'description': 'Graffiti on wall',
        'latitude': 40.0,
        'longitude': -8.0,
        'address': 'Rua B',
        'photoUrl': null,
        'userId': 'user2',
        'status': 'pending',
        'createdAt': Timestamp.fromDate(date),
      };

      final report = ReportModel.fromMap('id1', map);

      expect(report.id, equals('id1'));
      expect(report.category, equals('Vandalism'));
      expect(report.description, equals('Graffiti on wall'));
      expect(report.latitude, equals(40.0));
      expect(report.longitude, equals(-8.0));
      expect(report.address, equals('Rua B'));
      expect(report.userId, equals('user2'));
      expect(report.status, equals('pending'));
      expect(report.createdAt.year, equals(2024));
      expect(report.createdAt.month, equals(3));
      expect(report.createdAt.day, equals(20));
    });

    test('parses map with String createdAt', () {
      final map = {
        'category': 'Trash',
        'description': 'Litter on street',
        'latitude': 41.0,
        'longitude': -8.5,
        'status': 'resolved',
        'createdAt': '2024-05-15T10:30:00.000',
      };

      final report = ReportModel.fromMap('id2', map);

      expect(report.createdAt.year, equals(2024));
      expect(report.createdAt.month, equals(5));
      expect(report.createdAt.day, equals(15));
    });

    test('uses DateTime.now() when createdAt is null', () {
      final before = DateTime.now();
      final map = {
        'category': 'Pothole',
        'description': 'Hole',
        'latitude': 38.0,
        'longitude': -9.0,
        'status': 'pending',
        'createdAt': null,
      };

      final report = ReportModel.fromMap('id3', map);
      final after = DateTime.now();

      expect(
        report.createdAt.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        report.createdAt.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('uses defaults for missing fields', () {
      final map = <String, dynamic>{'createdAt': null};

      final report = ReportModel.fromMap('id4', map);

      expect(report.category, equals(''));
      expect(report.description, equals(''));
      expect(report.latitude, equals(0.0));
      expect(report.longitude, equals(0.0));
      expect(report.status, equals('pending'));
      expect(report.address, isNull);
      expect(report.photoUrl, isNull);
      expect(report.userId, isNull);
    });

    test('converts integer latitude/longitude to double', () {
      final map = {
        'category': 'Pothole',
        'description': 'Test',
        'latitude': 38,
        'longitude': -9,
        'status': 'pending',
        'createdAt': null,
      };

      final report = ReportModel.fromMap('id5', map);

      expect(report.latitude, isA<double>());
      expect(report.longitude, isA<double>());
      expect(report.latitude, equals(38.0));
      expect(report.longitude, equals(-9.0));
    });

    test('assigns the given id', () {
      final map = {
        'category': 'Pothole',
        'description': 'Test',
        'latitude': 0.0,
        'longitude': 0.0,
        'status': 'pending',
        'createdAt': null,
      };

      final report = ReportModel.fromMap('my-custom-id', map);

      expect(report.id, equals('my-custom-id'));
    });
  });
}
