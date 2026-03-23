with open('lib/screens/home_screen.dart', 'r') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if line.strip() == ");" and "class _GradientStatCard" in ''.join(lines[i:min(i+10, len(lines))]):
        pass

# Actually I'll just write a hardcoded sed script
