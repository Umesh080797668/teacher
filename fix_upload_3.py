with open('lib/screens/lms_manager_screen.dart', 'r') as f:
    lines = f.readlines()

new_lines = []
skip = False

for i, line in enumerate(lines):
    # Just to be safe with line numbers if other features drifted
    # the range we want to replace is 542 to 552
    # we know lines[541] is "    if (_isFileUpload) {\n"
    # lines[536] (approx) is "    setState(() {\n"
    pass

