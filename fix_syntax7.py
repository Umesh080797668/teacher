with open('lib/screens/lms_manager_screen.dart', 'r') as f:
    text = f.read()

idx = text.find("Text('Delete'),")
end_idx = text.find("floatingActionButton", idx)
chunk = text[idx:end_idx]

new_chunk = """Text('Delete'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      """

text = text[:idx] + new_chunk + text[end_idx:]

with open('lib/screens/lms_manager_screen.dart', 'w') as f:
    f.write(text)

