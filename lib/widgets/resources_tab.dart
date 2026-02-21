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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Resource', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        content: StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      hintText: 'e.g., Mathematics PDF',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(8),
                          color: Theme.of(context).colorScheme.surfaceVariant,
                    ),
                    child: Column(
                      children: [
                        if (selectedFile != null) ...[
                          Icon(Icons.check_circle, color: Theme.of(context).colorScheme.secondary, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            selectedFile!.path.split('/').last,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                        ],
                        OutlinedButton.icon(
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
                          label: Text(selectedFile == null ? 'Select Attachment' : 'Change  File'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                        if (selectedFile == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Supported: PDF, DOCX, Images',
                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () async {
              if (titleController.text.isEmpty || selectedFile == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please verify Title and attached File.')),
                );
                return;
              }
              try {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                Navigator.pop(context); // Close dialog first

                // Show loading snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(children: [CircularProgressIndicator(), SizedBox(width: 10), Text('Uploading resource...')]), 
                    duration: Duration(days: 1)
                  )
                );

                await ApiService.uploadResource(
                  widget.classId,
                  titleController.text,
                  descController.text,
                  selectedFile!,
                  auth.teacherId!,
                );
                
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resource Uploaded successfully!')));
                if (mounted) _loadResources();
              } catch (e) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Upload failed: $e')),
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
    if (_isLoading) return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadResource,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: const Icon(Icons.upload_file),
        tooltip: 'Upload Material',
      ),
      body: _resources.isEmpty
          ? Center(child: Text('No resources available.', style: TextStyle(color: Theme.of(context).colorScheme.onBackground)))
          : ListView.builder(
              itemCount: _resources.length,
              itemBuilder: (context, index) {
                final res = _resources[index];
                IconData icon = Icons.insert_drive_file;
                if (res['fileType'].toString().contains('pdf')) icon = Icons.picture_as_pdf;
                if (res['fileType'].toString().contains('image')) icon = Icons.image;

                return Card(
                  color: Theme.of(context).cardColor,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(icon, color: Theme.of(context).colorScheme.onPrimary), backgroundColor: Theme.of(context).colorScheme.primary),
                    title: Text(res['title'], style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (res['description'] != null && res['description'].isNotEmpty) 
                          Text(res['description'], style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat.yMMMd().format(DateTime.parse(res['createdAt'])),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.open_in_new, color: Theme.of(context).colorScheme.onSurface),
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
