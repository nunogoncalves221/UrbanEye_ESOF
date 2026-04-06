import 'package:flutter/material.dart';

class ReportProblemPrototype extends StatefulWidget {
  const ReportProblemPrototype({super.key});

  @override
  State<ReportProblemPrototype> createState() => _ReportProblemPrototypeState();
}

class _ReportProblemPrototypeState extends State<ReportProblemPrototype> {
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report a Problem'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // category dropdown menu
            const Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownMenu<String>(
              controller: _categoryController,
              // Makes the dropdown width match the rest of the screen padding
              width: MediaQuery.of(context).size.width - 32,
              hintText: 'Select or type a category...',
              requestFocusOnTap: true,
              dropdownMenuEntries: ['Pothole', 'Streetlight', 'Street sign', 'Traffic light', 'Vandalism', 'Blocked Sidewalk',
                                    'Water leak/Flooding', 'Overgrown Vegetation', 'Abandoned Vehicle', 'Trash']
                  .map((category) => DropdownMenuEntry<String>(
                        value: category,
                        label: category,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),

            //description textbox
            const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter details about the problem here...',
              ),
            ),
            const SizedBox(height: 20),

            //dummy photo and location buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  onPressed: () {}, 
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Photo'),
                ),
                OutlinedButton.icon(
                  onPressed: () {}, 
                  icon: const Icon(Icons.location_on),
                  label: const Text('Location'),
                ),
              ],
            ),
            
            const Spacer(),

            //submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // The _categoryController.text now perfectly captures whatever they typed OR selected
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Report Submitted!')),
                  );
                  
                  // Returns to the main menu
                  Navigator.pop(context);
                },
                child: const Text('SUBMIT REPORT', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}