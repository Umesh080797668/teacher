import re

with open('lib/screens/lms_manager_screen.dart', 'r') as f:
    text = f.read()

# 1. Remove unused import
text = text.replace("import 'package:url_launcher/url_launcher.dart';\n", "")

# 2. Add form fields
target = """
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: (!"""

replacement = """
              const SizedBox(height: 16),
              
              // New Meta Fields
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  title: Text(
                    'Allow Students to Download',
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  ),
                  value: _allowDownload,
                  onChanged: (val) => setState(() => _allowDownload = val),
                  activeColor: const Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(height: 16),

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

              TextField(
                controller: _relatedMaterialUrlCtrl,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Related Assignment URL (Optional)',
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
              ElevatedButton(
                onPressed: (!"""

text = text.replace(target, replacement)

with open('lib/screens/lms_manager_screen.dart', 'w') as f:
    f.write(text)

