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

// ── Payments Screen ──────────────────────────────────────────────────────────
final GlobalKey tutorialKeyPaySearch = GlobalKey(debugLabel: 'tut_pay_search');
final GlobalKey tutorialKeyPayRemind = GlobalKey(debugLabel: 'tut_pay_remind');
final GlobalKey tutorialKeyPayList = GlobalKey(debugLabel: 'tut_pay_list');

// ── Collect Payments Screen ──────────────────────────────────────────────────
final GlobalKey tutorialKeyColClass = GlobalKey(debugLabel: 'tut_col_class');
final GlobalKey tutorialKeyColSearch = GlobalKey(debugLabel: 'tut_col_search');
final GlobalKey tutorialKeyColList = GlobalKey(debugLabel: 'tut_col_list');

// ── Quiz Screen ──────────────────────────────────────────────────────────────
final GlobalKey tutorialKeyQuizList = GlobalKey(debugLabel: 'tut_quiz_list');
final GlobalKey tutorialKeyQuizFab = GlobalKey(debugLabel: 'tut_quiz_fab');

final GlobalKey tutorialKeyRepTabAtt = GlobalKey(debugLabel: 'tut_rep_tab_att');
final GlobalKey tutorialKeyRepTabStud = GlobalKey(debugLabel: 'tut_rep_tab_stud');
final GlobalKey tutorialKeyRepTabPay = GlobalKey(debugLabel: 'tut_rep_tab_pay');
final GlobalKey tutorialKeyRepTabEarn = GlobalKey(debugLabel: 'tut_rep_tab_earn');
final GlobalKey tutorialKeyColScanner = GlobalKey(debugLabel: 'tut_col_scan');

// ── Class Details Screen ──────────────────────────────────────────────────
final GlobalKey tutorialKeyCdSummary = GlobalKey(debugLabel: 'tut_cd_summary');
final GlobalKey tutorialKeyCdTabs    = GlobalKey(debugLabel: 'tut_cd_tabs');
final GlobalKey tutorialKeyCdFab     = GlobalKey(debugLabel: 'tut_cd_fab');
final GlobalKey tutorialKeyCdExport  = GlobalKey(debugLabel: 'tut_cd_export');

// ── Student Details Screen ────────────────────────────────────────────────
final GlobalKey tutorialKeySdProfile = GlobalKey(debugLabel: 'tut_sd_profile');
final GlobalKey tutorialKeySdActions = GlobalKey(debugLabel: 'tut_sd_actions');
final GlobalKey tutorialKeySdTabs    = GlobalKey(debugLabel: 'tut_sd_tabs');

// ── Settings Screen ────────────────────────────────────────────────────────
final GlobalKey tutorialKeySetTheme  = GlobalKey(debugLabel: 'tut_set_theme');
final GlobalKey tutorialKeySetLock   = GlobalKey(debugLabel: 'tut_set_lock');
final GlobalKey tutorialKeySetBackup = GlobalKey(debugLabel: 'tut_set_backup');

// ── Profile Screen ─────────────────────────────────────────────────────────
final GlobalKey tutorialKeyProfEdit   = GlobalKey(debugLabel: 'tut_prof_edit');
final GlobalKey tutorialKeyProfInst   = GlobalKey(debugLabel: 'tut_prof_inst');
final GlobalKey tutorialKeyProfLogout = GlobalKey(debugLabel: 'tut_prof_logout');

// ── Web QR Login Screen ──────────────────────────────────────────────────
final GlobalKey tutorialKeyQrScanner = GlobalKey(debugLabel: 'tut_qr_scanner');
final GlobalKey tutorialKeyQrHelp    = GlobalKey(debugLabel: 'tut_qr_help');

// ── Extra Extensions ───────────────────────────────────────────────────────
final GlobalKey tutorialKeyAttSubmit = GlobalKey(debugLabel: 'tut_att_submit');
final GlobalKey tutorialKeyColPayBtn = GlobalKey(debugLabel: 'tut_col_paybtn');

