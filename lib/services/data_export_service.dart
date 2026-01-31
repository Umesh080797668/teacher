import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/attendance.dart';
import '../models/class.dart';
import '../models/student.dart';
import '../models/payment.dart';

// Top-level functions for compute
String _generateAttendanceCsv(List<Attendance> records) {
  List<List<dynamic>> rows = [];
  rows.add([
    'Date', 'Student ID', 'Session', 'Status', 'Month', 'Year', 'Created At'
  ]);

  for (var record in records) {
    rows.add([
      DateFormat('yyyy-MM-dd').format(record.date),
      record.studentId,
      record.session,
      record.status,
      record.month,
      record.year,
      record.createdAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(record.createdAt!) : '',
    ]);
  }

  return const ListToCsvConverter().convert(rows);
}

String _generateClassesCsv(List<Class> classes) {
  List<List<dynamic>> rows = [];
  rows.add(['Class Name', 'Teacher ID', 'Created At']);

  for (var cls in classes) {
    rows.add([
      cls.name,
      cls.teacherId,
      cls.createdAt != null ? DateFormat('yyyy-MM-dd').format(cls.createdAt!) : '',
    ]);
  }

  return const ListToCsvConverter().convert(rows);
}

String _generateStudentsCsv(List<Student> students) {
  List<List<dynamic>> rows = [];
  rows.add(['Student Name', 'Student ID', 'Class ID', 'Email', 'Is Restricted', 'Restriction Reason', 'Restricted At', 'Created At']);

  for (var student in students) {
    rows.add([
      student.name,
      student.studentId,
      student.classId ?? '',
      student.email ?? '',
      student.isRestricted ? 'Yes' : 'No',
      student.restrictionReason ?? '',
      student.restrictedAt != null ? DateFormat('yyyy-MM-dd').format(student.restrictedAt!) : '',
      student.createdAt != null ? DateFormat('yyyy-MM-dd').format(student.createdAt!) : '',
    ]);
  }

  return const ListToCsvConverter().convert(rows);
}

String _generatePaymentsCsv(List<Payment> payments) {
  List<List<dynamic>> rows = [];
  rows.add(['Date', 'Student ID', 'Class ID', 'Amount', 'Type', 'Month', 'Year']);

  for (var payment in payments) {
    rows.add([
      DateFormat('yyyy-MM-dd').format(payment.date),
      payment.studentId,
      payment.classId,
      payment.amount,
      payment.type,
      payment.month ?? '',
      payment.year ?? '',
    ]);
  }

  return const ListToCsvConverter().convert(rows);
}

