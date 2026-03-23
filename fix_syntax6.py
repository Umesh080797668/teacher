with open('lib/screens/lms_manager_screen.dart', 'r') as f:
    text = f.read()

target = """                                          Text('Delete'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),"""

replacement = """                                          Text('Delete'),
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
            ),"""

print(text.find(target))

