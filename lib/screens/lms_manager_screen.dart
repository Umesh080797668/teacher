import 'package:flutter/material.dart';
import 'media_viewer_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';

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
          Uri.parse(
              '${ApiService.baseUrl}/api/lms/videos/teacher/${auth.teacherId}'),
          headers: token != null ? {'Authorization': 'Bearer $token'} : {});
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
    if (urlStr.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Link is empty.')));
      }
      return;
    }

    // Simple verification if it's a valid url
    if (!urlStr.startsWith('http') && !urlStr.startsWith('https')) {
      if (urlStr.startsWith('uploads/')) {
        urlStr = '${ApiService.baseUrl}/$urlStr';
      } else {
        urlStr = 'https://$urlStr';
      }
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MediaViewerScreen(url: urlStr),
        ),
      );
    }
  }

  Future<void> _deleteVideo(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Material'),
        content: const Text('Are you sure you want to delete this material?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final token = await ApiService.getToken();
      final res = await http.delete(
        Uri.parse('${ApiService.baseUrl}/api/lms/videos/$id'),
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Material deleted successfully')),
          );
        }
        _fetchVideos();
      } else {
        throw Exception('Failed to delete material');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _showEditMaterialSheet(
      BuildContext context, Map<String, dynamic> video) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _AddMaterialSheet(
        onMaterialAdded: _fetchVideos,
        initialData: video,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0E17) : const Color(0xFFF5F5FA),
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
                            style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontSize: 16),
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
                                          color: Colors.black
                                              .withAlpha(13), // ~0.05
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: ListTile(
                                onTap: () => _openVideo(v['videoUrl'] ?? ''),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F46E5)
                                        .withAlpha(25), // ~0.1
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
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    if (v['description'] != null &&
                                        v['description'].toString().isNotEmpty)
                                      Text(
                                        v['description'],
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                          fontSize: 14,
                                        ),
                                      ),
                                    Text(
                                      v['videoUrl'] ?? '',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white60
                                            : Colors.black54,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (v['relatedQuizUrl'] != null &&
                                        v['relatedQuizUrl']
                                            .toString()
                                            .isNotEmpty)
                                      IconButton(
                                        icon: Icon(Icons.quiz,
                                            color: Colors.orange.shade400,
                                            size: 22),
                                        onPressed: () =>
                                            _openVideo(v['relatedQuizUrl']),
                                        tooltip: 'Open Quiz',
                                      ),
                                    if (v['relatedMaterialUrl'] != null &&
                                        v['relatedMaterialUrl']
                                            .toString()
                                            .isNotEmpty)
                                      IconButton(
                                        icon: Icon(Icons.assignment,
                                            color: Colors.green.shade400,
                                            size: 22),
                                        onPressed: () =>
                                            _openVideo(v['relatedMaterialUrl']),
                                        tooltip: 'Open Assignment/Material',
                                      ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (val) {
                                        if (val == 'watch') {
                                          _openVideo(v['videoUrl'] ?? '');
                                        } else if (val == 'edit') {
                                          _showEditMaterialSheet(context, v);
                                        } else if (val == 'delete') {
                                          _deleteVideo(v['_id'] ?? '');
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(
                                          value: 'watch',
                                          child: Row(
                                            children: [
                                              Icon(
                                                  Icons
                                                      .play_circle_fill_rounded,
                                                  color: Colors.blue,
                                                  size: 20),
                                              SizedBox(width: 8),
                                              Text('Watch/Open'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit,
                                                  color: Colors.orange,
                                                  size: 20),
                                              SizedBox(width: 8),
                                              Text('Edit'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete,
                                                  color: Colors.red, size: 20),
                                              SizedBox(width: 8),
                                              Text('Delete'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
  final Map<String, dynamic>? initialData;

  const _AddMaterialSheet({required this.onMaterialAdded, this.initialData});

  @override
  State<_AddMaterialSheet> createState() => _AddMaterialSheetState();
}

class _AddMaterialSheetState extends State<_AddMaterialSheet> {
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _relatedQuizUrlCtrl = TextEditingController();
  final _relatedMaterialUrlCtrl = TextEditingController();
  bool _allowDownload = false;
  String? _selectedClassId;
  String? _selectedFileName;
  String? _selectedFilePath;
  String? _selectedFileExtension;
  int? _selectedFileSize;
  bool _isFileUpload = false;
  bool _isSubmitting = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _titleCtrl.text = widget.initialData!['title'] ?? '';
      _urlCtrl.text = widget.initialData!['videoUrl'] ?? '';
      _descriptionCtrl.text = widget.initialData!['description'] ?? '';
      _relatedQuizUrlCtrl.text = widget.initialData!['relatedQuizUrl'] ?? '';
      _relatedMaterialUrlCtrl.text =
          widget.initialData!['relatedMaterialUrl'] ?? '';
      _allowDownload = widget.initialData!['allowDownload'] ?? false;
      final cIdObj = widget.initialData!['classId'];
      if (cIdObj is Map) {
        _selectedClassId = cIdObj['_id'];
      } else if (cIdObj is String) {
        _selectedClassId = cIdObj;
      }
      _isFileUpload =
          false; // Note: for edits, we default to URL mode right now since we can't easily reverse engineer a file upload.
    }
  }

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
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'mp4':
      case 'mkv':
        return Icons.video_file;
      default:
        return Icons.insert_drive_file;
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select a class')));
      return;
    }
    if (!_isFileUpload && _urlCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter a URL')));
      return;
    }
    if (_isFileUpload && _selectedFileName == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select a file')));
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);

    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0.0;
    });

    try {
      final token = await ApiService.getToken();
      String payloadUrl = _urlCtrl.text;

      if (_isFileUpload) {
        if (_selectedFilePath != null) {
          // Actual file upload to backend that forwards to Cloudinary
          var request = http.MultipartRequest(
              'POST', Uri.parse('${ApiService.baseUrl}/api/lms/upload/video'));
          if (token != null) {
            request.headers['Authorization'] = 'Bearer $token';
          }
          request.files.add(
              await http.MultipartFile.fromPath('file', _selectedFilePath!));

          // Run in background while showing visual progress loader
          var streamedResponse = await request.send();
          var response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode == 200) {
            var result = jsonDecode(response.body);
            payloadUrl = result['url'];
            if (mounted) setState(() => _uploadProgress = 1.0);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content:
                      Text('Failed to upload video: ${response.statusCode}')));
              setState(() => _isSubmitting = false);
            }
            return;
          }
        } else {
          payloadUrl = 'uploads/$_selectedFileName'; // Fallback
        }
      }

      final isEdit = widget.initialData != null;
      final videoId = isEdit ? widget.initialData!['_id'] : '';
      final url = isEdit
          ? '${ApiService.baseUrl}/api/lms/videos/$videoId'
          : '${ApiService.baseUrl}/api/lms/videos';

      final req = isEdit
          ? await http.put(Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                if (token != null) 'Authorization': 'Bearer $token'
              },
              body: jsonEncode({
                'title': _titleCtrl.text,
                'description': _descriptionCtrl.text,
                'videoUrl': payloadUrl,
                'classId': _selectedClassId,
                'teacherId': auth.teacherId,
                'allowDownload': _allowDownload,
                'relatedQuizUrl': _relatedQuizUrlCtrl.text,
                'relatedMaterialUrl': _relatedMaterialUrlCtrl.text,
                'duration': 120,
              }))
          : await http.post(Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                if (token != null) 'Authorization': 'Bearer $token'
              },
              body: jsonEncode({
                'title': _titleCtrl.text,
                'description': _descriptionCtrl.text,
                'videoUrl': payloadUrl,
                'classId': _selectedClassId,
                'teacherId': auth.teacherId,
                'allowDownload': _allowDownload,
                'relatedQuizUrl': _relatedQuizUrlCtrl.text,
                'relatedMaterialUrl': _relatedMaterialUrlCtrl.text,
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
              widget.initialData != null ? 'Edit Material' : 'Add Material',
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
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Select Class',
                labelStyle:
                    TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                prefixIcon: Icon(Icons.class_,
                    color: isDark ? Colors.white70 : Colors.black54),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black12),
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
                labelStyle:
                    TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                prefixIcon: Icon(Icons.title,
                    color: isDark ? Colors.white70 : Colors.black54),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description Field
            TextField(
              controller: _descriptionCtrl,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                labelStyle:
                    TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                prefixIcon: Icon(Icons.description,
                    color: isDark ? Colors.white70 : Colors.black54),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black12),
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
                        color: !_isFileUpload
                            ? const Color(0xFF4F46E5).withAlpha(25)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !_isFileUpload
                              ? (isDark
                                  ? const Color(0xFF818CF8)
                                  : const Color(0xFF4F46E5))
                              : (isDark ? Colors.white24 : Colors.black12),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Link (URL)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: !_isFileUpload
                                ? (isDark
                                    ? const Color(0xFF818CF8)
                                    : const Color(0xFF4F46E5))
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
                        color: _isFileUpload
                            ? const Color(0xFF4F46E5).withAlpha(25)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isFileUpload
                              ? (isDark
                                  ? const Color(0xFF818CF8)
                                  : const Color(0xFF4F46E5))
                              : (isDark ? Colors.white24 : Colors.black12),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Upload File',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isFileUpload
                                ? (isDark
                                    ? const Color(0xFF818CF8)
                                    : const Color(0xFF4F46E5))
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
                  labelStyle: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54),
                  prefixIcon: Icon(Icons.link,
                      color: isDark ? Colors.white70 : Colors.black54),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            else if (_selectedFileName == null)
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: Icon(Icons.upload_file,
                    color: isDark ? Colors.white : Colors.black87),
                label: Text(
                  'Pick File',
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black87),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(
                      color: isDark
                          ? const Color(0xFF818CF8)
                          : const Color(0xFF4F46E5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      isDark ? const Color(0xFF2D2660) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark ? Colors.white24 : Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_getFileIcon(_selectedFileExtension),
                            size: 36,
                            color: isDark
                                ? const Color(0xFF818CF8)
                                : const Color(0xFF4F46E5)),
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
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!_isSubmitting)
                          IconButton(
                            icon: const Icon(Icons.cancel_outlined,
                                color: Colors.redAccent),
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
                                backgroundColor:
                                    isDark ? Colors.white12 : Colors.black12,
                                valueColor: AlwaysStoppedAnimation<Color>(isDark
                                    ? const Color(0xFF818CF8)
                                    : const Color(0xFF4F46E5)),
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
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      widget.initialData != null
                          ? 'Update Material'
                          : 'Save Material',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
