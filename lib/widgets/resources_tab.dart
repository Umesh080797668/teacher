import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class ResourcesTab extends StatefulWidget {
  final String classId;

  const ResourcesTab({super.key, required this.classId});

  @override
  State<ResourcesTab> createState() => _ResourcesTabState();
}

class _ResourcesTabState extends State<ResourcesTab> {
  List<Map<String, dynamic>> _resources = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    try {
      final resources = await ApiService.getResources(widget.classId);
      if (mounted) {
        setState(() {
          _resources = resources;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load resources: $e')));
      }
    }
  }

  Future<void> _uploadResource() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    File? selectedFile;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Resource'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () async {
                    FilePickerResult? result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
                    );

                    if (result != null) {
                      setState(() {
                        selectedFile = File(result.files.single.path!);
                      });
                    }
                  },
                  icon: const Icon(Icons.attach_file),
                  label: Text(selectedFile == null ? 'Select File' : 'File Selected'),
                ),
                if (selectedFile != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      selectedFile!.path.split('/').last,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty || selectedFile == null) return;
              try {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading...')));
                Navigator.pop(context); // Close dialog

                await ApiService.uploadResource(
                  widget.classId,
                  titleController.text,
                  descController.text,
                  selectedFile!,
                  auth.teacherId!,
                );
                
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploaded successfully!')));
                _loadResources();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to upload: $e')),
                );
              }
            },
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  Future<void> _openResource(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open file')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadResource,
        child: const Icon(Icons.upload_file),
        tooltip: 'Upload Material',
      ),
      body: _resources.isEmpty
          ? const Center(child: Text('No resources available.'))
          : ListView.builder(
              itemCount: _resources.length,
              itemBuilder: (context, index) {
                final res = _resources[index];
                IconData icon = Icons.insert_drive_file;
                if (res['fileType'].toString().contains('pdf')) icon = Icons.picture_as_pdf;
                if (res['fileType'].toString().contains('image')) icon = Icons.image;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(icon, color: Colors.white), backgroundColor: Colors.blue),
                    title: Text(res['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (res['description'] != null && res['description'].isNotEmpty) 
                          Text(res['description']),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat.yMMMd().format(DateTime.parse(res['createdAt'])),
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => _openResource(res['fileUrl']),
                    ),
                    onTap: () => _openResource(res['fileUrl']),
                  ),
                );
              },
            ),
    );
  }
}
