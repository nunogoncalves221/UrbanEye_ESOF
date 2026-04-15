// lib/features/image_picker_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerPage extends StatefulWidget {
  const ImagePickerPage({super.key});

  @override
  State<ImagePickerPage> createState() => _ImagePickerPageState();
}

class _ImagePickerPageState extends State<ImagePickerPage> {
  final ImagePicker _picker = ImagePicker();
  File? _image;
  String _statusMessage = "Clica no botão para escolher uma imagem";

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (picked != null) {
        //not cancelled
        setState(() {
          _image = File(picked.path);
          _statusMessage = "Imagem carregada com sucesso";
        });
      } else {
        //cancelled
        setState(() {
          _statusMessage = "Nenhuma imagem selecionada";
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
      appBar: AppBar(title: const Text("Image Picker Prototype")),
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
                    Icons.image,
                    size: 100,
                    color: Colors.grey,
                  ), // display a placeholder
            const SizedBox(height: 20),
            Text(_statusMessage, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              //button to prompts
              onPressed: _pickImage,
              child: const Text("Escolher da Galeria"),
            ),
          ],
        ),
      ),
    );
  }
}
