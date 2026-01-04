import 'package:flutter/material.dart';
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

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Icon(
              Icons.system_update_alt,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Update Available',
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
              'A new version (${updateInfo.version}) is available!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            if (updateInfo.releaseNotes.isNotEmpty) ...[
              Text(
                'What\'s New:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                updateInfo.releaseNotes,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'Current version: $_currentVersion',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(
                      isDark ? 0.7 : 0.6,
                    ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Later',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _downloadAndInstallUpdate(updateInfo);
            },
            child: const Text('Install Now'),
          ),
        ],
      ),
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
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Section
            _buildSectionHeader('Account'),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.person_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Profile Information'),
                    subtitle: Text(auth.userName ?? 'Not set'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.email_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Email'),
                    subtitle: Text(auth.userEmail ?? 'Not set'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.devices,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Linked Devices'),
                    subtitle: const Text('Manage web sessions'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const LinkedDevicesScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Preferences Section
            _buildSectionHeader('Preferences'),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Notifications
                  SwitchListTile(
                    secondary: Icon(
                      Icons.notifications_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Push Notifications'),
                    subtitle: const Text(
                      'Receive notifications for important updates',
                    ),
                    value: _notificationsEnabled,
                    onChanged: _isLoading
                        ? null
                        : (value) =>
                            _updateSetting('notifications_enabled', value),
                  ),
                  const Divider(height: 1),

                  // Dark Mode
                  SwitchListTile(
                    secondary: Icon(
                      _darkMode ? Icons.dark_mode : Icons.light_mode,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Dark Mode'),
                    subtitle: const Text(
                      'Switch between light and dark themes',
                    ),
                    value: _darkMode,
                    onChanged: _isLoading
                        ? null
                        : (value) => _updateSetting('dark_mode', value),
                  ),
                  const Divider(height: 1),

                  // Auto Backup
                  SwitchListTile(
                    secondary: Icon(
                      Icons.backup_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Auto Backup'),
                    subtitle: const Text('Automatically backup data to local device'),
                    value: _autoBackup,
                    onChanged: _isLoading
                        ? null
                        : (value) => _updateSetting('auto_backup', value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Data & Privacy Section
            _buildSectionHeader('Data & Privacy'),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.backup,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Backup & Restore'),
                    subtitle: const Text('Manage local backups'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const BackupRestoreScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.download_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Export Data'),
                    subtitle: const Text('Download your data in JSON format'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _exportData(),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text('Clear Local Data'),
                    subtitle: const Text('Remove all locally stored data'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showClearDataDialog(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // About Section
            _buildSectionHeader('About'),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('App Version'),
                    subtitle: Text(_currentVersion),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: _checkingUpdate
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.system_update_alt,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    title: const Text('Check for Updates'),
                    subtitle: const Text('Download the latest version'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _checkingUpdate ? null : _checkForUpdates,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.report_problem_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Report a Problem'),
                    subtitle: const Text('Report issues or bugs'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showReportProblemDialog(),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.lightbulb_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Request a Feature'),
                    subtitle: const Text('Suggest new features'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showFeatureRequestDialog(),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.privacy_tip_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Privacy Policy'),
                    subtitle: const Text('Read our privacy policy'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showPrivacyPolicy(),
                  ),
                ],
              ),
            ),

            // Loading indicator
            if (_isLoading)
              Container(
                margin: const EdgeInsets.only(top: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
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
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
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
                    ).colorScheme.onSurface.withOpacity(0.7),
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

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.help_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Help & Support',
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
                'Need assistance? We\'re here to help!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              _buildContactItem(Icons.email, 'Email', 'support@eduverse.com'),
              const SizedBox(height: 12),
              _buildContactItem(Icons.phone, 'Phone', '+1 (555) 123-4567'),
              const SizedBox(height: 12),
              _buildContactItem(
                Icons.language,
                'Website',
                'www.eduverse.com/support',
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Office Hours',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Monday - Friday: 9:00 AM - 6:00 PM',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                'Saturday: 10:00 AM - 4:00 PM',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                'Sunday: Closed',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Response Time',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We typically respond within 24 hours during business days.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
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

  Widget _buildContactItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
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
    final List<File> selectedImages = [];
    final ImagePicker _picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.report_problem_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                'Report a Problem',
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
                  'Please describe the issue you\'re experiencing:',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: issueController,
                  maxLines: 4,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Describe the problem in detail...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2)
                        : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Attach Images (Optional):',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                // Image picker buttons
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final XFile? image = await _picker.pickImage(
                          source: ImageSource.camera,
                          imageQuality: 80,
                        );
                        if (image != null) {
                          setState(() {
                            if (selectedImages.length < 5) {
                              selectedImages.add(File(image.path));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Maximum 5 images allowed'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          });
                        }
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final XFile? image = await _picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80,
                        );
                        if (image != null) {
                          setState(() {
                            if (selectedImages.length < 5) {
                              selectedImages.add(File(image.path));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Maximum 5 images allowed'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          });
                        }
                      },
                      icon: const Icon(Icons.image),
                      label: const Text('Gallery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                if (selectedImages.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Selected Images (${selectedImages.length}/5):',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: selectedImages.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  selectedImages[index],
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: -8,
                                right: -8,
                                child: IconButton(
                                  icon: const Icon(Icons.close),
                                  color: Colors.red,
                                  onPressed: () {
                                    setState(() {
                                      selectedImages.removeAt(index);
                                    });
                                  },
                                  iconSize: 20,
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (issueController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please describe the issue'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                  return;
                }

                final auth = Provider.of<AuthProvider>(context, listen: false);
                final userEmail = auth.userEmail;

                if (userEmail == null || userEmail.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('User email not found. Please log in again.'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                  return;
                }

                Navigator.of(context).pop();
                await _sendReportWithImages(
                  issueController.text.trim(),
                  userEmail,
                  selectedImages,
                );
              },
              child: const Text('Send Report'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendReportWithImages(
    String issueDescription,
    String userEmail,
    List<File> images,
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

  Future<void> _sendReportEmail(String issueDescription, String userEmail) async {
    // Keep this method for backward compatibility if needed
    await _sendReportWithImages(issueDescription, userEmail, []);
  }

  void _showFeatureRequestDialog() {
    final TextEditingController featureController = TextEditingController();
    final TextEditingController bidPriceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.lightbulb_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Request a Feature',
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
                'Describe the feature you would like:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: featureController,
                maxLines: 4,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Describe the feature in detail...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2)
                      : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Bid Price (LKR):',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bidPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter amount you\'re willing to pay',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                  prefixText: 'LKR ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2)
                      : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The bid price helps prioritize feature development.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (featureController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please describe the feature'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
                return;
              }

              if (bidPriceController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please enter a bid price'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
                return;
              }

              final bidPrice = double.tryParse(bidPriceController.text.trim());
              if (bidPrice == null || bidPrice < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please enter a valid price'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
                return;
              }

              final auth = Provider.of<AuthProvider>(context, listen: false);
              final userEmail = auth.userEmail;

              if (userEmail == null || userEmail.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('User email not found. Please log in again.'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
                return;
              }

              Navigator.of(context).pop();
              
              try {
                await ApiService.submitFeatureRequest(
                  userEmail: userEmail,
                  featureDescription: featureController.text.trim(),
                  bidPrice: bidPrice,
                  appVersion: _currentVersion,
                  device: Theme.of(context).platform == TargetPlatform.android ? 'Android' : 
                          Theme.of(context).platform == TargetPlatform.iOS ? 'iOS' : 'Unknown',
                  teacherId: Provider.of<AuthProvider>(context, listen: false).teacherId,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 12),
                          Text('Feature request submitted successfully'),
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
                      content: Text('Failed to submit feature request: $e'),
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
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }
}
