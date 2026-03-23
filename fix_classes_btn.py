import re

with open('lib/screens/classes_screen.dart', 'r') as f:
    content = f.read()

pattern_btn = re.compile(
    r'GestureDetector\(\n\s*onTap: _addClass,\n\s*child: Container\(\n\s*height: 54,\n\s*decoration: BoxDecoration\(\n\s*gradient: const LinearGradient\(\n\s*colors: \[\n\s*Color\(0xFF4F46E5\),\n\s*Color\(0xFF7C3AED\)\n\s*\],\n\s*begin: Alignment\.centerLeft,\n\s*end: Alignment\.centerRight,\n\s*\),\n\s*borderRadius: BorderRadius\.circular\(16\),\n\s*boxShadow: \[\n\s*BoxShadow\(\n\s*color: const Color\(0xFF4F46E5\)\n\s*\.withValues\(alpha: 0\.4\),\n\s*blurRadius: 14,\n\s*offset: const Offset\(0, 5\),\n\s*\)\n\s*\],\n\s*\),\n\s*child: const Center\(\n\s*child: Row\(\n\s*mainAxisSize: MainAxisSize\.min,\n\s*children: \[\n\s*Icon\(Icons\.save_rounded,\n\s*color: Colors\.white, size: 20\),\n\s*SizedBox\(width: 10\),\n\s*Text\(\n\s*\'Create Class\',\n\s*style: TextStyle\(\n\s*color: Colors\.white,\n\s*fontWeight: FontWeight\.w700,\n\s*fontSize: 15,\n\s*\),\n\s*\),\n\s*\],\n\s*\),\n\s*\),\n\s*\),\n\s*\)',
    re.DOTALL
)

new_btn = '''InkWell(
                            onTap: isFormValid ? _addClass : null,
                            child: Container(
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: isFormValid ? const LinearGradient(
                                  colors: [
                                    Color(0xFF4F46E5),
                                    Color(0xFF7C3AED)
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ) : null,
                                color: isFormValid ? null : (isDark ? Colors.white12 : Colors.black12),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: isFormValid ? [
                                  BoxShadow(
                                    color: const Color(0xFF4F46E5)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  )
                                ] : [],
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.save_rounded,
                                        color: isFormValid ? Colors.white : Colors.grey, size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Create Class',
                                      style: TextStyle(
                                        color: isFormValid ? Colors.white : Colors.grey,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )'''

content = pattern_btn.sub(new_btn, content)

with open('lib/screens/classes_screen.dart', 'w') as f:
    f.write(content)
