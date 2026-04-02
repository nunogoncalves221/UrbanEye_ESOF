import 'package:flutter/material.dart';
import 'features/map_prototype_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Prototypes'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MapPrototypePage(),
                ),
              );
            },
            child: const Text('Mapa Prototype'),
          ),
        ],
      ),
    );
  }
}