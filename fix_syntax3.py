import re
with open('lib/screens/lms_manager_screen.dart', 'r') as f:
    text = f.read()

target = """                        ],
                      ),
                    ),
                  );
                },
              ),                        ),"""

replacement = """                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),                        ),"""

if target in text:
    print("Found target")
    text = text.replace(target, replacement)
    with open('lib/screens/lms_manager_screen.dart', 'w') as f:
        f.write(text)
else:
    print("Target not found")
