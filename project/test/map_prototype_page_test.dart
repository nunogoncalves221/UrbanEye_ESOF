import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:project/features/map_prototype_page.dart';

void main() {
  group('MapPrototypePage', () {
    testWidgets('shows app bar, map, marker, and zoom buttons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MapPrototypePage(),
        ),
      );

      expect(find.text('Mapa Prototype'), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byIcon(Icons.location_pin), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNWidgets(2));
    });

    testWidgets('allows tapping zoom buttons without crashing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MapPrototypePage(),
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();

      expect(find.byType(FlutterMap), findsOneWidget);
    });
  });
}