import 'package:flutter/material.dart';
import 'location.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget { // nao quero que a meio clique num botao e mude td
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Urban Eye',
     
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),

      // This tells Flutter: "When the app opens, show this screen"
      home: const LocationScreen(),
      
      // Removes the "Debug" banner from the top right corner
      debugShowCheckedModeBanner: false,
    );
  }
}
