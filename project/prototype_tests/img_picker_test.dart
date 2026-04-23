import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:project/prototypes/img_picker.dart';

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
    return MaterialApp(home: ImagePickerPage(picker: mockPicker));
  }

  group('ImagePickerPage', () {
    testWidgets('shows initial UI elements', (WidgetTester tester) async {
      await tester.pumpWidget(buildPage());

      expect(find.text('Image Picker Prototype'), findsOneWidget);
      expect(
        find.text('Clica no botão para escolher uma imagem'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.image), findsOneWidget);
      expect(find.text('Escolher da Galeria'), findsOneWidget);
    });

    testWidgets('successfully picks an image and displays it', (
      WidgetTester tester,
    ) async {
      final fakeFile = XFile('/fake/path/image.png');

      when(
        () => mockPicker.pickImage(source: ImageSource.gallery),
      ).thenAnswer((_) async => fakeFile);

      await tester.pumpWidget(buildPage());

      await tester.tap(find.text('Escolher da Galeria'));
      await tester.pump();

      expect(find.text('Imagem carregada com sucesso'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('shows message when user cancels image picking', (
      WidgetTester tester,
    ) async {
      when(
        () => mockPicker.pickImage(source: ImageSource.gallery),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(buildPage());

      await tester.tap(find.text('Escolher da Galeria'));
      await tester.pump();

      expect(find.text('Nenhuma imagem selecionada'), findsOneWidget);
    });

    testWidgets('shows error message when picker throws exception', (
      WidgetTester tester,
    ) async {
      when(
        () => mockPicker.pickImage(source: ImageSource.gallery),
      ).thenThrow(Exception('Falha ao abrir galeria'));

      await tester.pumpWidget(buildPage());

      await tester.tap(find.text('Escolher da Galeria'));
      await tester.pump();

      expect(find.textContaining('Ocorreu um erro'), findsOneWidget);
    });
  });
}
