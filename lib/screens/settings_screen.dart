import 'package:flutter/material.dart';
import 'package:teacher_attendance/screens/screen_tutorial.dart';
import 'package:teacher_attendance/screens/tutorial_keys.dart';
import 'package:teacher_attendance/screens/tutorial_screen.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/notification_service.dart';
import '../services/backup_service.dart';
import '../services/data_export_service.dart';
import '../services/update_service.dart';
import '../services/background_backup_service.dart';
import '../services/api_service.dart';
import 'profile_screen.dart';
import 'backup_restore_screen.dart';
import 'linked_devices_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import "../widgets/custom_widgets.dart";

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  // Tutorial Steps
  final List<STStep> _tutSteps = [
    STStep(
      targetKey: tutorialKeySetTheme,
      title: 'App Theme',
      body: 'Switch between light and dark mode according to your preference.',
      icon: Icons.brightness_medium_rounded,
      accent: const Color(0xFF4F46E5),
    ),
    STStep(
      targetKey: tutorialKeySetLock,
      title: 'App Lock',
      body: 'Secure your app using your device\'s biometric lock (Fingerprint/Face ID).',
      icon: Icons.lock_outline_rounded,
      accent: const Color(0xFF4F46E5),
    ),
    STStep(
      targetKey: tutorialKeySetBackup,
      title: 'Cloud Backup',
      body: 'Manually trigger a sync or restore your data securely.',
      icon: Icons.cloud_upload_rounded,
      accent: const Color(0xFF4F46E5),
    ),
  ];

  Future<void> _maybeShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    if (TutorialScreen.isRunning) return;
    final allSkipped = prefs.getBool('all_tutorials_skipped') ?? false;
    if (allSkipped) return;
    
    final hasSeen = prefs.getBool('tutorial_set_v1') ?? false;
    if (!hasSeen) {
      if (!mounted) return;
      await prefs.setBool('tutorial_set_v1', true);
      showSTTutorial(context: context, steps: _tutSteps, prefKey: 'tutorial_set_v1');
    }
  }

  bool _notificationsEnabled = true;
  bool _darkMode = false;
  bool _autoBackup = true;
  bool _isLoading = false;
  bool _checkingUpdate = false;
  String _currentVersion = '1.0.0';
  final _notificationService = NotificationService();
  final _backupService = BackupService();
  final _updateService = UpdateService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { _maybeShowTutorial(); });
    _loadSettings();
    _initializeServices();
    _loadVersionInfo();
  }

  Future<void> _initializeServices() async {
    await _notificationService.initialize();
    await _backupService.initialize();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _autoBackup = prefs.getBool('auto_backup') ?? true;
    });
  }

  Future<void> _loadVersionInfo() async {
    try {
      debugPrint('Loading version info...');
      final packageInfo = await PackageInfo.fromPlatform();
      debugPrint(
          'PackageInfo: appName=${packageInfo.appName}, packageName=${packageInfo.packageName}, version=${packageInfo.version}, buildNumber=${packageInfo.buildNumber}');
      setState(() {
        _currentVersion = packageInfo.version;
      });
      debugPrint('Setting current version to: $_currentVersion');
    } catch (e) {
      debugPrint('Error loading version info: $e');
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checkingUpdate = true);
    try {
      // Clear cache to ensure fresh data
      await _updateService.clearUpdateCache();
      debugPrint('Update cache cleared before checking for updates');

      // Don't show notification when manually checking from settings
      final updateInfo =
          await _updateService.checkForUpdates(showNotification: false);

      if (!mounted) return;

      if (updateInfo != null) {
        // Show update available dialog
        _showUpdateAvailableDialog(updateInfo);
      } else {
        // Show already up-to-date message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('You are using the latest version'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to check for updates: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _checkingUpdate = false);
      }
    }
  }

  void _showUpdateAvailableDialog(UpdateInfo updateInfo) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetCtx) {
        final cs = Theme.of(sheetCtx).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, -4))],
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
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
                    child: const Icon(Icons.system_update_alt_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Update Available', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: cs.onSurface)),
                      Text('Version ${updateInfo.version} is ready to install', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (updateInfo.releaseNotes.isNotEmpty) ...[
                      Text('What\'s New:', style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
                      const SizedBox(height: 6),
                      Text(updateInfo.releaseNotes, style: TextStyle(color: cs.onSurface)),
                      const SizedBox(height: 10),
                    ],
                    Text('Current version: $_currentVersion', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(sheetCtx).pop(),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: isDark ? cs.surfaceContainerHigh : const Color(0xFFF5F5FA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                        ),
                        child: Center(child: Text('Later', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        _downloadAndInstallUpdate(updateInfo);
                      },
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], begin: Alignment.centerLeft, end: Alignment.centerRight),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 5))],
                        ),
                        child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.download_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Install Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        ])),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadAndInstallUpdate(UpdateInfo updateInfo) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double downloadProgress = 0.0;
    String statusMessage = 'Preparing download...';
    late StateSetter setDialogState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          setDialogState = setState;
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Row(
              children: [
                Icon(
                  Icons.download,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Downloading Update',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: downloadProgress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 16),
                Text(
                  '${(downloadProgress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  statusMessage,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 
                          isDark ? 0.7 : 0.6,
                        ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      await _updateService.downloadAndInstallUpdate(
        updateInfo.downloadUrl,
        onProgress: (progress) {
          setDialogState(() {
            downloadProgress = progress;
            if (progress < 1.0) {
              statusMessage =
                  'Downloading... ${(progress * 100).toStringAsFixed(1)}%';
            } else {
              statusMessage = 'Download complete. Installing...';
            }
          });
        },
      );

      // Update UI to show installation
      setDialogState(() {
        downloadProgress = 1.0;
        statusMessage = 'Installing update...';
      });

      // Wait a bit to show the installation message
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                      'Update downloaded successfully. Please install the APK.'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to install update: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    setState(() => _isLoading = true);
    try {
      await _saveSetting(key, value);
      // Update local state and call respective services
      switch (key) {
        case 'notifications_enabled':
          _notificationsEnabled = value;
          await _notificationService.setNotificationsEnabled(value);
          break;
        case 'dark_mode':
          _darkMode = value;
          if (mounted) {
            final themeProvider = Provider.of<ThemeProvider>(
              context,
              listen: false,
            );
            await themeProvider.toggleTheme(value);
          }
          break;
        case 'auto_backup':
          _autoBackup = value;
          await _backupService.setAutoBackup(value);
          // Enable or disable background backup service
          if (value) {
            await BackgroundBackupService.enableBackupTask();
          } else {
            await BackgroundBackupService.cancelBackupTask();
          }
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Setting updated successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update setting: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF0F0E17) : const Color(0xFFF5F5FA),
      appBar: const CustomAppBar(
        title: 'Settings',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile Summary Card ────────────────────────────────
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: isDarkMode
                      ? const LinearGradient(
                          colors: [Color(0xFF1E1A2E), Color(0xFF2D2660)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [
                            Color(0xFF3730A3),
                            Color(0xFF4F46E5),
                            Color(0xFF7C3AED)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 2),
                      ),
                      child: Center(
                        child: Text(
                          (auth.userName?.isNotEmpty == true)
                              ? auth.userName![0].toUpperCase()
                              : 'T',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.userName ?? 'Teacher',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            auth.userEmail ?? 'No email set',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35)),
                            ),
                            child: const Text(
                              'Edit Profile →',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Account Section
            _buildSectionHeader('Account'),
            _buildSection(context, [
              _buildNavTile(
                context,
                icon: Icons.person_rounded,
                title: 'Profile Information',
                subtitle: auth.userName ?? 'Not set',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
              ),
              _buildNavTile(
                context,
                icon: Icons.email_rounded,
                title: 'Email',
                subtitle: auth.userEmail ?? 'Not set',
              ),
              _buildNavTile(
                context,
                icon: Icons.devices_rounded,
                title: 'Linked Devices',
                subtitle: 'Manage web sessions',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const LinkedDevicesScreen()),
                ),
              ),
            ]),
            const SizedBox(height: 24),

            // Preferences Section
            _buildSectionHeader('Preferences'),
            _buildSection(context, [
              _buildSwitchTile(
                context,
                icon: Icons.notifications_rounded,
                title: 'Push Notifications',
                subtitle: 'Receive notifications for important updates',
                value: _notificationsEnabled,
                onChanged: _isLoading
                    ? null
                    : (v) => _updateSetting('notifications_enabled', v),
              ),
              _buildSwitchTile(
                context,
                icon: _darkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                title: 'Dark Mode',
                subtitle: 'Switch between light and dark themes',
                value: _darkMode,
                onChanged: _isLoading
                    ? null
                    : (v) => _updateSetting('dark_mode', v),
              ),
              _buildSwitchTile(
                context,
                icon: Icons.backup_rounded,
                title: 'Auto Backup',
                subtitle: 'Automatically backup data to local device',
                value: _autoBackup,
                onChanged: _isLoading
                    ? null
                    : (v) => _updateSetting('auto_backup', v),
              ),
            ]),
            const SizedBox(height: 24),

            // Data & Privacy Section
            _buildSectionHeader('Data & Privacy'),
            _buildSection(context, [
              _buildNavTile(
                context,
                icon: Icons.backup_rounded,
                title: 'Backup & Restore',
                subtitle: 'Manage local backups',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const BackupRestoreScreen()),
                ),
              ),
              _buildNavTile(
                context,
                icon: Icons.download_rounded,
                title: 'Export Data',
                subtitle: 'Download your data in JSON format',
                onTap: () => _exportData(),
              ),
              _buildNavTile(
                context,
                icon: Icons.delete_rounded,
                title: 'Clear Local Data',
                subtitle: 'Remove all locally stored data',
                iconColor: Theme.of(context).colorScheme.error,
                onTap: () => _showClearDataDialog(),
              ),
            ]),
            const SizedBox(height: 24),

            // About Section
            _buildSectionHeader('About'),
            _buildSection(context, [
              _buildNavTile(
                context,
                icon: Icons.school_rounded,
                iconColor: const Color(0xFF4F46E5),
                title: 'App Tutorial',
                subtitle: 'Replay the full app walkthrough',
                onTap: () async {
                  // Capture overlay & navigator BEFORE popping (context becomes invalid after pop)
                  final ov  = Overlay.of(context, rootOverlay: true);
                  final nav = Navigator.of(context, rootNavigator: true);
                  // Pop back to HomeScreen
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  await Future.delayed(const Duration(milliseconds: 350));
                  // Reset all tutorial prefs so the flow starts fresh
                  await resetTutorial();
                  TutorialScreen.startWithOverlay(ov, nav);
                },
              ),
              _buildNavTile(
                context,
                icon: Icons.info_rounded,
                title: 'App Version',
                subtitle: _currentVersion,
              ),
              _buildNavTile(
                context,
                icon: Icons.system_update_rounded,
                title: 'Check for Updates',
                subtitle: 'Download the latest version',
                leading: _checkingUpdate
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : null,
                onTap: _checkingUpdate ? null : _checkForUpdates,
              ),
              _buildNavTile(
                context,
                icon: Icons.report_problem_rounded,
                title: 'Report a Problem',
                subtitle: 'Report issues or bugs',
                onTap: () => _showReportProblemDialog(),
              ),
              _buildNavTile(
                context,
                icon: Icons.lightbulb_rounded,
                title: 'Request a Feature',
                subtitle: 'Suggest new features',
                onTap: () => _showFeatureRequestDialog(),
              ),
              _buildNavTile(
                context,
                icon: Icons.privacy_tip_rounded,
                title: 'Privacy Policy',
                subtitle: 'Read our privacy policy',
                onTap: () => _showPrivacyPolicy(),
              ),
            ]),

            // Loading indicator
            if (_isLoading)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Updating settings...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF4F46E5),
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable section container ───────────────────────────────────────────
  Widget _buildSection(BuildContext context, List<Widget> tiles) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
        border: isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.06))
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              tiles[i],
              if (i < tiles.length - 1)
                Divider(
                    height: 1,
                    indent: 60,
                    color: cs.outlineVariant.withValues(alpha: 0.3)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Navigation tile ──────────────────────────────────────────────────────
  Widget _buildNavTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Color? iconColor,
    Widget? leading,
  }) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = iconColor ?? cs.primary;
    return ListTile(
      leading: leading ??
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  effectiveColor,
                  effectiveColor.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: effectiveColor.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              fontSize: 14)),
      subtitle: Text(subtitle,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
      trailing: onTap != null
          ? Icon(Icons.chevron_right_rounded,
              size: 20, color: cs.onSurfaceVariant)
          : null,
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }

  // ── Switch tile ──────────────────────────────────────────────────────────
  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    return SwitchListTile(
      secondary: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary, cs.primary.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              fontSize: 14)),
      subtitle: Text(subtitle,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
      value: value,
      onChanged: onChanged,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }

  Future<void> _exportData() async {
    setState(() => _isLoading = true);
    try {
      final filePath = await DataExportService.exportData();
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 12),
                Text(
                  'Export Successful',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your data has been exported successfully!',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'File saved to:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  filePath ?? 'Unknown location',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 12),
                Text(
                  'Export Failed',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Failed to export data:',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange,
          size: 48,
        ),
        title: Text(
          'Clear Local Data',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'This will remove all locally stored data including settings and cached information. '
          'Your data on the server will remain intact. This action cannot be undone.\n\n'
          'Are you sure you want to continue?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await DataExportService.clearAllData();
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 12),
                          Text('Local data cleared successfully'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                  // Reload settings
                  _loadSettings();
                }
              } catch (e) {
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to clear data: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.privacy_tip_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Privacy Policy',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Privacy Matters',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              _buildPrivacySection(
                'Data Collection',
                'We collect only essential information needed to provide our services, including '
                    'your name, email, and attendance records. We do not collect unnecessary personal data.',
              ),
              _buildPrivacySection(
                'Data Usage',
                'Your data is used solely for attendance tracking and reporting purposes. '
                    'We do not sell or share your information with third parties without your explicit consent.',
              ),
              _buildPrivacySection(
                'Data Security',
                'We implement industry-standard security measures to protect your data, including '
                    'encryption, secure authentication, and regular security audits.',
              ),
              _buildPrivacySection(
                'Data Retention',
                'Your data is stored as long as your account is active. You can request data deletion '
                    'at any time by contacting our support team.',
              ),
              _buildPrivacySection(
                'Your Rights',
                'You have the right to access, modify, or delete your personal data. You can export '
                    'your data at any time using the export feature in settings.',
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Last Updated: December 2025',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'For the complete privacy policy, visit:',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'www.eduverse.com/privacy',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  void _showReportProblemDialog() {
    final TextEditingController issueController = TextEditingController();
    final TextEditingController deviceNameController = TextEditingController();
    final List<File> selectedImages = [];
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
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
                              gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF97316)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: const Icon(Icons.bug_report_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Report a Problem', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: cs.onSurface)),
                              Text('Help us improve the app', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                            ]),
                          ),
                          IconButton(onPressed: () => Navigator.pop(sheetCtx), icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('Describe the issue:', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: issueController,
                        maxLines: 4,
                        style: TextStyle(color: cs.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Describe the problem in detail...',
                          hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                          prefixIcon: const Padding(padding: EdgeInsets.only(bottom: 60), child: Icon(Icons.description_rounded)),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: deviceNameController,
                        style: TextStyle(color: cs.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Device Name (Optional)',
                          labelStyle: TextStyle(color: cs.onSurfaceVariant),
                          hintText: 'e.g., Samsung S20 Plus',
                          hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                          prefixIcon: const Icon(Icons.phone_android_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Text('Attach Images (Optional)', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () async {
                              final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                              if (image != null) {
                                setSheetState(() {
                                  if (selectedImages.length < 5) {
                                    selectedImages.add(File(image.path));
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 5 images allowed')));
                                  }
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF4F46E5), size: 18),
                                SizedBox(width: 6),
                                Text('Add', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w600, fontSize: 13)),
                              ]),
                            ),
                          ),
                        ],
                      ),
                      if (selectedImages.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 80,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: selectedImages.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (ctx, index) => Stack(
                              children: [
                                ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(selectedImages[index], width: 80, height: 80, fit: BoxFit.cover)),
                                Positioned(
                                  top: 2, right: 2,
                                  child: GestureDetector(
                                    onTap: () => setSheetState(() => selectedImages.removeAt(index)),
                                    child: Container(
                                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () async {
                          if (issueController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please describe the issue'), backgroundColor: Colors.red));
                            return;
                          }
                          final auth = Provider.of<AuthProvider>(context, listen: false);
                          final userEmail = auth.userEmail;
                          if (userEmail == null || userEmail.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User email not found. Please log in again.'), backgroundColor: Colors.red));
                            return;
                          }
                          Navigator.of(sheetCtx).pop();
                          await _sendReportWithImages(issueController.text.trim(), userEmail, selectedImages, deviceNameController.text.trim());
                        },
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF97316)], begin: Alignment.centerLeft, end: Alignment.centerRight),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 5))],
                          ),
                          child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.send_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 10),
                            Text('Send Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
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

  Future<void> _sendReportWithImages(
    String issueDescription,
    String userEmail,
    List<File> images,
    String? deviceName,
  ) async {
    try {
      await ApiService.submitProblemReport(
        userEmail: userEmail,
        issueDescription: issueDescription,
        appVersion: _currentVersion,
        device: Theme.of(context).platform == TargetPlatform.android
            ? 'Android'
            : Theme.of(context).platform == TargetPlatform.iOS
                ? 'iOS'
                : 'Unknown',
        deviceName: deviceName != null && deviceName.isNotEmpty ? deviceName : null,
        teacherId: Provider.of<AuthProvider>(context, listen: false).teacherId,
        images: images,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  'Problem report submitted${images.isNotEmpty ? ' with ${images.length} image${images.length > 1 ? 's' : ''}' : ''}',
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit problem report: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _showFeatureRequestDialog() {
    final TextEditingController featureController = TextEditingController();
    final TextEditingController bidPriceController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        final cs = Theme.of(sheetCtx).colorScheme;
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
                          gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEF4444)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Request a Feature', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: cs.onSurface)),
                          Text('Share your ideas with us', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        ]),
                      ),
                      IconButton(onPressed: () => Navigator.pop(sheetCtx), icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Describe the feature:', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: featureController,
                    maxLines: 4,
                    style: TextStyle(color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Describe the feature in detail...',
                      hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                      prefixIcon: const Padding(padding: EdgeInsets.only(bottom: 60), child: Icon(Icons.description_rounded)),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: bidPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: cs.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Bid Price (LKR)',
                      labelStyle: TextStyle(color: cs.onSurfaceVariant),
                      hintText: 'Amount you\'re willing to pay',
                      hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                      prefixText: 'LKR  ',
                      prefixIcon: const Icon(Icons.monetization_on_rounded),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Bid price helps prioritize feature development.', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () async {
                      if (featureController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please describe the feature'), backgroundColor: Colors.red));
                        return;
                      }
                      if (bidPriceController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a bid price'), backgroundColor: Colors.red));
                        return;
                      }
                      final bidPrice = double.tryParse(bidPriceController.text.trim());
                      if (bidPrice == null || bidPrice < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid price'), backgroundColor: Colors.red));
                        return;
                      }
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      final userEmail = auth.userEmail;
                      if (userEmail == null || userEmail.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User email not found. Please log in again.'), backgroundColor: Colors.red));
                        return;
                      }
                      Navigator.of(sheetCtx).pop();
                      try {
                        await ApiService.submitFeatureRequest(
                          userEmail: userEmail,
                          featureDescription: featureController.text.trim(),
                          bidPrice: bidPrice,
                          appVersion: _currentVersion,
                          device: Theme.of(context).platform == TargetPlatform.android ? 'Android' : Theme.of(context).platform == TargetPlatform.iOS ? 'iOS' : 'Unknown',
                          teacherId: Provider.of<AuthProvider>(context, listen: false).teacherId,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 12), Text('Feature request submitted successfully')]), backgroundColor: Colors.green));
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit feature request: $e'), backgroundColor: Colors.red));
                        }
                      }
                    },
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEF4444)], begin: Alignment.centerLeft, end: Alignment.centerRight),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 5))],
                      ),
                      child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text('Submit Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
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
  }
}
