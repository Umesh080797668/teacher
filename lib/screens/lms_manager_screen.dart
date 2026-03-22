import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class LmsManagerScreen extends StatefulWidget {
  const LmsManagerScreen({Key? key}) : super(key: key);

  @override
  State<LmsManagerScreen> createState() => _LmsManagerScreenState();
}

class _LmsManagerScreenState extends State<LmsManagerScreen> {
  bool _isLoading = false;
  List<dynamic> _videos = [];

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.teacherId == null) return;
      final res = await http.get(Uri.parse('${ApiService.baseUrl}/api/lms/videos/teacher/${auth.teacherId}'));
      if (res.statusCode == 200) {
        setState(() {
          _videos = jsonDecode(res.body);
        });
      }
    } catch (e) {
      debugPrint("Error loading LMS: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddVideoDialog() {
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final classIdCtrl = TextEditingController(); // Or dropdown later
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add LMS Material'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(labelText: 'Material URL (e.g. PDF/Video)'),
              ),
              TextField(
                controller: classIdCtrl,
                decoration: const InputDecoration(labelText: 'Class ID'),
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                try {
                  final req = await http.post(
                    Uri.parse('${ApiService.baseUrl}/api/lms/videos'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'title': titleCtrl.text,
                      'url': urlCtrl.text,
                      'classId': classIdCtrl.text,
                      'teacherId': auth.teacherId,
                      'duration': 120, // dummy
                    })
                  );
                  if (req.statusCode == 201) {
                    Navigator.pop(ctx);
                    _fetchVideos();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added!')));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add')));
                  }
                } catch (e) {
                  debugPrint('$e');
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('LMS Manager', style: GoogleFonts.poppins()),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _videos.isEmpty 
          ? const Center(child: Text("No materials uploaded yet."))
          : ListView.builder(
              itemCount: _videos.length,
              itemBuilder: (ctx, i) {
                final v = _videos[i];
                return ListTile(
                  leading: const Icon(Icons.video_library),
                  title: Text(v['title'] ?? 'Untitled', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  subtitle: Text(v['url'] ?? ''),
                );
              }
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddVideoDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
