// lib/features/img_taker.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImgTakerPage extends StatefulWidget {
  const ImgTakerPage({super.key});

  @override
  State<ImgTakerPage> createState() => _ImgTakerPageState();
}

class _ImgTakerPageState extends State<ImgTakerPage> {
  final ImagePicker _picker = ImagePicker();
  File? _image;
  String _statusMessage = "Clica no botão para tirar uma foto";

  Future<void> _takePhoto() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.camera);

      if (picked != null) {
        //not cancelled
        setState(() {
          _image = File(picked.path);
          _statusMessage = "Foto tirada com sucesso!";
        });
      } else {
        //cancelled
        setState(() {
          _statusMessage = "Nenhuma foto tirada";
        });
      }
    } catch (e) {
      // uh-oh
      setState(() {
        _statusMessage = "Ocorreu um erro: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Camera Prototype")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _image != null
                ? Image.file(
                    _image!,
                    width: 250,
                    height: 250,
                    fit: BoxFit.cover,
                  ) // display the image
                : const Icon(
                    Icons.camera_alt,
                    size: 100,
                    color: Colors.grey,
                  ), // display a placeholder
            const SizedBox(height: 20),
            Text(_statusMessage, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              //button to prompts
              onPressed: _takePhoto,
              child: const Text("Tirar Foto"),
            ),
          ],
        ),
      ),
    );
  }
}
