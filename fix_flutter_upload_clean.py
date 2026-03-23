import re

with open('lib/screens/lms_manager_screen.dart', 'r') as f:
    text = f.read()

submit_target = """      if (_isFileUpload) {
        // Simulate file upload progress roughly to match requirement visualization
        for (int i = 1; i <= 10; i++) {
          await Future.delayed(const Duration(milliseconds: 150));
          if (mounted) setState(() => _uploadProgress = i / 10.0);
        }
      }

      // Simulate URL generation for uploaded files to fit model requirement
      String payloadUrl =
          _isFileUpload ? 'uploads/$_selectedFileName' : _urlCtrl.text;

      try {
        final token = await ApiService.getToken();"""

submit_replacement = """      try {
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

            // Simulate progress up to 90% while waiting for network
            bool isWaiting = true;
            Future.doWhile(() async {
              if (!isWaiting) return false;
              if (mounted && _uploadProgress < 0.9) {
                setState(() => _uploadProgress += 0.1);
              }
              await Future.delayed(const Duration(milliseconds: 500));
              return true;
            });

            var streamedResponse = await request.send();
            var response = await http.Response.fromStream(streamedResponse);
            isWaiting = false;

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
        }"""
text = text.replace(submit_target, submit_replacement)

with open('lib/screens/lms_manager_screen.dart', 'w') as f:
    f.write(text)

