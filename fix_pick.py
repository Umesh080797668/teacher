import re

with open('lib/screens/lms_manager_screen.dart', 'r') as f:
    text = f.read()

target = """        setState(() {
          _selectedFileName = result.files.first.name;"""
replacement = """        setState(() {
          _selectedFilePath = result.files.first.path;
          _selectedFileName = result.files.first.name;"""

text = text.replace(target, replacement)

with open('lib/screens/lms_manager_screen.dart', 'w') as f:
    f.write(text)

