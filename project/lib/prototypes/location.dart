// lib/location_screen.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  String _locationMessage = "Clica no botão para ativar a localização";

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _locationMessage = 'A localização está desativada');
      return;
    }

    // 2. Check and request permissions
    permission =
        await Geolocator.checkPermission(); //ve se o user ja deu a permissao no passado
    if (permission == LocationPermission.denied) {
      // ou e a 1a vez q abre a app ou disse anteriormente nao
      permission =
          await Geolocator.requestPermission(); // faz aparecer o popup a pedir permissão
      if (permission == LocationPermission.denied) {
        setState(() => _locationMessage = 'Permissões foram negadas');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(
        () => _locationMessage =
            'Por favor permita a partilha da sua localização, através das definições do seu dispositivo',
      );
      await Geolocator.openAppSettings(); //abre a pagina das settings da app do dispositivo
      return;
    }

    // 3. Get the current position
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _locationMessage =
          "Lat: ${position.latitude}, Long: ${position.longitude}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Location Prototype")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, size: 50, color: Colors.blue),
            const SizedBox(height: 20),
            Text(_locationMessage, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _determinePosition,
              child: const Text("Obter Localização Atual"),
            ),
          ],
        ),
      ),
    );
  }
}
