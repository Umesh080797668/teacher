import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../providers/students_provider.dart';
import '../providers/classes_provider.dart';
import '../providers/auth_provider.dart';
import 'student_details_screen.dart';
import '../widgets/custom_widgets.dart';
import 'screen_tutorial.dart';
import 'tutorial_keys.dart';
import 'tutorial_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _studentIdController = TextEditingController();
  String? _selectedClassId;

  bool _isExisting = false;
  String _searchQuery = '';
  String _filterType = 'all';
  final TextEditingController _searchController = TextEditingController();

  static const _tutKey = 'tutorial_students_v1';

  List<STStep> get _tutSteps => [
    const STStep(
      targetKey: null,
      shape: STShape.none,
      title: 'Students',
      body: 'Manage all your students here — add new ones, search, filter, and view detailed profiles.',
      icon: Icons.people_rounded,
      accent: Color(0xFF4F46E5),
    ),
    STStep(
      targetKey: tutorialKeyStudSearch,
      title: 'Search Students',
      body: 'Type a name, email or student ID to quickly find anyone in your roster.',
      icon: Icons.search_rounded,
      accent: const Color(0xFF0891B2),
    ),
    STStep(
      targetKey: tutorialKeyStudFilter,
      title: 'Filter by Status',
      body: 'Switch between All, Active and Restricted to focus on the students you need.',
      icon: Icons.filter_list_rounded,
      accent: const Color(0xFF7C3AED),
    ),
    STStep(
      targetKey: tutorialKeyStudList,
      title: 'Student Cards',
      body: 'Tap a card to view full details. Swipe left on a card to restrict access or delete a student.',
      icon: Icons.person_rounded,
      accent: const Color(0xFF059669),
    ),
    STStep(
      targetKey: tutorialKeyStudFab,
      shape: STShape.circle,
      title: 'Add a Student',
      body: 'Tap here to enrol a new student — fill in their name, ID, class and contact info.',
      icon: Icons.person_add_rounded,
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
      _loadStudents();
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _maybeShowTutorial();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _studentIdController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    final studentsProvider = Provider.of<StudentsProvider>(context, listen: false);
    final classesProvider = Provider.of<ClassesProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await studentsProvider.loadStudents(teacherId: auth.teacherId);
      await classesProvider.loadClasses(teacherId: auth.teacherId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addStudent([GlobalKey<FormState>? formKey]) async {
    final key = formKey ?? _formKey;
    if (key.currentState!.validate()) {
      final provider = Provider.of<StudentsProvider>(context, listen: false);
      try {
        await provider.addStudent(
          _nameController.text,
          _emailController.text.isEmpty ? null : _emailController.text,
          _phoneController.text.isEmpty ? null : _phoneController.text,
          _studentIdController.text, // Use the auto-generated ID
          _selectedClassId,
        );
        _nameController.clear();
        _emailController.clear();
        _phoneController.clear();
        _studentIdController.clear();
        setState(() {
          _selectedClassId = null;
        });
        if (mounted) Navigator.of(context).pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Student added successfully'),
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
              content: Text('Failed to add student: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _generateStudentId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    final random = (DateTime.now().microsecondsSinceEpoch % 1000).toString().padLeft(3, '0');
    return 'STU$timestamp$random';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0E17) : const Color(0xFFF5F5FA),
      floatingActionButton: FloatingActionButton.extended(
        key: tutorialKeyStudFab,
        onPressed: () => _showAddStudentSheet(context),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: Text('Add Student',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Pinned Gradient Header ────────────────────────────
            Consumer<StudentsProvider>(
              builder: (context, provider, _) {
                final total = provider.students.length;
                final restricted =
                    provider.students.where((s) => s.isRestricted).length;
                final active = total - restricted;
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
                              'Students',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _loadStudents,
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
                          _statPill('Total', total,
                              Colors.white.withValues(alpha: 0.22)),
                          const SizedBox(width: 8),
                          _statPill('Active', active,
                              const Color(0xFF22C55E).withValues(alpha: 0.35)),
                          const SizedBox(width: 8),
                          _statPill('Restricted', restricted,
                              Colors.red.withValues(alpha: 0.35)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            // ── Search + Filter Chips ─────────────────────────────
            Container(
              color: isDark
                  ? const Color(0xFF0F0E17)
                  : const Color(0xFFF5F5FA),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    key: tutorialKeyStudSearch,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3))
                            ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) =>
                          setState(() => _searchQuery = v.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search students...',
                        prefixIcon: Icon(Icons.search_rounded,
                            color: cs.onSurfaceVariant),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded,
                                    color: cs.onSurfaceVariant),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    key: tutorialKeyStudFilter,
                    children: [
                      _filterChip(context, 'All', 'all', isDark),
                      const SizedBox(width: 8),
                      _filterChip(context, 'Active', 'active', isDark),
                      const SizedBox(width: 8),
                      _filterChip(
                          context, 'Restricted', 'restricted', isDark),
                    ],
                  ),
                ],
              ),
            ),

            // ── Students List ─────────────────────────────────────
            Expanded(
              key: tutorialKeyStudList,
              child: Consumer<StudentsProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return ListSkeleton(
                      itemCount: 6,
                      itemBuilder: (_) => const StudentCardSkeleton(),
                    );
                  }

                  final filtered = provider.students.where((s) {
                    final matchesSearch = _searchQuery.isEmpty ||
                        s.name
                            .toLowerCase()
                            .contains(_searchQuery) ||
                        (s.email?.toLowerCase().contains(_searchQuery) ??
                            false) ||
                        s.studentId.toLowerCase().contains(_searchQuery);
                    final matchesFilter = _filterType == 'all' ||
                        (_filterType == 'active' && !s.isRestricted) ||
                        (_filterType == 'restricted' && s.isRestricted);
                    return matchesSearch && matchesFilter;
                  }).toList();

                  if (filtered.isEmpty) {
                    return EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: _searchQuery.isEmpty
                          ? 'No Students Yet'
                          : 'No Results',
                      message: _searchQuery.isEmpty
                          ? 'Tap + Add Student to get started'
                          : 'Try a different search term',
                      action: _searchQuery.isEmpty
                          ? FilledButton.icon(
                              onPressed: () => _showAddStudentSheet(context),
                              icon: const Icon(Icons.person_add_rounded),
                              label: const Text('Add Student'),
                            )
                          : null,
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final student = filtered[index];
                      return Slidable(
                        endActionPane: ActionPane(
                          motion: const ScrollMotion(),
                          children: [
                            SlidableAction(
                              onPressed: (ctx) async {
                                final isRestricted = student.isRestricted;
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: Text(
                                        isRestricted
                                            ? 'Unrestrict Student'
                                            : 'Restrict Student',
                                        style:
                                            TextStyle(color: cs.onSurface)),
                                    content: Text(
                                        'Are you sure you want to ${isRestricted ? 'unrestrict' : 'restrict'} ${student.name}?',
                                        style:
                                            TextStyle(color: cs.onSurface)),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel')),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: isRestricted
                                            ? FilledButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF22C55E))
                                            : FilledButton.styleFrom(
                                                backgroundColor:
                                                    Colors.orange),
                                        child: Text(isRestricted
                                            ? 'Unrestrict'
                                            : 'Restrict'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true && ctx.mounted) {
                                  try {
                                    final p = Provider.of<StudentsProvider>(
                                        context,
                                        listen: false);
                                    isRestricted
                                        ? await p.unrestrictStudent(student.id)
                                        : await p.restrictStudent(student.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content: Text(
                                            'Student ${isRestricted ? 'unrestricted' : 'restricted'} successfully'),
                                        backgroundColor: isRestricted
                                            ? const Color(0xFF22C55E)
                                            : Colors.orange,
                                      ));
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content: Text('Failed: $e'),
                                        backgroundColor: cs.error,
                                      ));
                                    }
                                  }
                                }
                              },
                              backgroundColor: student.isRestricted
                                  ? const Color(0xFF22C55E)
                                  : Colors.orange,
                              foregroundColor: Colors.white,
                              icon: student.isRestricted
                                  ? Icons.lock_open_rounded
                                  : Icons.lock_rounded,
                              label: student.isRestricted
                                  ? 'Unrestrict'
                                  : 'Restrict',
                              borderRadius: BorderRadius.circular(12),
                            ),
                            SlidableAction(
                              onPressed: (ctx) async {
                                final sm = ScaffoldMessenger.of(context);
                                final nav = Navigator.of(context);
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: Text('Delete Student',
                                        style: TextStyle(
                                            color: cs.onSurface)),
                                    content: Text(
                                        'Delete ${student.name}? This action cannot be undone.',
                                        style: TextStyle(
                                            color: cs.onSurface)),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel')),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: FilledButton.styleFrom(
                                            backgroundColor: cs.error),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (_) => AlertDialog(
                                      content: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const CircularProgressIndicator(),
                                          const SizedBox(width: 16),
                                          Text('Deleting...',
                                              style: TextStyle(
                                                  color: cs.onSurface)),
                                        ],
                                      ),
                                    ),
                                  );
                                  try {
                                    await Provider.of<StudentsProvider>(
                                            context,
                                            listen: false)
                                        .deleteStudent(student.id);
                                    nav.pop();
                                    sm.showSnackBar(const SnackBar(
                                      content: Row(children: [
                                        Icon(Icons.check_circle,
                                            color: Colors.white),
                                        SizedBox(width: 8),
                                        Text('Student deleted'),
                                      ]),
                                      backgroundColor: Color(0xFF22C55E),
                                    ));
                                  } catch (e) {
                                    nav.pop();
                                    sm.showSnackBar(SnackBar(
                                      content: Text('Failed: $e'),
                                      backgroundColor: cs.error,
                                    ));
                                  }
                                }
                              },
                              backgroundColor: cs.error,
                              foregroundColor: Colors.white,
                              icon: Icons.delete_rounded,
                              label: 'Delete',
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ],
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1B2E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: isDark
                                ? []
                                : [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.06),
                                      blurRadius: 12,
                                      offset: const Offset(0, 3),
                                    )
                                  ],
                            border: isDark
                                ? Border.all(
                                    color: Colors.white.withValues(alpha: 0.06))
                                : null,
                          ),
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentDetailsScreen(
                                    student: student),
                              ),
                            ),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: student.isRestricted
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFFEF4444),
                                                Color(0xFFB91C1C)
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : const LinearGradient(
                                              colors: [
                                                Color(0xFF4F46E5),
                                                Color(0xFF7C3AED)
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (student.isRestricted
                                                  ? const Color(0xFFEF4444)
                                                  : const Color(0xFF4F46E5))
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        )
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        student.name.isNotEmpty
                                            ? student.name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          student.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: cs.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            // ID chip
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.white
                                                        .withValues(alpha: 0.1)
                                                    : const Color(0xFF4F46E5)
                                                        .withValues(alpha: 0.08),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                student.studentId,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark
                                                      ? Colors.white
                                                          .withValues(
                                                              alpha: 0.7)
                                                      : const Color(0xFF4F46E5),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            // Class chip
                                            Consumer<ClassesProvider>(
                                              builder: (_, cp, __) {
                                                final cls = cp.classes
                                                    .where((c) =>
                                                        c.id ==
                                                        student.classId);
                                                if (cls.isEmpty) {
                                                  return const SizedBox
                                                      .shrink();
                                                }
                                                return Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 7,
                                                          vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                            0xFF10B981)
                                                        .withValues(alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    cls.first.name,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Color(0xFF10B981),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Right: status indicator
                                  if (student.isRestricted)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: cs.error.withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                            color: cs.error
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.lock_rounded,
                                              size: 11, color: cs.error),
                                          const SizedBox(width: 3),
                                          Text('Locked',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: cs.error,
                                                  fontWeight:
                                                      FontWeight.w600)),
                                        ],
                                      ),
                                    )
                                  else
                                    Icon(Icons.chevron_right_rounded,
                                        color: cs.onSurfaceVariant),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Sheet Form ──────────────────────────────────────────────────────
  void _showAddStudentSheet(BuildContext context) {
    final sheetFormKey = GlobalKey<FormState>();
    _studentIdController.text = _generateStudentId();
    setState(() => _isExisting = false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final cs = Theme.of(ctx).colorScheme;
              bool isFormValid = _isExisting 
                  ? _studentIdController.text.trim().isNotEmpty
                  : _nameController.text.trim().isNotEmpty;
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: DraggableScrollableSheet(
                initialChildSize: 0.85,
                minChildSize: 0.5,
                maxChildSize: 0.96,
                expand: false,
                builder: (_, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color:
                          isDark ? const Color(0xFF1E1B2E) : Colors.white,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 30,
                            offset: const Offset(0, -4))
                      ],
                    ),
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
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
                        // Header row
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
                              child: const Icon(Icons.person_add_rounded,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Add Student',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 18,
                                          color: cs.onSurface)),
                                  Text('Fill in the student details',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: Icon(Icons.close_rounded,
                                  color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Toggle: New vs Existing
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : const Color(0xFFF1F0FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setSheetState(() {
                                    _isExisting = false;
                                    _studentIdController.text =
                                        _generateStudentId();
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 11),
                                    decoration: BoxDecoration(
                                      gradient: !_isExisting
                                          ? const LinearGradient(colors: [
                                              Color(0xFF4F46E5),
                                              Color(0xFF7C3AED)
                                            ])
                                          : null,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'New Student',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: !_isExisting
                                              ? Colors.white
                                              : cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setSheetState(() {
                                    _isExisting = true;
                                    _studentIdController.clear();
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 11),
                                    decoration: BoxDecoration(
                                      gradient: _isExisting
                                          ? const LinearGradient(colors: [
                                              Color(0xFF4F46E5),
                                              Color(0xFF7C3AED)
                                            ])
                                          : null,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Link Existing',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: _isExisting
                                              ? Colors.white
                                              : cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Form
                        Form(
                          key: sheetFormKey,
                          child: Column(
                            children: [
                              if (!_isExisting) ...[
                                TextFormField(
                                  controller: _nameController,
                                    onChanged: (_) => setSheetState((){}),
                                  style: TextStyle(color: cs.onSurface),
                                  decoration: const InputDecoration(
                                    labelText: 'Full Name',
                                    prefixIcon:
                                        Icon(Icons.person_rounded),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.isEmpty)
                                          ? 'Please enter a name'
                                          : null,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _emailController,
                                  style: TextStyle(color: cs.onSurface),
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email (optional)',
                                    prefixIcon: Icon(Icons.email_rounded),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _phoneController,
                                  style: TextStyle(color: cs.onSurface),
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'Mobile Number',
                                    prefixIcon: Icon(Icons.phone_rounded),
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                              TextFormField(
                                controller: _studentIdController,
                                style: TextStyle(color: cs.onSurface),
                                enabled: _isExisting,
                                  onChanged: (_) => setSheetState((){}),
                                validator: (v) => (_isExisting &&
                                        (v == null || v.isEmpty))
                                    ? 'Please enter Student ID'
                                    : null,
                                decoration: InputDecoration(
                                  labelText: _isExisting
                                      ? 'Existing Student ID'
                                      : 'Student ID (Auto-generated)',
                                  prefixIcon:
                                      const Icon(Icons.badge_rounded),
                                  helperText: _isExisting
                                      ? 'Enter the ID of the student to link'
                                      : 'Auto-generated',
                                ),
                              ),
                              const SizedBox(height: 14),
                              Consumer<ClassesProvider>(
                                builder: (ctx2, cp, _) =>
                                    DropdownButtonFormField<String>(
                                  initialValue: _selectedClassId,
                                  style: TextStyle(color: cs.onSurface),
                                  dropdownColor: isDark
                                      ? cs.surfaceContainerHigh
                                      : cs.surface,
                                  decoration: const InputDecoration(
                                    labelText: 'Class (optional)',
                                    prefixIcon:
                                        Icon(Icons.class_rounded),
                                  ),
                                  items: [
                                    DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('No class assigned',
                                          style: TextStyle(
                                              color: cs.onSurface)),
                                    ),
                                    ...cp.classes.map((c) =>
                                        DropdownMenuItem<String>(
                                          value: c.id,
                                          child: Text(c.name,
                                              style: TextStyle(
                                                  color: cs.onSurface)),
                                        )),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _selectedClassId = v),
                                ),
                              ),
                              const SizedBox(height: 24),
                              GestureDetector(
                                onTap: isFormValid ? () => _addStudent(sheetFormKey) : null,
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
                                    color: isFormValid ? null : (isDark ? Colors.grey[800] : Colors.grey[300]),
                                    borderRadius:
                                        BorderRadius.circular(16),
                                    boxShadow: isFormValid ? [
                                      BoxShadow(
                                        color: const Color(0xFF4F46E5)
                                            .withValues(alpha: 0.4),
                                        blurRadius: 14,
                                        offset: const Offset(0, 5),
                                      )
                                    ] : null,
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.save_rounded,
                                            color: isFormValid ? Colors.white : (isDark ? Colors.white30 : Colors.black26), size: 20),
                                        const SizedBox(width: 10),
                                        Text('Save Student',
                                            style: TextStyle(
                                              color: isFormValid ? Colors.white : (isDark ? Colors.white30 : Colors.black26),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                            )),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _statPill(String label, int value, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style:
                TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
      BuildContext context, String label, String type, bool isDark) {
    final isSelected = _filterType == type;
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)])
              : null,
          color: isSelected
              ? null
              : isDark
                  ? const Color(0xFF1E1B2E)
                  : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ]
              : [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0 : 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