class DataExportService {
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Try to request storage permission
      final status = await Permission.storage.request();
      if (status.isGranted) {
        return true;
      } else if (status.isPermanentlyDenied) {
        // Open app settings if permanently denied
        await openAppSettings();
        return false;
      } else {
        // If storage permission is denied, try to use app documents directory as fallback
        return false; // Will use documents directory as fallback
      }
    } else if (Platform.isIOS) {
      // iOS doesn't require explicit storage permission for documents directory
      return true;
    } else {
      return true;
    }
  }

  static Future<String?> exportData() async {
    try {
      // Request storage permissions
      final hasExternalPermission = await requestStoragePermission();

      // Get the directory to save the file
      Directory? directory;
      if (Platform.isAndroid) {
        if (hasExternalPermission) {
          directory = await getExternalStorageDirectory();
        } else {
          // Fallback to app documents directory
          directory = await getApplicationDocumentsDirectory();
          // Create an "Exports" subdirectory
          directory = Directory('${directory.path}/Exports');
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Could not get storage directory');
      }

      // Get all data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final allData = <String, dynamic>{};

      for (var key in prefs.getKeys()) {
        final value = prefs.get(key);
        allData[key] = value;
      }

      // Create export data structure
      final exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'appVersion': '1.0.0',
        'data': allData,
      };

      // Convert to JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // Create filename with timestamp
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')[0];
      final filename = 'teacher_app_data_$timestamp.json';

      // Save the file
      final file = File('${directory.path}/$filename');
      await file.writeAsString(jsonString);

      debugPrint('Data exported to: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('Error exporting data: $e');
      rethrow;
    }
  }

  static Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('All local data cleared');
    } catch (e) {
      debugPrint('Error clearing data: $e');
      rethrow;
    }
  }

  static Future<void> exportAttendanceToCsv(List<Attendance> records, String fileNamePrefix) async {
    String csv = await compute(_generateAttendanceCsv, records);
    await _shareCsvFile(csv, '${fileNamePrefix}_attendance.csv');
  }

  static Future<void> exportClassesToCsv(List<Class> classes) async {
    String csv = await compute(_generateClassesCsv, classes);
    await _shareCsvFile(csv, 'classes_export.csv');
  }

  static Future<void> exportStudentsToCsv(List<Student> students) async {
    String csv = await compute(_generateStudentsCsv, students);
    await _shareCsvFile(csv, 'students_export.csv');
  }

  static Future<void> exportPaymentsToCsv(List<Payment> payments) async {
    String csv = await compute(_generatePaymentsCsv, payments);
    await _shareCsvFile(csv, 'payments_export.csv');
  }

  static Future<void> exportAttendanceToPdf(List<Attendance> records, String fileNamePrefix) async {
    final pdf = pw.Document();
    
    // Create data for table
    final data = records.map((record) {
      return [
        DateFormat('yyyy-MM-dd').format(record.date),
        record.studentId, // Would be better if we had student name here, but id is what we have in the model directly
        record.status.toUpperCase(),
        record.session,
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(context, 'Attendance Report - $fileNamePrefix'),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              context: context,
              headers: ['Date', 'Student ID', 'Status', 'Session'],
              data: data,
              border: null,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
              },
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Generated on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
            ),
          ];
        },
      ),
    );

    await _sharePdfFile(pdf, '${fileNamePrefix}_attendance_report.pdf');
  }

  static Future<void> exportClassesToPdf(List<Class> classes) async {
    final pdf = pw.Document();
    
    final data = classes.map((cls) {
      return [
        cls.name,
        // cls.teacherId, // Skipping teacher ID for cleaner report
        cls.createdAt != null ? DateFormat('yyyy-MM-dd').format(cls.createdAt!) : '-',
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
             _buildHeader(context, 'Class List'),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Class Name', 'Created Date'],
              data: data,
              border: null,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    await _sharePdfFile(pdf, 'classes_export.pdf');
  }

  static Future<void> exportStudentsToPdf(List<Student> students) async {
    final pdf = pw.Document();
    
    final data = students.map((s) {
      return [
        s.name,
        s.studentId,
        s.email ?? '-',
        s.isRestricted ? 'Restricted' : 'Active',
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            _buildHeader(context, 'Student List'),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Name', 'Student ID', 'Email', 'Status'],
              data: data,
              border: null,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1),
              },
            ),
          ];
        },
      ),
    );

    await _sharePdfFile(pdf, 'students_export.pdf');
  }

  static Future<void> exportPaymentsToPdf(List<Payment> payments) async {
    final pdf = pw.Document();
    
    final data = payments.map((p) {
      return [
        DateFormat('yyyy-MM-dd').format(p.date),
        p.studentId, // Again, strictly using ID as per model access
        '${p.type.toUpperCase()}',
        '${p.amount.toStringAsFixed(2)}',
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            _buildHeader(context, 'Payment Report'),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Date', 'Student ID', 'Type', 'Amount'],
              data: data,
              border: null,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                3: pw.Alignment.centerRight,
              },
            ),
          ];
        },
      ),
    );

    await _sharePdfFile(pdf, 'payments_export.pdf');
  }

  static Future<String> generateMonthlyReport({
    required int month,
    required int year,
    required List<Class> classes,
    required List<Student> students,
    required List<Payment> payments,
    List<Attendance> attendanceRecords = const [],
  }) async {
    final pdf = pw.Document();
    final monthName = DateFormat('MMMM').format(DateTime(year, month));
    
    // Load Logo
    pw.MemoryImage? logoImage;
    try {
      final ByteData bytes = await rootBundle.load('assets/images/Gemini_Generated_Image_iirantiirantiira.png');
      logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error loading logo: $e');
    }

    // Sort classes
    final sortedClasses = List<Class>.from(classes)..sort((a, b) => a.name.compareTo(b.name));

    // Brand Colors
    const PdfColor brandColor = PdfColor.fromInt(0xFF1E88E5); // Blue 600
    const PdfColor accentColor = PdfColor.fromInt(0xFFE3F2FD); // Blue 50
    const PdfColor textColor = PdfColors.grey800;

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: brandColor, width: 2),
              ),
            ),
          ),
        ),
        header: (pw.Context context) => _buildEnhancedHeader(context, 'Monthly Report - $monthName $year', logoImage, brandColor),
        footer: (pw.Context context) => _buildFooter(context, brandColor),
        build: (pw.Context context) {
          final List<pw.Widget> widgets = [];
          
          widgets.add(pw.SizedBox(height: 20));

          for (final classObj in sortedClasses) {
            // Get students for this class
            final classStudents = students.where((s) => s.classId == classObj.id).toList();
            
            if (classStudents.isEmpty) continue;
            
            // Sort students
            classStudents.sort((a, b) => a.name.compareTo(b.name));
            
            double classTotalFees = 0.0;
            int paidCount = 0;
            
            final List<List<String>> tableData = [];
            
            for (final student in classStudents) {
              // Find payment for this month/year
              Payment? payment;
              try {
                payment = payments.firstWhere((p) {
                   final pMonth = p.month ?? p.date.month;
                   final pYear = p.year ?? p.date.year;
                   return p.studentId == student.id && 
                          p.classId == classObj.id && 
                          pMonth == month && 
                          pYear == year;
                });
              } catch (_) {
                payment = null;
              }
              
              if (payment != null) {
                classTotalFees += payment.amount;
                paidCount++;
              }
              
              tableData.add([
                student.studentId,
                student.name,
                // student.email ?? '-', // Removed to save space
                payment != null ? DateFormat('yyyy-MM-dd').format(payment.date) : '-',
                payment != null ? payment.amount.toStringAsFixed(2) : 'Unpaid',
                payment != null ? 'Paid' : 'Pending',
              ]);
            }

            // Class Section Header
            widgets.add(
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: pw.BoxDecoration(
                  color: brandColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Class: ${classObj.name}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
            
            widgets.add(pw.SizedBox(height: 10));

            // Payment Table
            widgets.add(pw.Text('Fees & Payments', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: brandColor)));
            widgets.add(pw.SizedBox(height: 5));

            // Custom table rows for payment to handle colors
            final List<pw.TableRow> paymentRows = [];
            
            // Header Row
            paymentRows.add(pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border(bottom: pw.BorderSide(color: brandColor, width: 1.5)),
              ),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('ID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: brandColor))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: brandColor))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Paid Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: brandColor), textAlign: pw.TextAlign.center)),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: brandColor), textAlign: pw.TextAlign.right)),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: brandColor), textAlign: pw.TextAlign.center)),
              ],
            ));

            for (int i = 0; i < classStudents.length; i++) {
              final student = classStudents[i];
              Payment? payment;
              try {
                payment = payments.firstWhere((p) {
                   final pMonth = p.month ?? p.date.month;
                   final pYear = p.year ?? p.date.year;
                   return p.studentId == student.id && 
                          p.classId == classObj.id && 
                          pMonth == month && 
                          pYear == year;
                });
              } catch (_) {
                payment = null;
              }

              // Define colors
              final PdfColor statusColor = payment != null ? PdfColors.green700 : PdfColors.amber700;
              final String statusText = payment != null ? 'Paid' : 'Pending';
              final PdfColor amountColor = payment != null ? textColor : PdfColors.red700;
              final String amountText = payment != null ? payment.amount.toStringAsFixed(2) : 'Unpaid';
              
              paymentRows.add(pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: i % 2 == 1 ? accentColor : null,
                  border: const pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
                ),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(student.studentId, style: const pw.TextStyle(fontSize: 10, color: textColor))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(student.name, style: const pw.TextStyle(fontSize: 10, color: textColor))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(payment != null ? DateFormat('yyyy-MM-dd').format(payment.date) : '-', style: const pw.TextStyle(fontSize: 10, color: textColor), textAlign: pw.TextAlign.center)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(amountText, style: pw.TextStyle(fontSize: 10, color: amountColor, fontWeight: payment == null ? pw.FontWeight.bold : null), textAlign: pw.TextAlign.right)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(statusText, style: pw.TextStyle(fontSize: 10, color: statusColor, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                ],
              ));
            }

            widgets.add(pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(2), // ID
                1: const pw.FlexColumnWidth(4), // Name
                2: const pw.FlexColumnWidth(3), // Date
                3: const pw.FlexColumnWidth(2), // Amount
                4: const pw.FlexColumnWidth(2), // Status
              },
              children: paymentRows,
            ));
            
            widgets.add(pw.SizedBox(height: 5));

            // Class Summary Box
            widgets.add(pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                   pw.Row(children: [
                       pw.Text('Total Students: ${classStudents.length}  |  ', style: const pw.TextStyle(fontSize: 10)),
                       pw.Text('Paid: $paidCount  |  ', style: const pw.TextStyle(fontSize: 10, color: PdfColors.green700)),
                       pw.Text('Unpaid: ${classStudents.length - paidCount}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.red700)),
                   ]),
                   pw.Row(children: [
                       pw.Text('Total Collected: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: brandColor)),
                       pw.Text('${classTotalFees.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                   ]),
                ]
              )
            ));

            // ATTENDANCE SECTION
            if (attendanceRecords.isNotEmpty) {
              final classStudentMongoIds = classStudents.map((s) => s.id).toSet();
              final classStudentCustomIds = classStudents.map((s) => s.studentId).toSet();
              
              debugPrint('Generating attendance for class ${classObj.name} (Month: $month, Year: $year)');
              debugPrint('Total attendance records: ${attendanceRecords.length}');
              
              if (attendanceRecords.isNotEmpty) {
                 debugPrint('Sample Attendance Record: studentId=${attendanceRecords.first.studentId}, date=${attendanceRecords.first.date}');
              }
              if (classStudentMongoIds.isNotEmpty) {
                 debugPrint('Sample Student ID (Mongo) from Class: ${classStudentMongoIds.first}');
              }
              if (classStudentCustomIds.isNotEmpty) {
                 debugPrint('Sample Student ID (Custom) from Class: ${classStudentCustomIds.first}');
              }

              // Filter attendance for this class's students and this month/year
              // Use date property as primary source of truth for month/year
              // Check BOTH Mongo ID and Custom Student ID
              final classAttendance = attendanceRecords.where((a) => 
                (classStudentMongoIds.contains(a.studentId) || classStudentCustomIds.contains(a.studentId)) &&
                a.date.month == month && 
                a.date.year == year
              ).toList();
              
              debugPrint('Attendance records for this class: ${classAttendance.length}');
              
              // Find unique dates
              final uniqueDates = classAttendance
                  .map((a) => DateTime(a.date.year, a.date.month, a.date.day))
                  .toSet()
                  .toList()
                  ..sort((a, b) => a.compareTo(b));
              
              if (uniqueDates.isNotEmpty) {
                widgets.add(pw.SizedBox(height: 20));
                widgets.add(pw.Text('Attendance Details (${uniqueDates.length} Days)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: brandColor)));
                widgets.add(pw.SizedBox(height: 5));

                // Table Header for Attendance
                final List<pw.TableRow> attRows = [];
                
                // Header
                final List<pw.Widget> headerWidgets = [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: brandColor))),
                ];
                for(var d in uniqueDates) {
                  headerWidgets.add(
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(DateFormat('d').format(d), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: brandColor), textAlign: pw.TextAlign.center))
                  );
                }
                
                attRows.add(pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border(bottom: pw.BorderSide(color: brandColor, width: 1.0)),
                  ),
                  children: headerWidgets,
                ));

                // Data Rows
                for (int i = 0; i < classStudents.length; i++) {
                  final student = classStudents[i];
                  final List<pw.Widget> rowWidgets = [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(student.name, style: const pw.TextStyle(fontSize: 9, color: textColor))),
                  ];
                  
                  for (final date in uniqueDates) {
                    final recordsOnDate = classAttendance.where((a) => 
                      (a.studentId == student.id || a.studentId == student.studentId) && 
                      a.date.year == date.year && 
                      a.date.month == date.month && 
                      a.date.day == date.day
                    ).toList();
                    
                    String statusChar = '-';
                    PdfColor statusColor = PdfColors.grey400;
                    
                    if (recordsOnDate.isNotEmpty) {
                      final s = recordsOnDate.first.status.toLowerCase();
                      if (s == 'present') {
                        statusChar = 'P';
                        statusColor = PdfColors.green700;
                      } else if (s == 'absent') {
                        statusChar = 'A';
                        statusColor = PdfColors.red700;
                      } else if (s == 'late') {
                        statusChar = 'L';
                        statusColor = PdfColors.orange700;
                      } else {
                        statusChar = s.isNotEmpty ? s[0].toUpperCase() : '?';
                      }
                    }
                    
                    rowWidgets.add(
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(statusChar, style: pw.TextStyle(fontSize: 9, color: statusColor, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center))
                    );
                  }
                  
                  attRows.add(pw.TableRow(
                    decoration: pw.BoxDecoration(
                       color: i % 2 == 1 ? accentColor : null,
                       border: const pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
                    ),
                    children: rowWidgets,
                  ));
                }

                // Calculate column widths
                final Map<int, pw.TableColumnWidth> colWidths = {
                  0: const pw.FlexColumnWidth(3),
                };
                for (int i = 0; i < uniqueDates.length; i++) {
                   colWidths[i + 1] = const pw.FlexColumnWidth(1);
                }

                widgets.add(pw.Table(
                  columnWidths: colWidths,
                  children: attRows,
                ));
                
                widgets.add(pw.SizedBox(height: 5));
                widgets.add(pw.Row(children: [
                   pw.Text('Key: ', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                   pw.Text('P', style: pw.TextStyle(fontSize: 8, color: PdfColors.green700, fontWeight: pw.FontWeight.bold)),
                   pw.Text(': Present, ', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                   pw.Text('A', style: pw.TextStyle(fontSize: 8, color: PdfColors.red700, fontWeight: pw.FontWeight.bold)),
                   pw.Text(': Absent, ', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                   pw.Text('L', style: pw.TextStyle(fontSize: 8, color: PdfColors.orange700, fontWeight: pw.FontWeight.bold)),
                   pw.Text(': Late', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ]));
              }
            }

             widgets.add(pw.SizedBox(height: 25));
          }
          
          return widgets;
        },
      ),
    );

    return await _savePdfToStorage(pdf, 'Monthly_Report_${monthName}_$year.pdf');
  }

  static pw.Widget _buildEnhancedHeader(pw.Context context, String title, pw.MemoryImage? logo, PdfColor brandColor) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Row(
        children: [
          if (logo != null)
            pw.Container(
              width: 60,
              height: 60,
              margin: const pw.EdgeInsets.only(right: 15),
              child: pw.Image(logo),
            ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'EduVerse',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: brandColor,
                  ),
                ),
                pw.Text(
                  'Excellence in Attendance Management',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 5),
                 pw.Container(
                    height: 2,
                    color: brandColor,
                    width: 100, // Partial underline
                  ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'REPORT',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey300,
                ),
              ),
              pw.Text(
                title.replaceAll('Monthly Report - ', ''),
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
              pw.Text(
                DateFormat('yyyy-MM-dd').format(DateTime.now()),
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context, PdfColor brandColor) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Column(children: [
          pw.Divider(color: PdfColors.grey300),
          pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated by EduVerse Teacher App',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ],
        )
      ]) 
    );
  }

  static pw.Widget _buildHeader(pw.Context context, String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.Text(
              'EduVerse',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey500,
              ),
            ),
          ],
        ),
        pw.Divider(color: PdfColors.blue900, thickness: 2),
      ],
    );
  }

  static Future<String> _savePdfToStorage(pw.Document pdf, String fileName) async {
    try {
      Directory? directory;
      bool hasPermission = false;
      
      if (Platform.isAndroid) {
        hasPermission = await requestStoragePermission();
        if (hasPermission) {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
             directory = await getExternalStorageDirectory();
          }
        }
      }
      
      if (directory == null) {
        directory = await getApplicationDocumentsDirectory();
      }
      
      // Timestamp to avoid overwrite if needed, or just overwrite
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      
      return file.path;
    } catch (e) {
      debugPrint('Error saving PDF: $e');
      // Fallback to temp dir if other storage fails (e.g. permission issues on newer Android)
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      return file.path;
    }
  }

  static Future<void> _sharePdfFile(pw.Document pdf, String fileName) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      
      await Share.shareXFiles([XFile(file.path)], text: 'Here is your exported PDF report.');
    } catch (e) {
      debugPrint('Error sharing PDF file: $e');
    }
  }

  static Future<void> _shareCsvFile(String csvContent, String fileName) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvContent);
      
      await Share.shareXFiles([XFile(file.path)], text: 'Here is your exported CSV file.');
    } catch (e) {
      debugPrint('Error sharing CSV file: $e');
    }
  }
}
