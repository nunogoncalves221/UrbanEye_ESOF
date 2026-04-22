import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project/prototypes/problems_list.dart';

void main() {
  testWidgets('ProblemsList displays all problems', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProblemsList(),
      ),
    );

    // Verifica se o título aparece
    expect(find.text('Lista de Problemas'), findsOneWidget);

    // Verifica se os problemas aparecem na lista
    expect(find.text('Rua Augusta'), findsOneWidget);
    expect(find.text('Avenida da Liberdade'), findsOneWidget);
    expect(find.text('Praça do Comércio'), findsOneWidget);
    expect(find.text('Rua do Alecrim'), findsOneWidget);

    // Verifica se existem icons de warning
    expect(find.byIcon(Icons.warning), findsNWidgets(4));
  });

  testWidgets('Tapping a problem shows SnackBar', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProblemsList(),
      ),
    );

    // Clica no primeiro item
    await tester.tap(find.text('Rua Augusta'));
    await tester.pump(); // inicia animação do SnackBar
    await tester.pump(const Duration(seconds: 1)); // deixa o SnackBar aparecer

    // Verifica SnackBar
    expect(find.text('Selecionaste Rua Augusta'), findsOneWidget);
  });
}