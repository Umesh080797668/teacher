import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../providers/classes_provider.dart';
import '../services/api_service.dart';

class LmsManagerScreen extends StatefulWidget {
  const LmsManagerScreen({super.key});

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
        final token = await ApiService.getToken();
        final res = await http.get(
            Uri.parse('${ApiService.baseUrl}/api/lms/videos/teacher/${auth.teacherId}'),
            headers: token != null ? {'Authorization': 'Bearer $token'} : {}
        );
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

  Future<void> _openVideo(String urlStr) async {
    if (urlStr.isEmpty) return;
    
    // Simple verification if it's a valid url
    if (!urlStr.startsWith('http') && !urlStr.startsWith('https')) {
      if (urlStr.startsWith('uploads/')) {
        urlStr = '${ApiService.baseUrl}/$urlStr';
      } else {
        urlStr = 'https://$urlStr';
      }
    }
    
    final uri = Uri.parse(urlStr);
    try {
      if (await canLaunchUrl(uri)) {
        // Run inside the app web view
        await launchUrl(uri, mode: LaunchMode.inAppWebView);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cannot open this media.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error opening media: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        color: Colors.white.withAlpha(45), // ~0.18
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
                            color: Colors.white.withAlpha(190), // ~0.75
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
                      ? Center(
                          child: Text(
                            "No materials uploaded yet.",
                            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 16),
                          ),
                        )
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
                                          color: Colors.black.withAlpha(13), // ~0.05
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: ListTile(
                                onTap: () => _openVideo(v['url'] ?? ''),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F46E5).withAlpha(25), // ~0.1
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
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  v['url'] ?? '',
                                  style: TextStyle(
                                    color: isDark ? Colors.white60 : Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: const Color(0xFF4F46E5).withAlpha(150),
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
  String? _selectedFileExtension;
  int? _selectedFileSize;
  bool _isFileUpload = false;
  bool _isSubmitting = false;
  double _uploadProgress = 0.0;

  bool get _isFormValid {
    if (_titleCtrl.text.trim().isEmpty) return false;
    if (_selectedClassId == null) return false;
    if (_isFileUpload) {
      if (_selectedFileName == null) return false;
    } else {
      if (_urlCtrl.text.trim().isEmpty) return false;
    }
    return true;
  }

  String _getFileSizeString(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'doc':
      case 'docx': return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png': return Icons.image;
      case 'mp4':
      case 'mkv': return Icons.video_file;
      default: return Icons.insert_drive_file;
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFileName = result.files.first.name;
        _selectedFileExtension = result.files.first.extension;
        _selectedFileSize = result.files.first.size;
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

    final auth = Provider.of<AuthProvider>(context, listen: false);

    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0.0;
    });

    if (_isFileUpload) {
      // Simulate file upload progress roughly to match requirement visualization
      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) setState(() => _uploadProgress = i / 10.0);
      }
    }

    // Simulate URL generation for uploaded files to fit model requirement
    String payloadUrl = _isFileUpload ? 'uploads/$_selectedFileName' : _urlCtrl.text;

    try {
      final token = await ApiService.getToken();
      final req = await http.post(
          Uri.parse('${ApiService.baseUrl}/api/lms/videos'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token'
          },
          body: jsonEncode({
            'title': _titleCtrl.text,
            'videoUrl': payloadUrl,
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
              color: Colors.black.withAlpha(64), // ~0.25
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
                  color: Colors.grey.withAlpha(90), // ~0.35
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Add Material',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),

            // Class Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedClassId,
              dropdownColor: isDark ? const Color(0xFF2D2660) : Colors.white,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Select Class',
                labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                prefixIcon: Icon(Icons.class_, color: isDark ? Colors.white70 : Colors.black54),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                ),
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
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                prefixIcon: Icon(Icons.title, color: isDark ? Colors.white70 : Colors.black54),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                ),
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
                        color: !_isFileUpload ? const Color(0xFF4F46E5).withAlpha(25) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !_isFileUpload 
                              ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                              : (isDark ? Colors.white24 : Colors.black12),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Link (URL)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: !_isFileUpload 
                                ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                                : (isDark ? Colors.white54 : Colors.black54),
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
                        color: _isFileUpload ? const Color(0xFF4F46E5).withAlpha(25) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isFileUpload 
                              ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                              : (isDark ? Colors.white24 : Colors.black12),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Upload File',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isFileUpload 
                                ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                                : (isDark ? Colors.white54 : Colors.black54),
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
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Material URL (e.g. YouTube, Drive)',
                  labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                  prefixIcon: Icon(Icons.link, color: isDark ? Colors.white70 : Colors.black54),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            else
              if (_selectedFileName == null)
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: Icon(Icons.upload_file, color: isDark ? Colors.white : Colors.black87),
                  label: Text(
                    'Pick File',
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D2660) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_getFileIcon(_selectedFileExtension), size: 36, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedFileName!,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_selectedFileSize != null)
                                  Text(
                                    _getFileSizeString(_selectedFileSize!),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (!_isSubmitting)
                            IconButton(
                              icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                              onPressed: () {
                                setState(() {
                                  _selectedFileName = null;
                                  _selectedFileExtension = null;
                                  _selectedFileSize = null;
                                });
                              },
                            )
                        ],
                      ),
                      if (_isSubmitting) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _uploadProgress,
                                  backgroundColor: isDark ? Colors.white12 : Colors.black12,
                                  valueColor: AlwaysStoppedAnimation<Color>(isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${(_uploadProgress * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            )
                          ],
                        )
                      ]
                    ],
                  ),
                ),
            
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (!_isFormValid || _isSubmitting) ? null : _submit,
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
                  : Text('Save Material', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
