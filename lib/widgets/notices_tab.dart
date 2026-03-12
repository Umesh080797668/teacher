import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'package:intl/intl.dart';
import 'custom_widgets.dart';

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

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        final cs = Theme.of(sheetCtx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
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
                            child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('New Notice', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: cs.onSurface)),
                              Text('Post an announcement to students', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                            ]),
                          ),
                          IconButton(onPressed: () => Navigator.pop(sheetCtx), icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: titleController,
                        style: TextStyle(color: cs.onSurface),
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Title',
                          hintText: 'e.g., Exam Schedule',
                          labelStyle: TextStyle(color: cs.onSurfaceVariant),
                          hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                          prefixIcon: const Icon(Icons.title_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: contentController,
                        style: TextStyle(color: cs.onSurface),
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Content',
                          alignLabelWithHint: true,
                          labelStyle: TextStyle(color: cs.onSurfaceVariant),
                          prefixIcon: const Icon(Icons.notes_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: priority,
                        dropdownColor: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                        style: TextStyle(color: cs.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Priority',
                          labelStyle: TextStyle(color: cs.onSurfaceVariant),
                          prefixIcon: const Icon(Icons.flag_rounded),
                        ),
                        items: ['low', 'normal', 'high'].map((e) => DropdownMenuItem(
                          value: e,
                          child: Row(children: [
                            Icon(Icons.circle, size: 12, color: e == 'high' ? cs.error : (e == 'normal' ? cs.tertiary : const Color(0xFF22C55E))),
                            const SizedBox(width: 8),
                            Text(e.toUpperCase(), style: TextStyle(fontSize: 14, color: cs.onSurface)),
                          ]),
                        )).toList(),
                        onChanged: (v) => setSheetState(() => priority = v!),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () async {
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
                              Navigator.pop(sheetCtx);
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
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], begin: Alignment.centerLeft, end: Alignment.centerRight),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 5))],
                          ),
                          child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 10),
                            Text('Post Notice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 5,
        itemBuilder: (_, __) => const NoticeCardSkeleton(),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _addNotice,
        tooltip: 'Post Notice',
        child: const Icon(Icons.add),
      ),
      body: _notices.isEmpty
          ? Center(child: Text('No notices yet.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)))
          : ListView.builder(
              itemCount: _notices.length,
              itemBuilder: (context, index) {
                final notice = _notices[index];
                final cs = Theme.of(context).colorScheme;
                Color priorityColor = const Color(0xFF22C55E);
                if (notice['priority'] == 'high') priorityColor = cs.error;
                if (notice['priority'] == 'normal') priorityColor = cs.tertiary;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: priorityColor.withValues(alpha: 0.15),
                      child: Icon(Icons.campaign, color: priorityColor),
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
