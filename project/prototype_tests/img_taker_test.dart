import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:project/prototypes/img_taker.dart';

class MockImagePicker extends Mock implements ImagePicker {}

class FakeXFile extends Fake implements XFile {}

void main() {
  late MockImagePicker mockPicker;

  setUpAll(() {
    registerFallbackValue(FakeXFile());
  });

  setUp(() {
    mockPicker = MockImagePicker();
  });

  Widget buildPage() {
    return MaterialApp(home: ImgTakerPage(picker: mockPicker));
  }

  group('ImgTakerPage', () {
    testWidgets('shows initial UI elements', (WidgetTester tester) async {
      await tester.pumpWidget(buildPage());

      expect(find.text('Camera Prototype'), findsOneWidget);
      expect(find.text('Clica no botão para tirar uma foto'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(find.text('Tirar Foto'), findsOneWidget);
    });

    testWidgets('successfully takes a photo and displays it', (
      WidgetTester tester,
    ) async {
      final fakeFile = XFile('/fake/path/photo.png');

      when(
        () => mockPicker.pickImage(source: ImageSource.camera),
      ).thenAnswer((_) async => fakeFile);

      await tester.pumpWidget(buildPage());

      await tester.tap(find.text('Tirar Foto'));
      await tester.pump();

      expect(find.text('Foto tirada com sucesso!'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('shows message when user cancels photo taking', (
      WidgetTester tester,
    ) async {
      when(
        () => mockPicker.pickImage(source: ImageSource.camera),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(buildPage());

      await tester.tap(find.text('Tirar Foto'));
      await tester.pump();

      expect(find.text('Nenhuma foto tirada'), findsOneWidget);
    });

    testWidgets('shows error message when camera throws exception', (
      WidgetTester tester,
    ) async {
      when(
        () => mockPicker.pickImage(source: ImageSource.camera),
      ).thenThrow(Exception('Camera error'));

      await tester.pumpWidget(buildPage());

      await tester.tap(find.text('Tirar Foto'));
      await tester.pump();

      expect(find.textContaining('Ocorreu um erro'), findsOneWidget);
    });
  });
}
