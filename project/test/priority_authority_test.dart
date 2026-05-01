import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:project/features/report/report_controller.dart';
import 'package:project/services/user_role_service.dart';
import 'package:project/services/user_role.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import necessário para o Fake
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

// 1. Criamos um Fake para o User para que o Mocktail o reconheça
class FakeUser extends Fake implements User {}

// Criamos um Mock para o serviço de Roles
class MockUserRoleService extends Mock implements UserRoleService {}

void main() {
  // 2. Registamos o fallback value antes de qualquer teste
  setUpAll(() {
    registerFallbackValue(FakeUser());
  });

  late ReportController controller;
  late MockUserRoleService mockRoleService;
  late MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    mockRoleService = MockUserRoleService();
    fakeFirestore = FakeFirebaseFirestore();
    
    final user = MockUser(uid: 'auth_user_123', email: 'authority@test.com');
    mockAuth = MockFirebaseAuth(signedIn: true, mockUser: user);

    controller = ReportController(
      auth: mockAuth,
      roleService: mockRoleService,
      firestore: fakeFirestore,
    );
  });

  group('Authority Feature Tests (Custom Claims)', () {
    
    test('Deve permitir ver reports se o Role for Authority', () async {
      // O 'any()' agora já vai funcionar porque registámos o FakeUser acima
      when(() => mockRoleService.getRole(any())).thenAnswer((_) async => UserRole.authority);

      await controller.syncUserRole();

      expect(controller.userRole, UserRole.authority);
      
      await fakeFirestore.collection('reports').add({
        'category': 'Pothole',
        'exists_confirmations': 10,
      });
      
      final reports = await controller.watchAuthorityReports().first;
      expect(reports.length, 1);
    });

    test('Deve bloquear reports e prioridade se o Role for Citizen', () async {
      when(() => mockRoleService.getRole(any())).thenAnswer((_) async => UserRole.citizen);

      await controller.syncUserRole();

      expect(controller.userRole, UserRole.citizen);
      
      await fakeFirestore.collection('reports').add({'category': 'Pothole'});
      
      final reports = await controller.watchAuthorityReports().first;
      expect(reports, isEmpty);

      await controller.togglePriority('doc_123', false);
      expect(controller.errorMessage, contains('Unauthorized'));
    });

    test('togglePriority deve atualizar Firestore se for Authority', () async {
      when(() => mockRoleService.getRole(any())).thenAnswer((_) async => UserRole.authority);
      await controller.syncUserRole();

      final doc = await fakeFirestore.collection('reports').add({
        'isPriority': false,
      });

      await controller.togglePriority(doc.id, false);

      final updatedDoc = await fakeFirestore.collection('reports').doc(doc.id).get();
      expect(updatedDoc.data()!['isPriority'], true);
    });
  });
}