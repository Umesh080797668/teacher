import re
with open('lib/screens/lms_manager_screen.dart', 'r') as f:
    text = f.read()

found_idx = text.find("Icon(Icons.delete, color: Colors.red, size: 20),")
if found_idx == -1:
    print("Not found")
else:
    chunk = text[found_idx:found_idx+400]
    print("Found chunk:\n===\n" + chunk + "\n===")
