import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';

import '../providers/auth_provider.dart';
import '../providers/classes_provider.dart';
import '../services/api_service.dart';

class LmsManagerScreen extends StatefulWidget {
  const LmsManagerScreen({Key? key}) : super(key: key);

  @override
  State<LmsManagerScreen> createState() => _LmsManagerScreenState();
}

class _LmsManagerScreenState extends State<LmsManagerScreen> {
  bool _isLoading = false;
  List<dynamic> _videos = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClassesProvider>().loadClasses(
            teacherId: context.read<AuthProvider>().teacherId,
          );
      _fetchVideos();
    });
  }

  Future<void> _fetchVideos() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.teacherId == null) return;
      final res = await http.get(
          Uri.parse('${ApiService.baseUrl}/api/lms/videos/teacher/${auth.teacherId}'));
      if (res.statusCode == 200) {
        setState(() {
          _videos = jsonDecode(res.body);
        });
      }
    } catch (e) {
      debugPrint("Error loading LMS: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddMaterialSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _AddMaterialSheet(onMaterialAdded: _fetchVideos),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0E17) : const Color(0xFFF5F5FA),
      body: SafeArea(
        child: Column(
          children: [
            // Pinned Gradient Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        colors: [Color(0xFF1E1A2E), Color(0xFF2D2660)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [
                          Color(0xFF3730A3),
                          Color(0xFF4F46E5),
                          Color(0xFF7C3AED)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LMS Manager',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Manage your course materials',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _videos.isEmpty
                      ? const Center(child: Text("No materials uploaded yet."))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _videos.length,
                          itemBuilder: (ctx, i) {
                            final v = _videos[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E1B2E)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: isDark
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.video_library,
                                      color: Color(0xFF4F46E5)),
                                ),
                                title: Text(
                                  v['title'] ?? 'Untitled',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  v['url'] ?? '',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        onPressed: () => _showAddMaterialSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: Text('Add Material',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _AddMaterialSheet extends StatefulWidget {
  final VoidCallback onMaterialAdded;

  const _AddMaterialSheet({required this.onMaterialAdded});

  @override
  State<_AddMaterialSheet> createState() => _AddMaterialSheetState();
}

class _AddMaterialSheetState extends State<_AddMaterialSheet> {
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  String? _selectedClassId;
  String? _selectedFileName;
  bool _isFileUpload = false;
  bool _isSubmitting = false;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFileName = result.files.first.name;
        // In a real scenario, you'd handle the file object. 
        // For UI demo, we'll put the file name in the URL box or keep it separated.
      });
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a title')));
      return;
    }
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a class')));
      return;
    }
    if (!_isFileUpload && _urlCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a URL')));
      return;
    }
    if (_isFileUpload && _selectedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a file')));
      return;
    }

    setState(() => _isSubmitting = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    // In a full implementation with multipart/form-data, you'd use http.MultipartRequest
    // For this UI requirement, we simulate URL generation for uploaded files if no backend upload route is provided
    String payloadUrl = _isFileUpload ? 'uploads/$_selectedFileName' : _urlCtrl.text;

    try {
      final req = await http.post(
          Uri.parse('${ApiService.baseUrl}/api/lms/videos'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'title': _titleCtrl.text,
            'url': payloadUrl,
            'classId': _selectedClassId,
            'teacherId': auth.teacherId,
            'duration': 120,
          }));
      if (req.statusCode == 201 || req.statusCode == 200) {
        if (mounted) Navigator.pop(context);
        widget.onMaterialAdded();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Material Added Successfully!')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to add material')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final classesProvider = context.watch<ClassesProvider>();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, -4),
            )
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Add Material',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 20),

            // Class Dropdown
            DropdownButtonFormField<String>(
              value: _selectedClassId,
              dropdownColor: isDark ? const Color(0xFF2D2660) : Colors.white,
              decoration: InputDecoration(
                labelText: 'Select Class',
                prefixIcon: const Icon(Icons.class_),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: classesProvider.classes.map((c) {
                return DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedClassId = val);
              },
            ),
            const SizedBox(height: 16),

            // Title Field
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Title',
                prefixIcon: const Icon(Icons.title),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            // Toggle URL or File
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isFileUpload = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isFileUpload ? const Color(0xFF4F46E5).withValues(alpha: 0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !_isFileUpload ? const Color(0xFF4F46E5) : cs.outlineVariant,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Link (URL)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: !_isFileUpload ? const Color(0xFF4F46E5) : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isFileUpload = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isFileUpload ? const Color(0xFF4F46E5).withValues(alpha: 0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isFileUpload ? const Color(0xFF4F46E5) : cs.outlineVariant,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Upload File',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isFileUpload ? const Color(0xFF4F46E5) : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (!_isFileUpload)
              TextField(
                controller: _urlCtrl,
                decoration: InputDecoration(
                  labelText: 'Material URL (e.g. YouTube, Drive)',
                  prefixIcon: const Icon(Icons.link),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Pick File'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFF4F46E5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (_selectedFileName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Selected: $_selectedFileName',
                      style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    )
                  ]
                ],
              ),
            
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text('Save Material', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
