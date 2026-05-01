import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:project/features/report/location_picker_screen.dart';

void main() {
  group('LocationPickerScreen - Prioridade de Localização', () {
    
    testWidgets('Deve iniciar no Porto por padrão (Fallback)', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LocationPickerScreen()));
      await tester.pumpAndSettle();

      final state = tester.state<LocationPickerScreenState>(find.byType(LocationPickerScreen));
      
      expect(state.mapCenter.latitude, closeTo(41.1496, 0.0001));
    });

    testWidgets('Deve atualizar o centro quando o GPS é detetado', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LocationPickerScreen()));

      final state = tester.state<LocationPickerScreenState>(find.byType(LocationPickerScreen));

      // Simulamos a receção do GPS dentro de um setState para o widget atualizar
      const lisboa = LatLng(38.7223, -9.1393);
      
      // ignore: invalid_use_of_protected_member
      state.setState(() {
        state.currentLocation = lisboa;
      });
      
      await tester.pump(); // Reconstrói o widget

      expect(state.mapCenter, lisboa);
    });

    testWidgets('Seleção manual deve ter prioridade máxima', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LocationPickerScreen()));
      final state = tester.state<LocationPickerScreenState>(find.byType(LocationPickerScreen));

      const lisboa = LatLng(38.7223, -9.1393);
      const coimbra = LatLng(40.2033, -8.4103);

      // ignore: invalid_use_of_protected_member
      state.setState(() {
        state.currentLocation = lisboa;
        state.selectedPoint = coimbra;
      });

      await tester.pump();

      expect(state.mapCenter, coimbra);
    });
  });
}