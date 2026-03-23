import re

with open('lib/screens/lms_manager_screen.dart', 'r') as f:
    text = f.read()

# 1. Add Mediviewer export
if "import 'package:flutter/material.dart';" in text and "import 'media_viewer_screen.dart';" not in text:
    text = text.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'media_viewer_screen.dart';")

if "import 'package:file_picker/file_picker.dart';" in text and "import 'package:http/http.dart' as http;" not in text:
    text = text.replace("import 'package:file_picker/file_picker.dart';", "import 'package:file_picker/file_picker.dart';\nimport 'package:http/http.dart' as http;")

# 2. Add _selectedFilePath to _AddMaterialSheetState
if "String? _selectedFileName;" in text and "String? _selectedFilePath;" not in text:
    text = text.replace("String? _selectedFileName;", "String? _selectedFileName;\n  String? _selectedFilePath;")

# 3. Modify _pickFile to set _selectedFilePath
pickfile_target = """        setState(() {
          _selectedFileName = result.files.first.name;"""
pickfile_replacement = """        setState(() {
          _selectedFilePath = result.files.first.path;
          _selectedFileName = result.files.first.name;"""
text = text.replace(pickfile_target, pickfile_replacement)

# 4. Modify _openVideo
openvideo_target = """    // Simple verification if it's a valid url
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error opening link: $e')));
      }
    }"""

openvideo_replacement = """    // Simple verification if it's a valid url
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
    }"""
text = text.replace(openvideo_target, openvideo_replacement)

with open('lib/screens/lms_manager_screen.dart', 'w') as f:
    f.write(text)

