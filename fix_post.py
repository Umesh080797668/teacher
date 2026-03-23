import re
with open('lib/screens/lms_manager_screen.dart', 'r') as f:
    text = f.read()

text = text.replace(
"""                'teacherId': auth.teacherId,
                'duration': 120,
              }));""",
"""                'teacherId': auth.teacherId,
                'allowDownload': _allowDownload,
                'relatedQuizUrl': _relatedQuizUrlCtrl.text,
                'relatedMaterialUrl': _relatedMaterialUrlCtrl.text,
                'duration': 120,
              }));""")

with open('lib/screens/lms_manager_screen.dart', 'w') as f:
    f.write(text)
