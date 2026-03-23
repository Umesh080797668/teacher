with open('lib/screens/lms_manager_screen.dart', 'r') as f:
    text = f.read()

import re

# We know the bug is right after "Icon(Icons.delete... Text('Delete'), ], ), )," and then "], )," for PopupMenu...
# Let's just find the index and manipulate it cleanly.

idx = text.find("Icon(Icons.delete, color: Colors.red, size: 20),")
end_idx = text.find("floatingActionButton", idx)

chunk = text[idx:end_idx]

# In this chunk, we have a missing "], )," for the Row that wraps the PopupMenuButton.
# The end of PopupMenuButton is "], )"
# So the part that is currently:
#                         ],
#                       ),
#                     ),
#                   );
#                 },
# needs to be:
#                         ],
#                       ),
#                     ],
#                   ),
#                 ),
#               );
#             },

new_chunk = chunk.replace("""
                        ],
                      ),
                    ),
                  );
                },""", """
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },""")

# If exact replace failed, let's do a more robust one
if new_chunk == chunk:
    print("Replace failed using exact space, using regex")
    new_chunk = re.sub(r'(\s+)\]\,\s*\n(\s*)\)\,\s*\n(\s*)\)\,\s*\n(\s*)\)\;\s*\n(\s*)\}\;', 
                       r'\1],\n\2),\n\2],\n\3),\n\4),\n\5);\n\5},', chunk)

text = text[:idx] + new_chunk + text[end_idx:]

with open('lib/screens/lms_manager_screen.dart', 'w') as f:
    f.write(text)

