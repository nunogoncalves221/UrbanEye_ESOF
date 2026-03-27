import 'package:flutter/material.dart'; // widgets
import 'package:flutter_test/flutter_test.dart';
import 'package:project/report_grouping_service.dart';
import 'package:project/report.dart';
import 'package:project/alert.dart';
import 'package:project/alert_list.dart';

void main(){
  group('User Story: Report Grouping for authorities',(){
    late ReportGroupingService grouping_service; // se declaro uma variavel tenho de lhe dar um valor logo 
  
    setUp((){
      grouping_service = ReportGroupingService(proximity_rad: 80);
    });

    // casos normais
    group('Normal Case - same category, same location',(){
      test ('T1: 3 reports grouped into one alert',() => testNormalGrouping(grouping_service));
      test ('T2: Count increments',() => testIncrementLogic(grouping_service));
      testWidgets ('T3: UI shows corrected count', testUICount);
      });
    // casos especiais
    group('Normal Case - different category, same location',(){
      test ('T4: 3 reports grouped into 3 different alerts',() => testDifferentCategories(grouping_service));
      test ('T5: Independent Count for each',() => testIndependentCounts(grouping_service));
      testWidgets ('T6: UI shows different reports with correct count', testUISeparateCards);
    });

    //testes de proximidade
    group('Proximity boundary tests', (){
      test('T7: Reports far apart are not grouped',() => testProximityLimits(grouping_service));
    });
  
  });
}

// funções de lógica

void testNormalGrouping(ReportGroupingService service) {
  final reports = [
    Report(id: '1', category: 'Luz', latitude: 41.1579, longitude: -8.6291),
    Report(id: '2', category: 'Luz', latitude: 41.1580, longitude: -8.6292),
    Report(id: '3', category: 'Luz', latitude: 41.1578, longitude: -8.6290),
  ];

  final alerts = service.groupReports(reports);

  expect(alerts.length, 1);
  expect(alerts.first.reportCount, 3);
}

void testIncrementLogic(ReportGroupingService service) {
  final initial = [
    Report(id: '1', category: 'Luz', latitude: 41.1579, longitude: -8.6291),
  ];
  
  var alerts = service.groupReports(initial);
  expect(alerts.first.reportCount, 1);

  final extra = Report(id: '2', category: 'Luz', latitude: 41.1579, longitude: -8.6291);
  alerts = service.groupReports([...initial, extra]);

  expect(alerts.first.reportCount, 2);
}

void testDifferentCategories(ReportGroupingService service) {
  final reports = [
    Report(id: '1', category: 'Luz', latitude: 41.1579, longitude: -8.6291),
    Report(id: '2', category: 'Buraco', latitude: 41.1579, longitude: -8.6291),
  ];

  final alerts = service.groupReports(reports);
  expect(alerts.length, 2);
}

void testIndependentCounts(ReportGroupingService service) {
  final reports = [
    Report(id: '1', category: 'Luz', latitude: 41.15, longitude: -8.62),
    Report(id: '2', category: 'Luz', latitude: 41.15, longitude: -8.62),
    Report(id: '3', category: 'Buraco', latitude: 41.15, longitude: -8.62),
  ];

  final alerts = service.groupReports(reports);
  final luz = alerts.firstWhere((a) => a.category == 'Luz');
  final buraco = alerts.firstWhere((a) => a.category == 'Buraco');

  expect(luz.reportCount, 2);
  expect(buraco.reportCount, 1);
}

void testProximityLimits(ReportGroupingService service) {
  final reports = [
    Report(id: '1', category: 'Luz', latitude: 41.15, longitude: -8.62),
    Report(id: '2', category: 'Luz', latitude: 41.25, longitude: -8.70), // Longe
  ];

  final alerts = service.groupReports(reports);
  expect(alerts.length, 2);
}


// funções de Interface
Future<void> testUICount(WidgetTester tester) async {
  final alerts = [
    Alert(id: 'a1', category: 'Luz', reportCount: 3, latitude: 0, longitude: 0),
  ];

  await tester.pumpWidget(MaterialApp(home: Scaffold(body: AlertList(alerts: alerts))));

  expect(find.text('No. Relatos: 3'), findsOneWidget);
  expect(find.text('Luz'), findsOneWidget);
}

Future<void> testUISeparateCards(WidgetTester tester) async {
  final alerts = [
    Alert(id: 'a1', category: 'Luz', reportCount: 1, latitude: 0, longitude: 0),
    Alert(id: 'a2', category: 'Buraco', reportCount: 1, latitude: 0, longitude: 0),
  ];

  await tester.pumpWidget(MaterialApp(home: Scaffold(body: AlertList(alerts: alerts))));

  expect(find.text('Luz'), findsOneWidget);
  expect(find.text('Buraco'), findsOneWidget);
}