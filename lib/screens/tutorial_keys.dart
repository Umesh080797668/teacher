// Tutorial GlobalKeys — shared between tutorial_screen.dart and home_screen.dart
// Keep this in its own file to avoid circular imports.
import 'package:flutter/material.dart';

// ── Home Screen ──────────────────────────────────────────────────────────────
final GlobalKey tutorialKeyGreeting    = GlobalKey(debugLabel: 'tut_greeting');
final GlobalKey tutorialKeySearch      = GlobalKey(debugLabel: 'tut_search');
final GlobalKey tutorialKeyStatsRow    = GlobalKey(debugLabel: 'tut_stats_row');
final GlobalKey tutorialKeyQuickAccess = GlobalKey(debugLabel: 'tut_quick_access');
final GlobalKey tutorialKeyFab         = GlobalKey(debugLabel: 'tut_fab');
final GlobalKey tutorialKeyAvatar      = GlobalKey(debugLabel: 'tut_avatar');

// ── Attendance Mark Screen ────────────────────────────────────────────────────
final GlobalKey tutorialKeyAttDate  = GlobalKey(debugLabel: 'tut_att_date');
final GlobalKey tutorialKeyAttClass = GlobalKey(debugLabel: 'tut_att_class');
final GlobalKey tutorialKeyAttList  = GlobalKey(debugLabel: 'tut_att_list');

// ── Classes Screen ────────────────────────────────────────────────────────────
final GlobalKey tutorialKeyClassGrid = GlobalKey(debugLabel: 'tut_class_grid');
final GlobalKey tutorialKeyClassFab  = GlobalKey(debugLabel: 'tut_class_fab');

// ── Students Screen ───────────────────────────────────────────────────────────
final GlobalKey tutorialKeyStudSearch = GlobalKey(debugLabel: 'tut_stud_search');
final GlobalKey tutorialKeyStudFilter = GlobalKey(debugLabel: 'tut_stud_filter');
final GlobalKey tutorialKeyStudList   = GlobalKey(debugLabel: 'tut_stud_list');
final GlobalKey tutorialKeyStudFab    = GlobalKey(debugLabel: 'tut_stud_fab');

// ── Reports Screen ────────────────────────────────────────────────────────────
final GlobalKey tutorialKeyRepTabBar = GlobalKey(debugLabel: 'tut_rep_tabs');
final GlobalKey tutorialKeyRepPdf    = GlobalKey(debugLabel: 'tut_rep_pdf');
