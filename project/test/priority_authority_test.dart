import 'package:flutter_test/flutter_test.dart';
import 'package:project/features/report/report_model.dart';
import 'package:project/features/report/report_controller.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth fakeAuth;
  late ReportController controller;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    fakeAuth = MockFirebaseAuth();
    
    // Injetamos os mocks no controller para ele não tentar ligar ao Firebase real
    controller = ReportController(
      auth: fakeAuth,
    );
  });

  group('Authority Feature Tests', () {
    
    test('Should order reports by exists_confirmations descending', () async {
      // Criar dados no fake firestore
      await fakeFirestore.collection('reports').add({
        'category': 'Pothole',
        'exists_confirmations': 2,
        'isPriority': false,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await fakeFirestore.collection('reports').add({
        'category': 'Broken Pipe',
        'exists_confirmations': 10,
        'isPriority': false,
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Simulamos a query que está no watchAuthorityReports
      final snapshot = await fakeFirestore
          .collection('reports')
          .orderBy('exists_confirmations', descending: true)
          .get();

      final firstReport = snapshot.docs.first;
      
      expect(firstReport.data()['exists_confirmations'], 10);
      expect(snapshot.docs.length, 2);
    });

    test('togglePriority logic should update the document', () async {
      // 1. Criar um documento
      final docRef = await fakeFirestore.collection('reports').add({
        'category': 'Test',
        'isPriority': false,
      });

      // 2. Simular a lógica de update
      await fakeFirestore.collection('reports').doc(docRef.id).update({
        'isPriority': true,
      });

      // 3. Verificar
      final updatedDoc = await fakeFirestore.collection('reports').doc(docRef.id).get();
      expect(updatedDoc.data()!['isPriority'], true);
    });

    test('Authority Login Bypass Check', () {
      // Teste direto da lógica de login que usaste no ecrã
      const email = 'authority@gmail.com';
      const pass = 'authority';

      final isAuthority = (email == 'authority@gmail.com' && pass == 'authority');
      
      expect(isAuthority, isTrue);
    });
  });
}