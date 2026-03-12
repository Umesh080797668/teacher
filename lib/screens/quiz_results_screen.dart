import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/quiz.dart';
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';

class QuizResultsScreen extends StatelessWidget {
  final String quizId;
  final String quizTitle;

  const QuizResultsScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0E17) : const Color(0xFFF5F5FA),
      body: SafeArea(
        child: Column(
          children: [
            // Gradient Header
            Container(
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        colors: [Color(0xFF1E1A2E), Color(0xFF2D2660)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF3730A3), Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Results',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          quizTitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: FutureBuilder<List<QuizResult>>(
        future: ApiService.getQuizResults(quizId),
        builder: (context, snapshot) {
          // ── Skeleton loading ──────────────────────────────────
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: 6,
              itemBuilder: (_, __) => const QuizResultTileSkeleton(),
            );
          }

          // ── Error state ─────────────────────────────────────
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 56, color: cs.error),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load results',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            );
          }

          // ── Empty state ──────────────────────────────────────
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 72,
                      color: cs.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No submissions yet',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Student results will appear here once they submit',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            );
          }

          // ── Loaded list ──────────────────────────────────────
          final results = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final result = results[index];
              final studentName = result.studentDetails != null
                  ? result.studentDetails!['name'] ?? 'Unknown'
                  : 'Student ${result.studentId}';
              final studentReg = result.studentDetails != null &&
                      result.studentDetails!['regNo'] != null
                  ? result.studentDetails!['regNo'] as String
                  : '';

              final scoreRatio = result.totalMarks > 0
                  ? result.score / result.totalMarks
                  : 0.0;
              final scoreColor = scoreRatio >= 0.75
                  ? const Color(0xFF22C55E)
                  : scoreRatio >= 0.5
                      ? const Color(0xFFF59E0B)
                      : cs.error;
              final scoreGradient = scoreRatio >= 0.75
                  ? const LinearGradient(colors: [Color(0xFF059669), Color(0xFF22C55E)])
                  : scoreRatio >= 0.5
                      ? const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFF59E0B)])
                      : LinearGradient(colors: [cs.error, cs.error.withValues(alpha: 0.7)]);

              final initial = studentName.isNotEmpty ? studentName[0].toUpperCase() : '?';

              return Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isDark
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          )
                        ],
                  border: isDark
                      ? Border.all(color: Colors.white.withValues(alpha: 0.06))
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // Avatar with gradient
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              studentName,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (studentReg.isNotEmpty)
                              Text(
                                studentReg,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : cs.onSurface.withValues(alpha: 0.55),
                                ),
                              ),
                            const SizedBox(height: 6),
                            // Score progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(
                                height: 5,
                                child: LinearProgressIndicator(
                                  value: scoreRatio.clamp(0.0, 1.0),
                                  backgroundColor:
                                      scoreColor.withValues(alpha: 0.15),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(scoreColor),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Submitted: ${result.submittedAt.toString().substring(0, 16)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.45)
                                    : cs.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Score badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: scoreGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: scoreColor.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Text(
                          '${result.score}/${result.totalMarks}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
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
}
