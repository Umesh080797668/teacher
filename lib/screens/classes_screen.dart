import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/classes_provider.dart';
import '../providers/auth_provider.dart';
import 'class_details_screen.dart';
import '../widgets/custom_widgets.dart';
import 'screen_tutorial.dart';
import 'tutorial_keys.dart';
import 'tutorial_screen.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  static const _tutKey = 'tutorial_classes_v1';

  List<STStep> get _tutSteps => [
    const STStep(
      targetKey: null,
      shape: STShape.none,
      title: 'Your Classes',
      body: 'Here you manage all your classes. Each card represents one class with its students.',
      icon: Icons.class_rounded,
      accent: Color(0xFF4F46E5),
    ),
    STStep(
      targetKey: tutorialKeyClassGrid,
      title: 'Class Cards',
      body: 'Tap a card to open its details — see students, attendance history, and payment records. Long-press to delete.',
      icon: Icons.grid_view_rounded,
      accent: const Color(0xFF7C3AED),
    ),
    STStep(
      targetKey: tutorialKeyClassFab,
      shape: STShape.circle,
      title: 'Create a Class',
      body: 'Tap here to add a new class. Give it a name — e.g. "Grade 10 Science" or "Piano Batch A".',
      icon: Icons.add_circle_rounded,
      accent: const Color(0xFFDB2777),
    ),
  ];

  Future<void> _maybeShowTutorial() async {
    if (TutorialScreen.isRunning) return; // main tutorial is active
    final done = await isSTDone(_tutKey);
    if (!done && mounted) {
      showSTTutorial(
        context: context,
        steps: _tutSteps,
        prefKey: _tutKey,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClasses();
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _maybeShowTutorial();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    final provider = Provider.of<ClassesProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await provider.loadClasses(teacherId: auth.teacherId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load classes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addClass() async {
    if (_formKey.currentState!.validate()) {
      final provider = Provider.of<ClassesProvider>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      try {
        final teacherId = auth.teacherId;
        if (teacherId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Teacher ID not found. Please login again.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        await provider.addClass(_nameController.text, teacherId);
        _nameController.clear();
        if (mounted) Navigator.of(context).pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Class added successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add class: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteClass(String classId) async {
    final provider = Provider.of<ClassesProvider>(context, listen: false);
    try {
      await provider.deleteClass(classId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.delete, color: Colors.white),
                SizedBox(width: 12),
                Text('Class deleted successfully'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete class: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddClassSheet(BuildContext context) {
    _nameController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(sheetCtx).brightness == Brightness.dark
                  ? const Color(0xFF1E1B2E)
                  : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 30,
                    offset: const Offset(0, -4))
              ],
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Builder(builder: (ctx) {
              final cs = Theme.of(ctx).colorScheme;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF4F46E5),
                              Color(0xFF7C3AED)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFF4F46E5)
                                    .withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: const Icon(Icons.class_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create New Class',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: cs.onSurface,
                              ),
                            ),
                            Text(
                              'Give your class a descriptive name',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        icon: Icon(Icons.close_rounded,
                            color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          style: TextStyle(color: cs.onSurface),
                          autofocus: true,
                          textCapitalization:
                              TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Class Name',
                            hintText: 'e.g. Grade 10 - Section A',
                            labelStyle: TextStyle(
                                color: cs.onSurfaceVariant),
                            prefixIcon:
                                const Icon(Icons.class_rounded),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Please enter a class name'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: _addClass,
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF4F46E5),
                                  Color(0xFF7C3AED)
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4F46E5)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                )
                              ],
                            ),
                            child: const Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.save_rounded,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 10),
                                  Text(
                                    'Create Class',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0E17) : const Color(0xFFF5F5FA),
      floatingActionButton: FloatingActionButton.extended(
        key: tutorialKeyClassFab,
        onPressed: () => _showAddClassSheet(context),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('New Class',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Pinned Gradient Header ──────────────────────────────
            Consumer<ClassesProvider>(
              builder: (context, provider, _) {
                final count = provider.classes.length;
                return Container(
                  padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 8, 20),
                  decoration: BoxDecoration(
                    gradient: isDark
                        ? const LinearGradient(
                            colors: [Color(0xFF1E1A2E), Color(0xFF2D2660)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : const LinearGradient(
                            colors: [
                              Color(0xFF3730A3),
                              Color(0xFF4F46E5),
                              Color(0xFF7C3AED)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.arrow_back_rounded,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Classes',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _loadClasses,
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.refresh_rounded,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$count',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  count == 1 ? 'Class' : 'Classes',
                                  style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.85),
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E)
                                  .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$count',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Active',
                                  style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.85),
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            // ── Grid of Classes ─────────────────────────────────────
            Expanded(
              child: SizedBox.expand(
                key: tutorialKeyClassGrid,
                child: Consumer<ClassesProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading) {
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: 4,
                        itemBuilder: (_, __) => const ClassCardSkeleton(),
                      );
                    }

                    if (provider.classes.isEmpty) {
                      return EmptyState(
                        icon: Icons.class_outlined,
                        title: 'No Classes Yet',
                        message: 'Tap + New Class to create your first class',
                        action: FilledButton.icon(
                          onPressed: () => _showAddClassSheet(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('New Class'),
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: provider.classes.length,
                      itemBuilder: (context, index) {
                        final classObj = provider.classes[index];
                        return _ClassGridCard(
                          classObj: classObj,
                          isDark: isDark,
                          cs: cs,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ClassDetailsScreen(classObj: classObj),
                            ),
                          ),
                          onDelete: () => showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text('Delete Class',
                                  style: TextStyle(color: cs.onSurface)),
                              content: Text(
                                  'Delete "${classObj.name}"? This cannot be undone.',
                                  style: TextStyle(color: cs.onSurface)),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel')),
                                FilledButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _deleteClass(classObj.id);
                                  },
                                  style: FilledButton.styleFrom(
                                      backgroundColor: cs.error),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Class Grid Card ───────────────────────────────────────────────────────────
class _ClassGridCard extends StatelessWidget {
  final dynamic classObj;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ClassGridCard({
    required this.classObj,
    required this.isDark,
    required this.cs,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
          border: isDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.07))
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            onLongPress: onDelete,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon container
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF4F46E5).withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: const Icon(Icons.class_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const Spacer(),
                  // Class name
                  Text(
                    classObj.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: cs.onSurface,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Footer: students + arrow
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : const Color(0xFF4F46E5).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_rounded,
                                size: 11,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : const Color(0xFF4F46E5)),
                            const SizedBox(width: 4),
                            Text(
                              'View',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : const Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
