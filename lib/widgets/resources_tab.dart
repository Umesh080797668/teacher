import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'custom_widgets.dart';

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

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        final cs = Theme.of(sheetCtx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, -4))],
                ),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2)))),
                      Row(
                        children: [
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Add Resource', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: cs.onSurface)),
                              Text('Upload study materials for students', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                            ]),
                          ),
                          IconButton(onPressed: () => Navigator.pop(sheetCtx), icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: titleController,
                        style: TextStyle(color: cs.onSurface),
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Title',
                          hintText: 'e.g., Mathematics PDF',
                          labelStyle: TextStyle(color: cs.onSurfaceVariant),
                          prefixIcon: const Icon(Icons.title_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: descController,
                        style: TextStyle(color: cs.onSurface),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Description (Optional)',
                          labelStyle: TextStyle(color: cs.onSurfaceVariant),
                          alignLabelWithHint: true,
                          prefixIcon: const Icon(Icons.description_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () async {
                          FilePickerResult? result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
                          );
                          if (result != null) {
                            setSheetState(() {
                              selectedFile = File(result.files.single.path!);
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? cs.surfaceContainerHigh : const Color(0xFFF5F5FA),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: selectedFile != null ? const Color(0xFF4F46E5).withValues(alpha: 0.5) : cs.outlineVariant.withValues(alpha: 0.5)),
                          ),
                          child: selectedFile != null
                              ? Row(children: [
                                  Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(color: const Color(0xFF4F46E5).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF4F46E5)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(selectedFile!.path.split('/').last, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface), overflow: TextOverflow.ellipsis)),
                                  Icon(Icons.edit_rounded, color: cs.onSurfaceVariant, size: 18),
                                ])
                              : Row(children: [
                                  Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(color: cs.outlineVariant.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                                    child: Icon(Icons.attach_file_rounded, color: cs.onSurfaceVariant),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('Select File', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                                    Text('PDF, DOCX, Images supported', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                  ]),
                                ]),
                        ),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () async {
                          if (titleController.text.isEmpty || selectedFile == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a title and select a file.')),
                            );
                            return;
                          }
                          try {
                            final auth = Provider.of<AuthProvider>(context, listen: false);
                            Navigator.pop(sheetCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Row(children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), SizedBox(width: 12), Text('Uploading resource...')]),
                                duration: Duration(days: 1),
                              ),
                            );
                            await ApiService.uploadResource(
                              widget.classId,
                              titleController.text,
                              descController.text,
                              selectedFile!,
                              auth.teacherId!,
                            );
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resource uploaded successfully!')));
                            if (mounted) _loadResources();
                          } catch (e) {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
                          }
                        },
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], begin: Alignment.centerLeft, end: Alignment.centerRight),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 5))],
                          ),
                          child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 10),
                            Text('Upload Resource', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                          ])),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 5,
        itemBuilder: (_, __) => const ResourceCardSkeleton(),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadResource,
        tooltip: 'Upload Material',
        child: const Icon(Icons.upload_file),
      ),
      body: _resources.isEmpty
          ? Center(child: Text('No resources available.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)))
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
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Icon(icon, color: Theme.of(context).colorScheme.onPrimary),
                    ),
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
