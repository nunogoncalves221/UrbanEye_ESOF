import 'package:flutter/material.dart';

class ProblemsList extends StatelessWidget {
  const ProblemsList({super.key});

  // List of simulated problems
  final List<Map<String, String>> problems = const [
    {'street': 'Rua Augusta', 'type': 'Buraco na estrada'},
    {'street': 'Avenida da Liberdade', 'type': 'Lixo na rua'},
    {'street': 'Praça do Comércio', 'type': 'Iluminação defeituosa'},
    {'street': 'Rua do Alecrim', 'type': 'Árvore caída'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lista de Problemas')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: problems.length,
        itemBuilder: (context, index) {
          final problem = problems[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.warning, color: Colors.red),
              title: Text(problem['street']!),
              subtitle: Text(problem['type']!),
              onTap: () {
                // Aqui podes adicionar ação quando clicarem no problema
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Selecionaste ${problem['street']}')),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
