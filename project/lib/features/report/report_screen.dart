import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'report_controller.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'location_picker_screen.dart';

class ReportScreen extends StatefulWidget {
  final ReportController? controller;
  final FirebaseAuth? auth;
  const ReportScreen({super.key, this.controller, this.auth});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late final ReportController _controller;
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  static const List<String> _categories = [
    'Pothole',
    'Streetlight',
    'Street sign',
    'Traffic light',
    'Vandalism',
    'Blocked Sidewalk',
    'Water leak/Flooding',
    'Overgrown Vegetation',
    'Abandoned Vehicle',
    'Trash',
  ];

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ReportController(auth: widget.auth);
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _descriptionController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    // Sync text fields into controller before submitting
    _controller.description = _descriptionController.text;

    final success = await _controller.submitReport();

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.errorMessage ?? 'Something went wrong.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handlePickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLocation: _controller.latitude != null
              ? LatLng(_controller.latitude!, _controller.longitude!)
              : null,
        ),
      ),
    );

    if (result != null) {
      _controller.latitude = result.latitude;
      _controller.longitude = result.longitude;
      _controller.address = result.address;
      _controller.notifyListeners();
    }
  }

  Future<void> _handlePickPhoto(ImageSource source) async {
    await _controller.pickPhoto(source);
    if (!mounted) return;
    setState(() {});
  }

  void _showPhotoSourceModal() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _handlePickPhoto(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _handlePickPhoto(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report a Problem')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Category ──────────────────────────────────
                const Text(
                  'Category',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownMenu<String>(
                  controller: _categoryController,
                  width: MediaQuery.of(context).size.width - 32,
                  hintText: 'Select or type a category...',
                  requestFocusOnTap: true,
                  dropdownMenuEntries: _categories
                      .map((c) => DropdownMenuEntry<String>(value: c, label: c))
                      .toList(),
                  onSelected: (value) {
                    _controller.selectedCategory = value;
                  },
                ),
                const SizedBox(height: 20),

                // ── Description ───────────────────────────────
                const Text(
                  'Description',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter details about the problem here...',
                  ),
                  onChanged: (value) => _controller.description = value,
                ),
                const SizedBox(height: 20),

                // ── Photo & Location buttons ───────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Photo button — turns green when photo is picked
                    OutlinedButton.icon(
                      onPressed: _controller.isLoading
                          ? null
                          : _showPhotoSourceModal, // <-- Chama o modal aqui
                      icon: Icon(
                        Icons.camera_alt,
                        color: _controller.photo != null ? Colors.green : null,
                      ),
                      label: Text(
                        _controller.photo != null ? 'Photo added ✓' : 'Photo',
                      ),
                    ),

                    // Location button — shows coords when fetched
                    OutlinedButton.icon(
                      onPressed: _controller.isLoading
                          ? null
                          : _handlePickLocation,
                      icon: Icon(
                        Icons.location_on,
                        color: _controller.latitude != null
                            ? Colors.green
                            : null,
                      ),
                      label: Text(
                        _controller.latitude != null
                            ? 'Location set ✓'
                            : 'Location',
                      ),
                    ),
                  ],
                ),

                // Show coordinates if fetched
                if (_controller.latitude != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Lat: ${_controller.latitude!.toStringAsFixed(5)}, '
                      'Lng: ${_controller.longitude!.toStringAsFixed(5)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),

                const Spacer(),

                // ── Submit button ─────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _controller.isLoading ? null : _handleSubmit,
                    child: _controller.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'SUBMIT REPORT',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
