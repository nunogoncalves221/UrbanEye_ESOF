import 'package:flutter/material.dart';
import 'alert.dart';

class AlertList extends StatelessWidget {
  final List<Alert> alerts;

  const AlertList({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final alert = alerts[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            title: Text(
              alert.category,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: Chip(
              label: Text('No. Relatos: ${alert.reportCount}'),
              backgroundColor: Colors.red.shade100,
            ),
          ),
        );
      },
    );
  }
}