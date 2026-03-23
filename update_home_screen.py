import re

with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

# Wrap the root widget in a GestureDetector to dismiss the FAB when tapping outside
pattern_scaffold = re.compile(r'(return\s+Scaffold\()', re.DOTALL)
new_scaffold = r'''return GestureDetector(
      onTap: () {
        if (_fabExpanded) {
          setState(() => _fabExpanded = false);
        }
      },
      child: Scaffold('''

content_scaffold = pattern_scaffold.sub(new_scaffold, content, count=1)

with open('lib/screens/home_screen.dart', 'w') as f:
    f.write(content_scaffold)
