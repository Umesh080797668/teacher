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
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'New Notice',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g., Exam Schedule',
                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Content',
                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8)),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceVariant,
                  contentPadding: const EdgeInsets.all(16),
                ),
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: priority,
                dropdownColor: Theme.of(context).cardColor,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                items: ['low', 'normal', 'high']
                    .map((e) => DropdownMenuItem(
                      value: e, 
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle, 
                            size: 12, 
                            color: e == 'high' ? Colors.red : (e == 'normal' ? Colors.orange : Colors.green)
                          ),
                          const SizedBox(width: 8),
                          Text(e.toUpperCase(), style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
                        ],
                      )
                    ))
                    .toList(),
                onChanged: (v) => priority = v!,
                decoration: InputDecoration(
                  labelText: 'Priority',
                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
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
                if (mounted) {
                  Navigator.pop(context);
                  _loadNotices();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notice posted successfully!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to post notice: $e')),
                  );
                }
              }
            },
            child: const Text('Post Notice'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _addNotice,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: const Icon(Icons.add),
        tooltip: 'Post Notice',
      ),
      body: _notices.isEmpty
          ? Center(child: Text('No notices yet.', style: TextStyle(color: Theme.of(context).colorScheme.onBackground)))
          : ListView.builder(
              itemCount: _notices.length,
              itemBuilder: (context, index) {
                final notice = _notices[index];
                Color priorityColor = Colors.green;
                if (notice['priority'] == 'high') priorityColor = Colors.red;
                if (notice['priority'] == 'normal') priorityColor = Colors.orange;

                return Card(
                  color: Theme.of(context).cardColor,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: priorityColor,
                      child: Icon(Icons.campaign, color: Theme.of(context).colorScheme.onPrimary),
                    ),
                    title: Text(notice['title'], style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(notice['content'], style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat.yMMMd().format(DateTime.parse(notice['createdAt'])),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
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
