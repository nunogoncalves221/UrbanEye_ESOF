// Cloudinary Service Tests
//
// Tests for CloudinaryService signature generation and URL parsing
// No network calls - pure unit tests

import 'package:flutter_test/flutter_test.dart';
import 'package:project/services/cloudinary_service.dart';
import 'package:project/config/cloudinary_config.dart';

class TestableCloudinaryService extends CloudinaryService {
  String testGenerateSignature(Map<String, String> params) {
    return generateSignature(params);
  }

  String testGetTimestamp() {
    return getTimestamp();
  }
}

void main() {
  group('CloudinaryService Signature', () {
    late TestableCloudinaryService service;

    setUp(() {
      service = TestableCloudinaryService();
    });

    group('_generateSignature', () {
      test('same params produce same signature (deterministic)', () {
        final params = {
          'folder': 'reports/abc',
          'timestamp': '1234567890',
        };

        final sig1 = service.testGenerateSignature(params);
        final sig2 = service.testGenerateSignature(params);

        expect(sig1, equals(sig2));
      });

      test('different folder produces different signature', () {
        final params1 = {'folder': 'reports/abc', 'timestamp': '1234567890'};
        final params2 = {'folder': 'reports/xyz', 'timestamp': '1234567890'};

        final sig1 = service.testGenerateSignature(params1);
        final sig2 = service.testGenerateSignature(params2);

        expect(sig1, isNot(equals(sig2)));
      });

      test('different timestamp produces different signature', () {
        final params1 = {'folder': 'reports/abc', 'timestamp': '1234567890'};
        final params2 = {'folder': 'reports/abc', 'timestamp': '1234567891'};

        final sig1 = service.testGenerateSignature(params1);
        final sig2 = service.testGenerateSignature(params2);

        expect(sig1, isNot(equals(sig2)));
      });

      test('signature order is alphabetical (folder before timestamp)', () {
        final paramsAlphabetical = {
          'folder': 'reports/abc',
          'timestamp': '1234567890',
        };
        final paramsReversed = {
          'timestamp': '1234567890',
          'folder': 'reports/abc',
        };

        final sig1 = service.testGenerateSignature(paramsAlphabetical);
        final sig2 = service.testGenerateSignature(paramsReversed);

        expect(sig1, equals(sig2));
      });
    });

    group('extractPublicIdFromUrl', () {
      test('extracts public ID with version number', () {
        final url = 'https://res.cloudinary.com/dzvoc9wu3/image/upload/v1/reports/abc/photo.jpg';
        expect(CloudinaryService.extractPublicIdFromUrl(url), equals('reports/abc/photo.jpg'));
      });

      test('extracts public ID without version number', () {
        final url = 'https://res.cloudinary.com/dzvoc9wu3/image/upload/reports/xyz.png';
        expect(CloudinaryService.extractPublicIdFromUrl(url), equals('reports/xyz.png'));
      });

      test('extracts nested folder paths', () {
        final url = 'https://res.cloudinary.com/dzvoc9wu3/image/upload/v2/reports/test/abc/def.jpg';
        expect(CloudinaryService.extractPublicIdFromUrl(url), equals('reports/test/abc/def.jpg'));
      });

      test('returns empty string for non-cloudinary URL', () {
        expect(CloudinaryService.extractPublicIdFromUrl('https://example.com/image.jpg'), isEmpty);
      });

      test('strips query parameters', () {
        final url = 'https://res.cloudinary.com/dzvoc9wu3/image/upload/v1/reports/abc/photo.jpg?abc=123';
        expect(CloudinaryService.extractPublicIdFromUrl(url), equals('reports/abc/photo.jpg'));
      });
    });
  });
}