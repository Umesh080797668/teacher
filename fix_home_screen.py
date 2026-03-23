import re

with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

# Replace ending
content = re.sub(
    r'        \),\n      \);\n    }\n  }\n\n\nclass _GradientStatCard',
    r'        ),\n      ),\n    );\n  }\n}\n\nclass _GradientStatCard',
    content
)

with open('lib/screens/home_screen.dart', 'w') as f:
    f.write(content)
