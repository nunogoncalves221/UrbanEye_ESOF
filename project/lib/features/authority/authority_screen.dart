import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Se usares provider, senão usa o teu sistema de estado
import 'package:project/features/report/report_controller.dart';
import 'package:project/features/report/report_model.dart';
class AuthorityScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<ReportController>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel de Controlo: Autoridade'),
        backgroundColor: Colors.indigo,
      ),
      body: StreamBuilder<List<ReportModel>>(
        stream: controller.watchAuthorityReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snapshot.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              
              return Card(
                elevation: report.isPriority ? 10 : 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: report.isPriority 
                    ? const BorderSide(color: Colors.amber, width: 2) 
                    : BorderSide.none,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo.shade50,
                    child: Text('${report.existsConfirmations}'),
                  ),
                  title: Text(report.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(report.description),
                  trailing: IconButton(
                    // ÍCONE DE PRIORIDADE
                    icon: Icon(
                      report.isPriority ? Icons.star : Icons.star_border,
                      color: report.isPriority ? Colors.amber : Colors.grey,
                    ),
                    onPressed: () => controller.togglePriority(report.id!, report.isPriority),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}