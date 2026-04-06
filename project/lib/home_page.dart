import 'package:flutter/material.dart';
import 'features/location.dart';
import 'features/auth_page.dart';
import 'features/map_prototype_page.dart';
import 'features/report_problem.dart';

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
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AuthPage(),
                ),
              );
            },
            child: const Text('Login / Register Prototype'),
          ),
     const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LocationScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade50, 
            ),
            child: const Text('Localização Prototype'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  // Make sure this matches the class name in your file!
                  builder: (context) => const ReportProblemPrototype(), 
                ),
              );
            },
            child: const Text('Report Problem Prototype'),
          ),
        ],
      ),
    );
  }
}
