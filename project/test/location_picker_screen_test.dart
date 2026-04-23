import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:project/features/report/location_picker_screen.dart';

// Fake reverse geocode that always returns a fixed address
Future<String?> fakeReverseGeocode(double lat, double lon) async =>
    'Rua de exemplo, Lisboa';

// Fake search that always returns a valid point
Future<LatLng?> fakeSearchFound(String query) async =>
    const LatLng(38.7075, -9.1364);

// Fake search that simulates address not found
Future<LatLng?> fakeSearchNotFound(String query) async => null;

// Fake search that simulates a network failure
Future<LatLng?> fakeSearchThrows(String query) async =>
    throw Exception('no network');

// Fake search that never completes, used to test the loading state
Future<LatLng?> fakeSearchSlow(String query) => Completer<LatLng?>().future;

Widget buildPage({
  double? initialLatitude,
  double? initialLongitude,
  ReverseGeocodeFn reverseGeocode = fakeReverseGeocode,
  SearchAddressFn searchAddress = fakeSearchFound,
}) {
  return MaterialApp(
    home: LocationPickerScreen(
      initialLatitude: initialLatitude,
      initialLongitude: initialLongitude,
      reverseGeocode: reverseGeocode,
      searchAddress: searchAddress,
    ),
  );
}

void main() {
  // When the widget opens without an initial location, the hint card should be shown
  testWidgets('shows hint when no location provided', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();
    expect(find.text('Tap the map to place a pin'), findsOneWidget);
  });

  // Without a selected point, the confirm buttons should not appear
  testWidgets('no confirm button before selecting a point', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();
    expect(find.text('Confirm'), findsNothing);
    expect(find.text('Confirm Location'), findsNothing);
  });

  // With an initial location, the coordinates and confirm button should be visible
  testWidgets('shows coordinates and confirm when initial location given', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(initialLatitude: 38.7223, initialLongitude: -9.1393),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('38.72230'), findsOneWidget);
    expect(find.text('Confirm Location'), findsOneWidget);
  });

  // After a successful search, the returned address should be displayed
  testWidgets('shows address label after successful search', (tester) async {
    await tester.pumpWidget(buildPage(searchAddress: fakeSearchFound));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Praça do Comércio');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.textContaining('Rua de exemplo'), findsOneWidget);
  });

  // When the address is not found, the appropriate error message should be shown
  testWidgets('shows error when address not found', (tester) async {
    await tester.pumpWidget(buildPage(searchAddress: fakeSearchNotFound));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'xyzzy');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(
      find.text('Address not found. Try a different query.'),
      findsOneWidget,
    );
  });

  // When the search fails due to a network error, the appropriate error message should be shown
  testWidgets('shows error when search throws', (tester) async {
    await tester.pumpWidget(buildPage(searchAddress: fakeSearchThrows));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'somewhere');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.text('Search failed. Check your connection.'), findsOneWidget);
  });

  // While searching, a spinner should appear and the search icon should be hidden
  testWidgets('shows spinner while searching', (tester) async {
    await tester.pumpWidget(buildPage(searchAddress: fakeSearchSlow));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Lisbon');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.search), findsNothing);
  });

  // If the search field is empty, no request should be made
  testWidgets('does nothing when search field is empty', (tester) async {
    var called = false;
    await tester.pumpWidget(
      buildPage(
        searchAddress: (q) async {
          called = true;
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(called, false);
  });

  // The zoom buttons should always be visible on the map
  testWidgets('zoom FABs are present', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
  });

  // On confirm, the Navigator should pop with the correct LatLng
  testWidgets('pops with the correct LatLng on confirm', (tester) async {
    dynamic result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) => LocationPickerScreen(
                    initialLatitude: 38.7223,
                    initialLongitude: -9.1393,
                    reverseGeocode: fakeReverseGeocode,
                    searchAddress: fakeSearchFound,
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Location'));
    await tester.pumpAndSettle();

    expect((result as LatLng).latitude, closeTo(38.7223, 0.0001));
    expect((result as LatLng).longitude, closeTo(-9.1393, 0.0001));
  });
}
