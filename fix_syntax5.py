with open('lib/screens/lms_manager_screen.dart', 'r') as f:
    text = f.read()

import re
# Get the chunk of interest
idx = text.find("Icon(Icons.delete, color: Colors.red, size: 20),")
end_idx = text.find("floatingActionButton", idx)
chunk = text[idx:end_idx]

# Let's print exactly what it is, using python repr
print(repr(chunk))
