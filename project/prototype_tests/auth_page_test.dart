import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:project/prototypes/auth_page.dart';
import 'package:project/services/auth_service.dart';

class MockAuthService extends Mock implements AuthService {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

class FakeAuthCredential extends Fake implements AuthCredential {}

void main() {
  late MockAuthService mockAuthService;
  late MockUserCredential mockUserCredential;
  late MockUser mockUser;

  setUpAll(() {
    registerFallbackValue(FakeAuthCredential());
  });

  setUp(() {
    mockAuthService = MockAuthService();
    mockUserCredential = MockUserCredential();
    mockUser = MockUser();

    when(() => mockAuthService.currentUser).thenReturn(null);
    when(() => mockUserCredential.user).thenReturn(mockUser);
    when(() => mockUser.email).thenReturn('test@email.com');
  });

  Widget buildPage() {
    return MaterialApp(home: AuthPage(authService: mockAuthService));
  }

  group('AuthPage', () {
    testWidgets('shows title, text fields, and action buttons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildPage());

      expect(find.text('Login / Register Prototype'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
    });

    testWidgets('logs in successfully and shows success message', (
      WidgetTester tester,
    ) async {
      when(
        () =>
            mockAuthService.signIn(email: 'test@email.com', password: '123456'),
      ).thenAnswer((_) async => mockUserCredential);

      await tester.pumpWidget(buildPage());

      await tester.enterText(find.byType(TextField).at(0), 'test@email.com');
      await tester.enterText(find.byType(TextField).at(1), '123456');
      await tester.tap(find.text('Login'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Login successful'), findsOneWidget);
    });

    testWidgets('registers successfully and shows success message', (
      WidgetTester tester,
    ) async {
      when(
        () => mockAuthService.register(
          email: 'test@email.com',
          password: '123456',
        ),
      ).thenAnswer((_) async => mockUserCredential);

      await tester.pumpWidget(buildPage());

      await tester.enterText(find.byType(TextField).at(0), 'test@email.com');
      await tester.enterText(find.byType(TextField).at(1), '123456');
      await tester.tap(find.text('Register'));
      await tester.pump();
      await tester.pump();

      expect(
        find.textContaining('Account created successfully'),
        findsOneWidget,
      );
    });

    testWidgets('shows error message when login throws exception', (
      WidgetTester tester,
    ) async {
      when(
        () => mockAuthService.signIn(
          email: 'error@email.com',
          password: '123456',
        ),
      ).thenThrow(
        FirebaseAuthException(
          code: 'user-not-found',
          message: 'User not found.',
        ),
      );

      await tester.pumpWidget(buildPage());

      await tester.enterText(find.byType(TextField).at(0), 'error@email.com');
      await tester.enterText(find.byType(TextField).at(1), '123456');
      await tester.tap(find.text('Login'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('User not found'), findsOneWidget);
    });

    testWidgets('logs out and shows logout message', (
      WidgetTester tester,
    ) async {
      when(() => mockAuthService.signOut()).thenAnswer((_) async {});

      await tester.pumpWidget(buildPage());

      await tester.tap(find.text('Logout'));
      await tester.pump();

      expect(find.text('Logged out.'), findsOneWidget);
      verify(() => mockAuthService.signOut()).called(1);
    });

    testWidgets('shows loading indicator while login is in progress', (
      WidgetTester tester,
    ) async {
      when(
        () =>
            mockAuthService.signIn(email: 'test@email.com', password: '123456'),
      ).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return mockUserCredential;
      });

      await tester.pumpWidget(buildPage());

      await tester.enterText(find.byType(TextField).at(0), 'test@email.com');
      await tester.enterText(find.byType(TextField).at(1), '123456');
      await tester.tap(find.text('Login'));

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Login successful'), findsOneWidget);
    });
  });
}
