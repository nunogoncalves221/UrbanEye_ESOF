import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project/services/points_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _seedUser(
  FakeFirebaseFirestore firestore,
  String userId, {
  int points = 0,
}) async {
  await firestore.collection('users').doc(userId).set({'points': points});
}

Future<String> _seedReport(
  FakeFirebaseFirestore firestore, {
  String userId = 'reporter-1',
  bool pointsAwarded = false,
}) async {
  final ref = firestore.collection('reports').doc();
  await ref.set({
    'userId': userId,
    'status': 'pending',
    'points_awarded': pointsAwarded,
  });
  return ref.id;
}

Future<int> _getPoints(FakeFirebaseFirestore firestore, String userId) async {
  final doc = await firestore.collection('users').doc(userId).get();
  return (doc.data()?['points'] as int?) ?? 0;
}

Future<List<Map<String, dynamic>>> _getHistory(
  FakeFirebaseFirestore firestore,
  String userId,
) async {
  final snap = await firestore
      .collection('points_history')
      .where('userId', isEqualTo: userId)
      .get();
  return snap.docs.map((d) => d.data()).toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late PointsService service;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    service = PointsService(firestore: fakeFirestore);
  });

  // ── onReportResolved ───────────────────────────────────────────────────────

  group('onReportResolved', () {
    test('PT-01 | reporter recebe +10 pontos quando report é resolvido',
        () async {
      await _seedUser(fakeFirestore, 'reporter-1', points: 5);
      final reportId = await _seedReport(fakeFirestore, userId: 'reporter-1');

      await service.onReportResolved(reportId, 'reporter-1');

      expect(await _getPoints(fakeFirestore, 'reporter-1'), equals(15));
    });

    test('PT-02 | cria entrada no histórico com motivo correto', () async {
      await _seedUser(fakeFirestore, 'reporter-1');
      final reportId = await _seedReport(fakeFirestore, userId: 'reporter-1');

      await service.onReportResolved(reportId, 'reporter-1');

      final history = await _getHistory(fakeFirestore, 'reporter-1');
      expect(history, hasLength(1));
      expect(history.first['amount'], equals(10));
      expect(history.first['reason'], equals('Report resolved'));
      expect(history.first['userId'], equals('reporter-1'));
    });

    test('PT-03 | não atribui pontos duas vezes ao mesmo report (idempotente)',
        () async {
      await _seedUser(fakeFirestore, 'reporter-1');
      final reportId = await _seedReport(fakeFirestore, userId: 'reporter-1');

      await service.onReportResolved(reportId, 'reporter-1');
      await service.onReportResolved(reportId, 'reporter-1');

      expect(await _getPoints(fakeFirestore, 'reporter-1'), equals(10));
      expect(
        await _getHistory(fakeFirestore, 'reporter-1'),
        hasLength(1),
      );
    });

    test('PT-04 | não faz nada se reporterId for null', () async {
      final reportId = await _seedReport(fakeFirestore);

      await expectLater(
        service.onReportResolved(reportId, null),
        completes,
      );
    });

    test('PT-05 | não faz nada se o report não existir no Firestore', () async {
      await _seedUser(fakeFirestore, 'reporter-1');

      await expectLater(
        service.onReportResolved('id-inexistente', 'reporter-1'),
        completes,
      );

      expect(await _getPoints(fakeFirestore, 'reporter-1'), equals(0));
    });
  });

  // ── onReportRejected ───────────────────────────────────────────────────────

  group('onReportRejected', () {
    test('PT-06 | reporter perde 5 pontos quando report é rejeitado', () async {
      await _seedUser(fakeFirestore, 'reporter-1', points: 20);

      await service.onReportRejected('reporter-1');

      expect(await _getPoints(fakeFirestore, 'reporter-1'), equals(15));
    });

    test('PT-07 | cria entrada no histórico com amount -5', () async {
      await _seedUser(fakeFirestore, 'reporter-1', points: 10);

      await service.onReportRejected('reporter-1');

      final history = await _getHistory(fakeFirestore, 'reporter-1');
      expect(history, hasLength(1));
      expect(history.first['amount'], equals(-5));
      expect(history.first['reason'], equals('Report rejected'));
    });

    test('PT-08 | pontos não ficam negativos (mínimo é 0)', () async {
      await _seedUser(fakeFirestore, 'reporter-1', points: 3);

      await service.onReportRejected('reporter-1');

      expect(await _getPoints(fakeFirestore, 'reporter-1'), equals(0));
    });

    test('PT-09 | user com 0 pontos fica com 0 pontos após rejeição', () async {
      await _seedUser(fakeFirestore, 'reporter-1', points: 0);

      await service.onReportRejected('reporter-1');

      expect(await _getPoints(fakeFirestore, 'reporter-1'), equals(0));
    });

    test('PT-10 | não faz nada se reporterId for null', () async {
      await expectLater(service.onReportRejected(null), completes);
    });

    test('PT-11 | não faz nada se reporterId for string vazia', () async {
      await expectLater(service.onReportRejected(''), completes);
    });
  });

  // ── onReportConfirmed ──────────────────────────────────────────────────────

  group('onReportConfirmed', () {
    test('PT-12 | confirmer recebe +1 ponto ao confirmar um report', () async {
      await _seedUser(fakeFirestore, 'confirmer-1');
      await _seedUser(fakeFirestore, 'reporter-1');

      await service.onReportConfirmed(
        confirmerId: 'confirmer-1',
        reporterId: 'reporter-1',
      );

      expect(await _getPoints(fakeFirestore, 'confirmer-1'), equals(1));
    });

    test('PT-13 | reporter recebe +2 pontos quando outro utilizador confirma',
        () async {
      await _seedUser(fakeFirestore, 'confirmer-1');
      await _seedUser(fakeFirestore, 'reporter-1');

      await service.onReportConfirmed(
        confirmerId: 'confirmer-1',
        reporterId: 'reporter-1',
      );

      expect(await _getPoints(fakeFirestore, 'reporter-1'), equals(2));
    });

    test('PT-14 | cria entradas no histórico para confirmer e reporter',
        () async {
      await _seedUser(fakeFirestore, 'confirmer-1');
      await _seedUser(fakeFirestore, 'reporter-1');

      await service.onReportConfirmed(
        confirmerId: 'confirmer-1',
        reporterId: 'reporter-1',
      );

      final confirmerHistory =
          await _getHistory(fakeFirestore, 'confirmer-1');
      expect(confirmerHistory, hasLength(1));
      expect(confirmerHistory.first['amount'], equals(1));
      expect(confirmerHistory.first['reason'], equals('Confirmed a report'));

      final reporterHistory = await _getHistory(fakeFirestore, 'reporter-1');
      expect(reporterHistory, hasLength(1));
      expect(reporterHistory.first['amount'], equals(2));
      expect(
        reporterHistory.first['reason'],
        equals('Report confirmed by citizen'),
      );
    });

    test(
        'PT-15 | confirmer recebe +1 mas reporter não recebe quando são o mesmo utilizador',
        () async {
      await _seedUser(fakeFirestore, 'user-1');

      await service.onReportConfirmed(
        confirmerId: 'user-1',
        reporterId: 'user-1',
      );

      expect(await _getPoints(fakeFirestore, 'user-1'), equals(1));
      final history = await _getHistory(fakeFirestore, 'user-1');
      expect(history, hasLength(1));
      expect(history.first['reason'], equals('Confirmed a report'));
    });

    test(
        'PT-16 | confirmer recebe +1 mesmo quando reporterId é null (report anónimo)',
        () async {
      await _seedUser(fakeFirestore, 'confirmer-1');

      await service.onReportConfirmed(
        confirmerId: 'confirmer-1',
        reporterId: null,
      );

      expect(await _getPoints(fakeFirestore, 'confirmer-1'), equals(1));
    });

    test(
        'PT-17 | reporter não recebe pontos quando reporterId é null (sem conta registada)',
        () async {
      await _seedUser(fakeFirestore, 'confirmer-1');

      await service.onReportConfirmed(
        confirmerId: 'confirmer-1',
        reporterId: null,
      );

      final snap = await fakeFirestore
          .collection('points_history')
          .where('reason', isEqualTo: 'Report confirmed by citizen')
          .get();
      expect(snap.docs, isEmpty);
    });

    test(
        'PT-18 | múltiplas confirmações acumulam pontos correctamente',
        () async {
      await _seedUser(fakeFirestore, 'reporter-1');
      await _seedUser(fakeFirestore, 'confirmer-1');
      await _seedUser(fakeFirestore, 'confirmer-2');

      await service.onReportConfirmed(
        confirmerId: 'confirmer-1',
        reporterId: 'reporter-1',
      );
      await service.onReportConfirmed(
        confirmerId: 'confirmer-2',
        reporterId: 'reporter-1',
      );

      expect(await _getPoints(fakeFirestore, 'reporter-1'), equals(4));
      expect(await _getPoints(fakeFirestore, 'confirmer-1'), equals(1));
      expect(await _getPoints(fakeFirestore, 'confirmer-2'), equals(1));
    });
  });
}
