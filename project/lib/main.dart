import 'package:flutter/material.dart';
import 'package:project/report_grouping_service.dart';
import 'package:project/report.dart';
import 'package:project/alert.dart';
import 'package:project/alert_list.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget { // nao quero que a meio clique num botao e mude td
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ReportGroupingService(proximity_rad: 80);

    final reports =[
      Report(id: '1', category: 'Luz do Semáforo Avariada', latitude: 41.1579, longitude: -8.6291),
      Report(id: '2', category: 'Luz do Semáforo Avariada', latitude: 41.1580, longitude: -8.6292),
      Report(id: '3', category: 'Luz do Semáforo Avariada', latitude: 41.1578, longitude: -8.6290),
      Report(id: '4', category: 'Buraco na Estrada',latitude: 41.1579, longitude: -8.6291),
    ];
    final alerts = service.groupReports(reports);
    return MaterialApp(
      home: Scaffold(appBar: AppBar(title: const Text('Alertas')), body: AlertList(alerts: alerts),),
    );
  }
}
