import 'package:flutter/material.dart';

class ExportFormatDialog extends StatelessWidget {
  final VoidCallback onCsvSelected;
  final VoidCallback onPdfSelected;

  const ExportFormatDialog({
    super.key,
    required this.onCsvSelected,
    required this.onPdfSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Select Export Format',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.table_chart, color: Colors.green),
            title: const Text('Export as CSV'),
            subtitle: const Text('Commas separated values, good for Excel'),
            onTap: () {
              Navigator.pop(context);
              onCsvSelected();
            },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
            title: const Text('Export as PDF'),
            subtitle: const Text('Formatted document, good for printing'),
            onTap: () {
              Navigator.pop(context);
              onPdfSelected();
            },
          ),
        ],
      ),
    );
  }
}
