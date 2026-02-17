import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/class.dart';
import '../providers/auth_provider.dart';
import 'package:intl/intl.dart';

class NoticesTab extends StatefulWidget {
  final String classId;

  const NoticesTab({super.key, required this.classId});

  @override
  State<NoticesTab> createState() => _NoticesTabState();
}

class _NoticesTabState extends State<NoticesTab> {
  List<Map<String, dynamic>> _notices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    try {
      final notices = await ApiService.getNotices(widget.classId);
      if (mounted) {
        setState(() {
          _notices = notices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load notices: $e')),
        );
      }
    }
  }

  Future<void> _addNotice() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String priority = 'normal';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Notice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(labelText: 'Content'),
              maxLines: 3,
            ),
            DropdownButtonFormField<String>(
              value: priority,
              items: ['low', 'normal', 'high']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                  .toList(),
              onChanged: (v) => priority = v!,
              decoration: const InputDecoration(labelText: 'Priority'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty || contentController.text.isEmpty) return;
              try {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                await ApiService.createNotice(
                  widget.classId,
                  titleController.text,
                  contentController.text,
                  auth.teacherId!,
                  priority: priority,
                );
                Navigator.pop(context);
                _loadNotices();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to post notice: $e')),
                );
              }
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _addNotice,
        child: const Icon(Icons.add),
        tooltip: 'Post Notice',
      ),
      body: _notices.isEmpty
          ? const Center(child: Text('No notices yet.'))
          : ListView.builder(
              itemCount: _notices.length,
              itemBuilder: (context, index) {
                final notice = _notices[index];
                Color priorityColor = Colors.green;
                if (notice['priority'] == 'high') priorityColor = Colors.red;
                if (notice['priority'] == 'normal') priorityColor = Colors.orange;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: priorityColor,
                      child: const Icon(Icons.campaign, color: Colors.white),
                    ),
                    title: Text(notice['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(notice['content']),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat.yMMMd().format(DateTime.parse(notice['createdAt'])),
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
