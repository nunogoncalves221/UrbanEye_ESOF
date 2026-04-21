import 'package:flutter/material.dart';

import 'auth_page.dart';
import 'img_picker.dart';
import 'img_taker.dart';
import 'location.dart';
import 'map_prototype_page.dart';
import 'problems_list.dart';
import 'report_problem.dart';

class PrototypeListPage extends StatelessWidget {
  const PrototypeListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prototypes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MapPrototypePage()),
              );
            },
            child: const Text('Map Prototype'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuthPage()),
              );
            },
            child: const Text('Auth Prototype'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LocationScreen()),
              );
            },
            child: const Text('Location Prototype'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReportProblemPrototype(),
                ),
              );
            },
            child: const Text('Report Problem Prototype'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProblemsList()),
              );
            },
            child: const Text('Problems List Prototype'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ImagePickerPage()),
              );
            },
            child: const Text('Image Picker Prototype'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ImgTakerPage()),
              );
            },
            child: const Text('Camera Prototype'),
          ),
        ],
      ),
    );
  }
}
