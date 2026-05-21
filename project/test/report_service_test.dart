import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:project/features/report/report_model.dart';
import 'package:project/services/report_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Subclasse de ReportService que aceita dependências injectadas (Fake/Mock)
// para que os testes não precisem de Firebase real.
// ─────────────────────────────────────────────────────────────────────────────
class _TestableReportService extends ReportService {
  final FakeFirebaseFirestore fakeFirestore;
  final MockFirebaseStorage fakeStorage;

   _TestableReportService({
    required this.fakeFirestore,
    required this.fakeStorage,
  }) : super(firestore: fakeFirestore, storage: fakeStorage);

  @override
  FirebaseFirestore get _firestore => fakeFirestore;

  @override
  FirebaseStorage get _storage => fakeStorage;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: cria um report no Firestore falso e devolve o modelo
// ─────────────────────────────────────────────────────────────────────────────
Future<ReportModel> _seedReport(
  FakeFirebaseFirestore firestore, {
  String userId = 'user-owner',
  bool authorityConfirmed = false,
}) async {
  final ref = firestore.collection('reports').doc();
  final report = ReportModel(
    id: ref.id,
    category: 'Pothole',
    description: 'Large pothole on main street',
    latitude: 41.1496,
    longitude: -8.6109,
    address: 'Rua de Santa Catarina, Porto',
    userId: userId,
    status: 'pending',
    priority: 'low',
    authorityConfirmed: authorityConfirmed,
  );
  await ref.set(report.toMap());
  return report;
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseStorage fakeStorage;
  late _TestableReportService service;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    fakeStorage = MockFirebaseStorage();
    service = _TestableReportService(
      fakeFirestore: fakeFirestore,
      fakeStorage: fakeStorage,
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // GROUP 1 — confirmReportByAuthority
  // ───────────────────────────────────────────────────────────────────────────
  group('confirmReportByAuthority', () {
    test(
      'AC-01 | authority_confirmed fica true após confirmação',
      () async {
        final report = await _seedReport(fakeFirestore);

        await service.confirmReportByAuthority(report.id!);

        final doc = await fakeFirestore
            .collection('reports')
            .doc(report.id)
            .get();

        expect(doc.data()?['authority_confirmed'], isTrue);
      },
    );

    test(
      'AC-02 | outros campos do report não são alterados pela confirmação',
      () async {
        final report = await _seedReport(fakeFirestore);

        await service.confirmReportByAuthority(report.id!);

        final doc = await fakeFirestore
            .collection('reports')
            .doc(report.id)
            .get();
        final data = doc.data()!;

        expect(data['category'], equals('Pothole'));
        expect(data['status'], equals('pending'));
        expect(data['userId'], equals('user-owner'));
        expect(data['priority'], equals('low'));
      },
    );

    test(
      'AC-03 | confirmar um report já confirmado não lança excepção',
      () async {
        final report =
            await _seedReport(fakeFirestore, authorityConfirmed: true);

        // Não deve lançar — apenas re-escreve o mesmo valor
        await expectLater(
          service.confirmReportByAuthority(report.id!),
          completes,
        );

        final doc = await fakeFirestore
            .collection('reports')
            .doc(report.id)
            .get();
        expect(doc.data()?['authority_confirmed'], isTrue);
      },
    );

    test(
      'AC-04 | confirmação de report inexistente lança excepção',
      () async {
        await expectLater(
          service.confirmReportByAuthority('id-que-nao-existe'),
          throwsA(anything),
        );
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // GROUP 2 — deleteReport (Reject)
  // ───────────────────────────────────────────────────────────────────────────
  group('deleteReport (Reject Report)', () {
    test(
      'AC-05 | report é removido do Firestore após rejeição',
      () async {
        final report = await _seedReport(fakeFirestore);

        await service.deleteReport(report);

        final doc = await fakeFirestore
            .collection('reports')
            .doc(report.id)
            .get();
        expect(doc.exists, isFalse);
      },
    );

    test(
      'AC-06 | checkReportExists devolve false após deleteReport',
      () async {
        final report = await _seedReport(fakeFirestore);

        await service.deleteReport(report);

        final exists = await service.checkReportExists(report.id!);
        expect(exists, isFalse);
      },
    );

    test(
      'AC-07 | apagar um report não afecta outros reports',
      () async {
        final reportA = await _seedReport(fakeFirestore, userId: 'user-a');
        final reportB = await _seedReport(fakeFirestore, userId: 'user-b');

        await service.deleteReport(reportA);

        final existsB = await service.checkReportExists(reportB.id!);
        expect(existsB, isTrue);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // GROUP 3 — confirmProblem (users normais) bloqueado após authority confirmar
  // ───────────────────────────────────────────────────────────────────────────
  group('confirmProblem após authority confirmar', () {
    test(
      'AC-08 | user consegue confirmar antes de authority_confirmed = true',
      () async {
        final report = await _seedReport(fakeFirestore);

        await service.confirmProblem(report.id!, 'user-other', true);

        final doc = await fakeFirestore
            .collection('reports')
            .doc(report.id)
            .get();
        expect(doc.data()?['exists_confirmations'], equals(1));
      },
    );

    test(
      'AC-09 | authority_confirmed = true não impede confirmProblem no serviço '
      '(o bloqueio é feito na UI — este teste documenta o comportamento actual)',
      () async {
        // O serviço em si não verifica authority_confirmed;
        // a UI é responsável por esconder os botões.
        // Este teste garante que, se a UI falhar, o serviço ainda funciona.
        final report =
            await _seedReport(fakeFirestore, authorityConfirmed: true);

        await service.confirmProblem(report.id!, 'user-other', true);

        final doc = await fakeFirestore
            .collection('reports')
            .doc(report.id)
            .get();
        expect(doc.data()?['exists_confirmations'], equals(1));
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // GROUP 4 — hasUserConfirmed
  // ───────────────────────────────────────────────────────────────────────────
  group('hasUserConfirmed', () {
    test(
      'AC-10 | devolve false antes de qualquer confirmação',
      () async {
        final report = await _seedReport(fakeFirestore);

        final result =
            await service.hasUserConfirmed(report.id!, 'user-other');
        expect(result, isFalse);
      },
    );

    test(
      'AC-11 | devolve true após o user confirmar',
      () async {
        final report = await _seedReport(fakeFirestore);

        await service.confirmProblem(report.id!, 'user-other', true);

        final result =
            await service.hasUserConfirmed(report.id!, 'user-other');
        expect(result, isTrue);
      },
    );

    test(
      'AC-12 | user A confirmar não afecta o estado do user B',
      () async {
        final report = await _seedReport(fakeFirestore);

        await service.confirmProblem(report.id!, 'user-a', true);

        final resultB =
            await service.hasUserConfirmed(report.id!, 'user-b');
        expect(resultB, isFalse);
      },
    );

    test(
      'AC-13 | confirmProblem é idempotente — chamar duas vezes não duplica contagem',
      () async {
        final report = await _seedReport(fakeFirestore);

        await service.confirmProblem(report.id!, 'user-other', true);
        await service.confirmProblem(report.id!, 'user-other', true); // duplicado

        final doc = await fakeFirestore
            .collection('reports')
            .doc(report.id)
            .get();
        expect(doc.data()?['exists_confirmations'], equals(1));
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // GROUP 5 — auto-delete por votos negativos (lógica existente no serviço)
  // ───────────────────────────────────────────────────────────────────────────
  group('auto-delete por votos negativos', () {
    test(
      'AC-14 | report é apagado automaticamente quando not_exists supera threshold',
      () async {
        final report = await _seedReport(fakeFirestore);

        // Threshold: exists * 1.25 + 5 < not_exists
        // Com 0 exists → threshold = 5 → precisamos de 6 votos negativos
        for (var i = 0; i < 6; i++) {
          await service.confirmProblem(report.id!, 'user-$i', false);
        }

        final exists = await service.checkReportExists(report.id!);
        expect(exists, isFalse);
      },
    );

    test(
      'AC-15 | report não é apagado se votos negativos não atingem threshold',
      () async {
        final report = await _seedReport(fakeFirestore);

        // 5 votos negativos — ainda não chega ao threshold (precisa de 6)
        for (var i = 0; i < 5; i++) {
          await service.confirmProblem(report.id!, 'user-$i', false);
        }

        final exists = await service.checkReportExists(report.id!);
        expect(exists, isTrue);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // GROUP 6 — getUserFavouriteIds & toggleFavourite
  // ───────────────────────────────────────────────────────────────────────────
  group('getUserFavouriteIds & toggleFavourite', () {
    test(
      'FAV-01 | getUserFavouriteIds devolve set vazio quando user não tem favoritos',
      () async {
        final ids = await service.getUserFavouriteIds('user-123');
        expect(ids, isEmpty);
      },
    );

    test(
      'FAV-02 | getUserFavouriteIds devolve os IDs dos reports favoritos do user',
      () async {
        final report = await _seedReport(fakeFirestore);
        await fakeFirestore
            .collection('user_favourites')
            .doc('user-123_${report.id}')
            .set({'reportId': report.id, 'userId': 'user-123'});

        final ids = await service.getUserFavouriteIds('user-123');

        expect(ids, contains(report.id));
        expect(ids.length, equals(1));
      },
    );

    test(
      'FAV-03 | getUserFavouriteIds não devolve favoritos de outros utilizadores',
      () async {
        final report = await _seedReport(fakeFirestore);
        await fakeFirestore
            .collection('user_favourites')
            .doc('other-user_${report.id}')
            .set({'reportId': report.id, 'userId': 'other-user'});

        final ids = await service.getUserFavouriteIds('user-123');

        expect(ids, isEmpty);
      },
    );

    test(
      'FAV-04 | toggleFavourite cria documento quando report ainda não é favorito',
      () async {
        final report = await _seedReport(fakeFirestore);

        await service.toggleFavourite(report.id!, 'user-123');

        final doc = await fakeFirestore
            .collection('user_favourites')
            .doc('user-123_${report.id}')
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['reportId'], equals(report.id));
        expect(doc.data()?['userId'], equals('user-123'));
      },
    );

    test(
      'FAV-05 | toggleFavourite remove documento quando report já é favorito',
      () async {
        final report = await _seedReport(fakeFirestore);
        await fakeFirestore
            .collection('user_favourites')
            .doc('user-123_${report.id}')
            .set({'reportId': report.id, 'userId': 'user-123'});

        await service.toggleFavourite(report.id!, 'user-123');

        final doc = await fakeFirestore
            .collection('user_favourites')
            .doc('user-123_${report.id}')
            .get();
        expect(doc.exists, isFalse);
      },
    );

    test(
      'FAV-06 | toggleFavourite pode alternar entre favorito e não favorito',
      () async {
        final report = await _seedReport(fakeFirestore);
        final docPath = 'user-123_${report.id}';

        await service.toggleFavourite(report.id!, 'user-123');
        expect(
          (await fakeFirestore.collection('user_favourites').doc(docPath).get()).exists,
          isTrue,
          reason: 'após primeiro toggle deve estar marcado como favorito',
        );

        await service.toggleFavourite(report.id!, 'user-123');
        expect(
          (await fakeFirestore.collection('user_favourites').doc(docPath).get()).exists,
          isFalse,
          reason: 'após segundo toggle deve estar desmarcado',
        );
      },
    );

    test(
      'FAV-07 | toggleFavourite de um user não afecta favoritos de outro user',
      () async {
        final report = await _seedReport(fakeFirestore);

        await service.toggleFavourite(report.id!, 'user-a');
        await service.toggleFavourite(report.id!, 'user-b');

        final docA = await fakeFirestore
            .collection('user_favourites')
            .doc('user-a_${report.id}')
            .get();
        final docB = await fakeFirestore
            .collection('user_favourites')
            .doc('user-b_${report.id}')
            .get();
        expect(docA.exists, isTrue);
        expect(docB.exists, isTrue);
      },
    );
  });
}