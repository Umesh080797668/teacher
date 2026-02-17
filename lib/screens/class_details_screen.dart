import 'package:flutter/material.dart';
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
            Text('To: ${studentsInClass.length > 3 ? "${studentsInClass.length} recipients" : studentsInClass.map((e) => e.name).join(", ")}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
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
          ElevatedButton.icon(
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Send SMS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (messageController.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), SizedBox(width: 15), Text('Sending messages...')]),
                    duration: Duration(seconds: 2),
                  )
                );
                
                try {
                  await ApiService.sendSMS(phoneNumbers, messageController.text.trim());
                  if (mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Messages sent successfully!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to send: ${e.toString().replaceAll("Exception:", "")}'), backgroundColor: Colors.red),
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
     
     // Auto-generate ID (optional fallback)
     final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
     final random = (DateTime.now().microsecondsSinceEpoch % 1000).toString().padLeft(3, '0');
     idController.text = 'STU$timestamp$random';

     await showDialog(
       context: context, 
       builder: (ctx) => AlertDialog(
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
         title: const Text('Add Student', style: TextStyle(fontWeight: FontWeight.bold)),
         content: SingleChildScrollView(
           child: Column(
             mainAxisSize: MainAxisSize.min, 
             children: [
               TextField(
                 controller: nameController, 
                 decoration: const InputDecoration(
                   labelText: 'Full Name',
                   prefixIcon: Icon(Icons.person),
                   border: OutlineInputBorder(),
                   contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                 ),
                 textCapitalization: TextCapitalization.words,
               ),
               const SizedBox(height: 16),
               TextField(
                 controller: idController, 
                 decoration: const InputDecoration(
                   labelText: 'Student ID',
                   prefixIcon: Icon(Icons.badge),
                   border: OutlineInputBorder(),
                   contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                 ),
                 enabled: false,
               ),
               const SizedBox(height: 16),
               TextField(
                 controller: emailController, 
                 decoration: const InputDecoration(
                   labelText: 'Email (Optional)',
                   prefixIcon: Icon(Icons.email),
                   border: OutlineInputBorder(),
                   contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                 ),
                 keyboardType: TextInputType.emailAddress,
               ),
               const SizedBox(height: 16),
               TextField(
                 controller: phoneController, 
                 decoration: const InputDecoration(
                   labelText: 'Mobile Number',
                   prefixIcon: Icon(Icons.phone),
                   border: OutlineInputBorder(),
                   contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                   hintText: '+947...'
                 ),
                 keyboardType: TextInputType.phone,
               ),
             ]
           ),
         ),
         actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
         actions: [
           TextButton(
             onPressed: () => Navigator.pop(ctx), 
             child: const Text('Cancel', style: TextStyle(color: Colors.grey))
           ),
           ElevatedButton(
             style: ElevatedButton.styleFrom(
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
               backgroundColor: Theme.of(context).primaryColor,
               foregroundColor: Colors.white,
             ),
             onPressed: () async {
               if (nameController.text.isNotEmpty) {
                 final provider = Provider.of<StudentsProvider>(context, listen: false);
                 await provider.addStudent(
                   nameController.text, 
                   emailController.text.isEmpty ? null : emailController.text, // Updated to pass email
                   phoneController.text.isEmpty ? null : phoneController.text,
                   idController.text, 
                   widget.classObj.id,
                 );
                 Navigator.pop(ctx);
                 _loadData();
               }
             }, 
             child: const Text('Add Student')
           ),
         ],
       )
     );
  }

  Future<void> _editClass() async {
    final nameController = TextEditingController(text: widget.classObj.name);
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Edit Class'),
      content: TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, nameController.text), child: const Text('Save')),
      ],
    ));
    if (result != null && result != widget.classObj.name && mounted) {
       await Provider.of<ClassesProvider>(context, listen: false).updateClass(widget.classObj.id, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.classObj.name),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
              Tab(text: 'Notices', icon: Icon(Icons.campaign)),
              Tab(text: 'Resources', icon: Icon(Icons.folder_shared)),
            ],
          ),
          actions: [
             IconButton(icon: const Icon(Icons.edit), onPressed: _editClass),
          ],
        ),
        body: TabBarView(
          children: [
            _buildOverviewTab(),
            NoticesTab(classId: widget.classObj.id),
            ResourcesTab(classId: widget.classObj.id),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
               Expanded(
                 child: ElevatedButton.icon(
                  onPressed: _sendBulkMessage,
                  icon: const Icon(Icons.message, size: 18),
                  label: const Text('Message All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, 
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                             ),
               ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _addStudent,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Add Student'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Stats
        Consumer2<StudentsProvider, AttendanceProvider>(
          builder: (context, studentsProvider, attendanceProvider, child) {
             final studentsInClass = _getStudentsInClass();
             final rate = _getAttendanceRate();
             return Container(
               margin: const EdgeInsets.symmetric(horizontal: 16),
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(
                 color: Colors.blue[50], 
                 borderRadius: BorderRadius.circular(12)
               ),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceAround,
                 children: [
                   Column(children: [
                     const Icon(Icons.people, color: Colors.blue),
                     const SizedBox(height: 4),
                     Text('${studentsInClass.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), 
                     const Text('Students')
                   ]),
                   Column(children: [
                     const Icon(Icons.check_circle, color: Colors.green),
                     const SizedBox(height: 4),
                     Text('${rate.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), 
                     const Text('Rate')
                   ]),
                 ],
               ),
             );
          },
        ),
        // Search
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search students...', 
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10)
            ),
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: Consumer<StudentsProvider>(
            builder: (context, provider, child) {
              final students = _getStudentsInClass().where((s) => 
                s.name.toLowerCase().contains(_searchQuery) || s.studentId.toLowerCase().contains(_searchQuery)
              ).toList();
              
              if (students.isEmpty) return const Center(child: Text('No students found'));

              return ListView.builder(
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  return Slidable(
                    endActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      children: [
                        SlidableAction(
                          onPressed: (context) async {
                             // Delete logic
                             await Provider.of<StudentsProvider>(context, listen: false).deleteStudent(student.id);
                             _loadData(); // refresh
                          },
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          icon: Icons.delete,
                          label: 'Delete',
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: CircleAvatar(child: Text(student.name.isNotEmpty ? student.name[0] : '?')),
                      title: Text(student.name),
                      subtitle: Text(student.studentId),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (student.phoneNumber != null)
                             IconButton(
                               icon: const Icon(Icons.message, size: 20, color: Colors.blue),
                               onPressed: () async {
                                 final uri = Uri.parse('sms:${student.phoneNumber}');
                                 if (await canLaunchUrl(uri)) launchUrl(uri);
                               },
                             ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => StudentDetailsScreen(student: student)));
                      },
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
