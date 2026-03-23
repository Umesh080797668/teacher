with open('lib/screens/lms_manager_screen.dart', 'r') as f:
    text = f.read()

idx_start = text.find("if (_isFileUpload) {")
# search backwards from the `try {` block
idx_start = text.rfind("if (_isFileUpload) {", 0, text.find("try {", idx_start))

# find the next `final isEdit =`
idx_end = text.find("final isEdit =", idx_start)

if idx_start == -1 or idx_end == -1:
    print("Not found")
else:
    chunk = text[idx_start:idx_end]
    print("Found chunk to replace:\n", chunk)

    replacement = """try {
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
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to upload video: ${response.statusCode}')));
                setState(() => _isSubmitting = false);
              }
              return;
            }
          } else {
            payloadUrl = 'uploads/$_selectedFileName'; // Fallback
          }
        }

        """
    
    text = text[:idx_start] + replacement + text[idx_end:]
    with open('lib/screens/lms_manager_screen.dart', 'w') as f:
        f.write(text)
        print("Replaced!")
