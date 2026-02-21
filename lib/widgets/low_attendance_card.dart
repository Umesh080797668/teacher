import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../models/student.dart';
import 'package:provider/provider.dart';

class LowAttendanceCard extends StatefulWidget {
  final String classId;

  const LowAttendanceCard({super.key, required this.classId});

  @override
  State<LowAttendanceCard> createState() => _LowAttendanceCardState();
}

class _LowAttendanceCardState extends State<LowAttendanceCard> {
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await ApiService.getLowAttendance(widget.classId);
      if (mounted) {
        setState(() {
          _students = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();
    if (_students.isEmpty) return const SizedBox.shrink();

    return Card(
      color: Colors.red[50], // Alert color
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.warning, color: Colors.red),
        title: Text(
          'Action Needed: Low Attendance (${_students.length})',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        subtitle: const Text('Students with 3+ consecutive absences'),
        children: _students.map((data) {
          final student = Student.fromJson(data['student']);
          final absences = data['consecutiveAbsences'];
          return ListTile(
            title: Text(student.name),
            subtitle: Text('$absences consecutive absences'),
            trailing: IconButton(
              icon: const Icon(Icons.message, color: Colors.green),
              onPressed: () async {
                if (student.phoneNumber == null) return;
                
                final phone = student.phoneNumber!.replaceAll(RegExp(r'\D'), '');
                final uri = Uri.parse('https://wa.me/$phone');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  // Fallback to SMS
                  if (await canLaunchUrl(Uri.parse('sms:${student.phoneNumber}'))) {
                     await launchUrl(Uri.parse('sms:${student.phoneNumber}'));
                  }
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
