import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/class.dart';
import '../models/student.dart';
import '../providers/students_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/classes_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../screens/student_details_screen.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/notices_tab.dart';
import '../widgets/resources_tab.dart';

class ClassDetailsScreen extends StatefulWidget {
  final Class classObj;

  const ClassDetailsScreen({super.key, required this.classObj});

  @override
  State<ClassDetailsScreen> createState() => _ClassDetailsScreenState();
}

class _ClassDetailsScreenState extends State<ClassDetailsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final studentsProvider = Provider.of<StudentsProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
    try {
      final classStudents = await ApiService.getStudentsByClass(widget.classObj.id);
      if (classStudents.isNotEmpty) {
        studentsProvider.setStudents(classStudents);
      } else {
        await studentsProvider.loadStudents(teacherId: auth.teacherId);
      }
      await attendanceProvider.loadAttendance(teacherId: auth.teacherId);
    } catch (e) {
      // Fallback
      await studentsProvider.loadStudents(teacherId: auth.teacherId);
      await attendanceProvider.loadAttendance(teacherId: auth.teacherId);
    }
  }

  List<Student> _getStudentsInClass() {
    final studentsProvider = Provider.of<StudentsProvider>(context, listen: false);
    final students = studentsProvider.students;
    final studentsWithClassId = students.where((s) => s.classId != null).toList();

    if (studentsWithClassId.isNotEmpty) {
      return studentsWithClassId.where((student) => student.classId == widget.classObj.id).toList();
    } else {
      return students; // Fallback
    }
  }

  double _getAttendanceRate() {
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
    final studentsInClass = _getStudentsInClass();
    if (studentsInClass.isEmpty) return 0.0;
    int totalAttendanceRecords = 0;
    int presentCount = 0;
    for (final student in studentsInClass) {
      final studentAttendance =
          attendanceProvider.attendance.where((record) => record.studentId == student.id).toList();
      totalAttendanceRecords += studentAttendance.length;
      presentCount +=
          studentAttendance.where((record) => record.status.toLowerCase() == 'present').length;
    }
    return totalAttendanceRecords > 0 ? (presentCount / totalAttendanceRecords) * 100 : 0.0;
  }

  Future<void> _sendBulkMessage() async {
    final studentsInClass = _getStudentsInClass();
    if (studentsInClass.isEmpty) return;

    final phoneNumbers = studentsInClass
        .where((s) => s.phoneNumber != null && s.phoneNumber!.isNotEmpty)
        .map((s) => s.phoneNumber!)
        .toList();

    if (phoneNumbers.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students have phone numbers linked.')));
      return;
    }

    final messageController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Message ${phoneNumbers.length} Students'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To: ${studentsInClass.length > 3 ? "${studentsInClass.length} recipients" : studentsInClass.map((e) => e.name).join(", ")}',
              style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message Content',
                border: OutlineInputBorder(),
                hintText: 'Enter announcement...',
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Send WhatsApp'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (messageController.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), SizedBox(width: 15), Text('Sending WhatsApp messages...')]),
                    duration: Duration(seconds: 2),
                  )
                );
                
                try {
                  await ApiService.sendWhatsApp(phoneNumbers, messageController.text.trim());
                  if (mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('WhatsApp messages sent successfully!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to send: ${e.toString().replaceAll("Exception:", "")}'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addStudent() async {
     final nameController = TextEditingController();
     final idController = TextEditingController();
     final emailController = TextEditingController();
     final phoneController = TextEditingController();
     
     // Auto-generate ID
     final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
     final random = (DateTime.now().microsecondsSinceEpoch % 1000).toString().padLeft(3, '0');
     idController.text = 'STU$timestamp$random';

     await showModalBottomSheet(
       context: context,
       isScrollControlled: true,
       backgroundColor: Colors.transparent,
       builder: (sheetCtx) {
         final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
         final cs = Theme.of(sheetCtx).colorScheme;
         return Padding(
           padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
           child: Container(
             decoration: BoxDecoration(
               color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
               borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
               boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, -4))],
             ),
             padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
             child: SingleChildScrollView(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 crossAxisAlignment: CrossAxisAlignment.stretch,
                 children: [
                   Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2)))),
                   Row(
                     children: [
                       Container(
                         width: 46, height: 46,
                         decoration: BoxDecoration(
                           gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                           borderRadius: BorderRadius.circular(13),
                           boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
                         ),
                         child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 22),
                       ),
                       const SizedBox(width: 14),
                       Expanded(
                         child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                           Text('Add Student', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: cs.onSurface)),
                           Text('Fill in the student details', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                         ]),
                       ),
                       IconButton(onPressed: () => Navigator.pop(sheetCtx), icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant)),
                     ],
                   ),
                   const SizedBox(height: 20),
                   TextField(
                     controller: nameController,
                     style: TextStyle(color: cs.onSurface),
                     textCapitalization: TextCapitalization.words,
                     decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_rounded)),
                   ),
                   const SizedBox(height: 14),
                   TextField(
                     controller: emailController,
                     style: TextStyle(color: cs.onSurface),
                     keyboardType: TextInputType.emailAddress,
                     decoration: const InputDecoration(labelText: 'Email (Optional)', prefixIcon: Icon(Icons.email_rounded)),
                   ),
                   const SizedBox(height: 14),
                   TextField(
                     controller: phoneController,
                     style: TextStyle(color: cs.onSurface),
                     keyboardType: TextInputType.phone,
                     decoration: const InputDecoration(labelText: 'Mobile Number', prefixIcon: Icon(Icons.phone_rounded), hintText: '+947...'),
                   ),
                   const SizedBox(height: 14),
                   TextField(
                     controller: idController,
                     style: TextStyle(color: cs.onSurface),
                     enabled: false,
                     decoration: const InputDecoration(labelText: 'Student ID (Auto-generated)', prefixIcon: Icon(Icons.badge_rounded)),
                   ),
                   const SizedBox(height: 24),
                   GestureDetector(
                     onTap: () async {
                       if (nameController.text.isNotEmpty) {
                         final provider = Provider.of<StudentsProvider>(context, listen: false);
                         await provider.addStudent(
                           nameController.text,
                           emailController.text.isEmpty ? null : emailController.text,
                           phoneController.text.isEmpty ? null : phoneController.text,
                           idController.text,
                           widget.classObj.id,
                         );
                         Navigator.pop(sheetCtx);
                         _loadData();
                       }
                     },
                     child: Container(
                       height: 54,
                       decoration: BoxDecoration(
                         gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], begin: Alignment.centerLeft, end: Alignment.centerRight),
                         borderRadius: BorderRadius.circular(16),
                         boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 5))],
                       ),
                       child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                         Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
                         SizedBox(width: 10),
                         Text('Add Student', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                       ])),
                     ),
                   ),
                 ],
               ),
             ),
           ),
         );
       },
     );
  }

  Future<void> _editClass() async {
    final nameController = TextEditingController(text: widget.classObj.name);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        final cs = Theme.of(sheetCtx).colorScheme;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, -4))],
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2)))),
                Row(
                  children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Edit Class', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: cs.onSurface)),
                        Text('Update the class name', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      ]),
                    ),
                    IconButton(onPressed: () => Navigator.pop(sheetCtx), icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  style: TextStyle(color: cs.onSurface),
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Class Name', prefixIcon: Icon(Icons.class_rounded)),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () async {
                    final newName = nameController.text.trim();
                    if (newName.isNotEmpty && newName != widget.classObj.name) {
                      Navigator.pop(sheetCtx);
                      if (mounted) {
                        await Provider.of<ClassesProvider>(context, listen: false).updateClass(widget.classObj.id, newName);
                      }
                    } else {
                      Navigator.pop(sheetCtx);
                    }
                  },
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], begin: Alignment.centerLeft, end: Alignment.centerRight),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 5))],
                    ),
                    child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.save_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    ])),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F0E17) : const Color(0xFFF5F5FA),
        body: SafeArea(
          child: Column(
            children: [
              // ── Gradient Header + TabBar ────────────────────────────
              Consumer2<StudentsProvider, AttendanceProvider>(
                builder: (context, sp, ap, _) {
                  final totalStudents = sp.students
                      .where((s) => s.classId == widget.classObj.id)
                      .length;
                  final rate = _getAttendanceRate();
                  return Container(
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
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 16, 8, 12),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                      Icons.arrow_back_rounded,
                                      color: Colors.white,
                                      size: 20),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.classObj.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Class Overview',
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.75),
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _editClass,
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.edit_rounded,
                                      color: Colors.white, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 0, 20, 14),
                          child: Row(
                            children: [
                              _statPill(
                                  '$totalStudents',
                                  'Students',
                                  Colors.white.withValues(alpha: 0.22)),
                              const SizedBox(width: 8),
                              _statPill(
                                  '${rate.toStringAsFixed(0)}%',
                                  'Attendance',
                                  const Color(0xFF22C55E)
                                      .withValues(alpha: 0.35)),
                            ],
                          ),
                        ),
                        const TabBar(
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white60,
                          indicatorColor: Colors.white,
                          indicatorWeight: 3,
                          dividerColor: Colors.transparent,
                          tabs: [
                            Tab(text: 'Overview'),
                            Tab(text: 'Notices'),
                            Tab(text: 'Resources'),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              // ── Tab Content ───────────────────────────────────
              Expanded(
                child: TabBarView(
                  children: [
                    _buildOverviewTab(),
                    NoticesTab(classId: widget.classObj.id),
                    ResourcesTab(classId: widget.classObj.id),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statPill(String value, String label, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        // ── Action Buttons ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _sendBulkMessage,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF25D366), Color(0xFF128C7E)]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color:
                                const Color(0xFF25D366).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.message_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Message All',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _addStudent,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color:
                                const Color(0xFF4F46E5).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_add_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Add Student',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // ── Search ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
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
                prefixIcon:
                    Icon(Icons.search_rounded, color: cs.onSurfaceVariant),
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
        ),
        // ── Students List ──────────────────────────────────────
        Expanded(
          child: Consumer<StudentsProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return ListSkeleton(
                    itemCount: 5,
                    itemBuilder: (_) => const StudentCardSkeleton());
              }
              final students = _getStudentsInClass()
                  .where((s) =>
                      s.name.toLowerCase().contains(_searchQuery) ||
                      s.studentId.toLowerCase().contains(_searchQuery))
                  .toList();

              if (students.isEmpty) {
                return const Center(
                  child: EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'No students',
                      message: 'Add students to this class'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  return Slidable(
                    endActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      children: [
                        SlidableAction(
                          onPressed: (context) async {
                            await Provider.of<StudentsProvider>(context,
                                    listen: false)
                                .deleteStudent(student.id);
                            _loadData();
                          },
                          backgroundColor: Colors.red,
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
                                    color:
                                        Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3))
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
                              builder: (_) =>
                                  StudentDetailsScreen(student: student)),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF4F46E5),
                                        Color(0xFF7C3AED)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                        color: const Color(0xFF4F46E5)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3))
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
                                      color: Colors.white),
                                )),
                              ),
                              const SizedBox(width: 14),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(student.name,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: cs.onSurface)),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 3),
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
                                                    ? Colors.white.withValues(
                                                        alpha: 0.7)
                                                    : const Color(0xFF4F46E5)),
                                          ),
                                        ),
                                        if (student.phoneNumber != null &&
                                            student.phoneNumber!.isNotEmpty) ...
                                          [
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () async {
                                                String phone = student
                                                    .phoneNumber!
                                                    .replaceAll(
                                                        RegExp(r'[^\d+]'), '');
                                                final uri = Uri.parse(
                                                    'https://wa.me/$phone');
                                                if (await canLaunchUrl(uri)) {
                                                  launchUrl(uri,
                                                      mode: LaunchMode
                                                          .externalApplication);
                                                }
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 3),
                                                decoration: BoxDecoration(
                                                    color: const Color(
                                                            0xFF25D366)
                                                        .withValues(alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6)),
                                                child: const Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                        Icons.message_rounded,
                                                        size: 11,
                                                        color: Color(
                                                            0xFF25D366)),
                                                    SizedBox(width: 3),
                                                    Text('WA',
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Color(
                                                                0xFF25D366))),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
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
    );
  }
}
