import re

with open('lib/screens/lms_manager_screen.dart', 'r') as f:
    content = f.read()

# 1. Fix _openVideo
open_video_old = """  Future<void> _openVideo(String urlStr) async {
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
  }"""

open_video_new = """  Future<void> _openVideo(String urlStr) async {
    if (urlStr.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Link is empty.')));
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
    
    final uri = Uri.parse(urlStr);
    try {
      if (await canLaunchUrl(uri)) {
        // Use external Application to let the OS decide how to open the video/link to avoid webview limitations
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback for some links that canLaunchUrl rejects but launchUrl accepts
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error opening link: $e')));
      }
    }
  }"""

content = content.replace(open_video_old, open_video_new)

# 2. Add properties to State
state_vars_old = """
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  String? _selectedClassId;
  String? _selectedFileName;
  String? _selectedFileExtension;
  int? _selectedFileSize;
  bool _isFileUpload = false;
  bool _isSubmitting = false;
  double _uploadProgress = 0.0;
"""

state_vars_new = """
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _relatedQuizUrlCtrl = TextEditingController();
  final _relatedMaterialUrlCtrl = TextEditingController();
  bool _allowDownload = false;
  String? _selectedClassId;
  String? _selectedFileName;
  String? _selectedFileExtension;
  int? _selectedFileSize;
  bool _isFileUpload = false;
  bool _isSubmitting = false;
  double _uploadProgress = 0.0;
"""
content = re.sub(r"  final _titleCtrl = TextEditingController\(\);\n.*?double _uploadProgress = 0\.0;", state_vars_new.strip(), content, flags=re.DOTALL)


# 3. Add to initState
init_state_old = """
    if (widget.initialData != null) {
      _titleCtrl.text = widget.initialData!['title'] ?? '';
      _urlCtrl.text = widget.initialData!['videoUrl'] ?? '';
      _descriptionCtrl.text = widget.initialData!['description'] ?? '';
      final cIdObj = widget.initialData!['classId'];
      if (cIdObj is Map) {
         _selectedClassId = cIdObj['_id'];
      } else if (cIdObj is String) {
         _selectedClassId = cIdObj;
      }
      _isFileUpload = false; // Note: for edits, we default to URL mode right now since we can't easily reverse engineer a file upload.
    }
"""

init_state_new = """
    if (widget.initialData != null) {
      _titleCtrl.text = widget.initialData!['title'] ?? '';
      _urlCtrl.text = widget.initialData!['videoUrl'] ?? '';
      _descriptionCtrl.text = widget.initialData!['description'] ?? '';
      _relatedQuizUrlCtrl.text = widget.initialData!['relatedQuizUrl'] ?? '';
      _relatedMaterialUrlCtrl.text = widget.initialData!['relatedMaterialUrl'] ?? '';
      _allowDownload = widget.initialData!['allowDownload'] ?? false;
      final cIdObj = widget.initialData!['classId'];
      if (cIdObj is Map) {
         _selectedClassId = cIdObj['_id'];
      } else if (cIdObj is String) {
         _selectedClassId = cIdObj;
      }
      _isFileUpload = false; // Note: for edits, we default to URL mode right now since we can't easily reverse engineer a file upload.
    }
"""
content = content.replace(init_state_old, init_state_new)

# 4. HTTP Request Body Update
http_req_old = """
              body: jsonEncode({
                'title': _titleCtrl.text,
                'description': _descriptionCtrl.text,
                'videoUrl': payloadUrl,
                'classId': _selectedClassId,
                'teacherId': auth.teacherId,
                'duration': 120,
              }))
"""

http_req_new = """
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
"""
content = content.replace(http_req_old, http_req_new)

# 5. UI Additions in Sheet
ui_fields = """
            // Allow Download Switch
            SwitchListTile(
              title: Text('Allow Students to Download', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              subtitle: Text('If disabled, students can only view the material in the app', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 12)),
              value: _allowDownload,
              activeColor: const Color(0xFF4F46E5),
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() => _allowDownload = val);
              },
            ),
            const SizedBox(height: 16),

            // Related Quiz Field
            TextField(
              controller: _relatedQuizUrlCtrl,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Related Quiz URL (Optional)',
                labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                prefixIcon: Icon(Icons.quiz, color: isDark ? Colors.white70 : Colors.black54),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Related Material/Assignment Field
            TextField(
              controller: _relatedMaterialUrlCtrl,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Assignments / Extra Material URL (Optional)',
                labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                prefixIcon: Icon(Icons.assignment, color: isDark ? Colors.white70 : Colors.black54),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
"""

content = content.replace("const SizedBox(height: 24),\n\n            ElevatedButton(", ui_fields + "            ElevatedButton(")

# 6. ListTile Buttons in View
icons_to_add = """
                                trailing: PopupMenuButton<String>(
"""

icons_added = """
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (v['relatedQuizUrl'] != null && v['relatedQuizUrl'].toString().isNotEmpty)
                                      IconButton(
                                        icon: Icon(Icons.quiz, color: Colors.orange.shade400, size: 22),
                                        onPressed: () => _openVideo(v['relatedQuizUrl']),
                                        tooltip: 'Open Quiz',
                                      ),
                                    if (v['relatedMaterialUrl'] != null && v['relatedMaterialUrl'].toString().isNotEmpty)
                                      IconButton(
                                        icon: Icon(Icons.assignment, color: Colors.green.shade400, size: 22),
                                        onPressed: () => _openVideo(v['relatedMaterialUrl']),
                                        tooltip: 'Open Assignment/Material',
                                      ),
                                    PopupMenuButton<String>(
"""

content = content.replace(icons_to_add, icons_added)


with open('lib/screens/lms_manager_screen.dart', 'w') as f:
    f.write(content)

print("Flutter script complete")
