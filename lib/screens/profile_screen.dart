import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teacher_attendance/screens/screen_tutorial.dart';
import 'package:teacher_attendance/screens/tutorial_keys.dart';
import 'package:teacher_attendance/screens/tutorial_screen.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/teacher.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/image_storage_service.dart';
import 'account_selection_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  bool _isEditing = false;

  // Tutorial Steps
  final List<STStep> _tutSteps = [
    STStep(
      targetKey: tutorialKeyProfEdit,
      title: 'Edit Profile',
      body: 'Update your name, photo, and other details by tapping here.',
      icon: Icons.edit_rounded,
      accent: const Color(0xFF4F46E5),
    ),
    STStep(
      targetKey: tutorialKeyProfLogout,
      title: 'Logout',
      body: 'Sign out of your account securely from here.',
      icon: Icons.logout_rounded,
      accent: const Color(0xFFE11D48),
    ),
  ];

  Future<void> _maybeShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    if (TutorialScreen.isRunning) return;
    final allSkipped = prefs.getBool('all_tutorials_skipped') ?? false;
    if (allSkipped) return;
    
    final hasSeen = prefs.getBool('tutorial_prof_v1') ?? false;
    if (!hasSeen) {
      if (!mounted) return;
      await prefs.setBool('tutorial_prof_v1', true);
      showSTTutorial(context: context, steps: _tutSteps, prefKey: 'tutorial_prof_v1');
    }
  }

  bool _isLoading = false;
  Teacher? _teacher;
  final ImagePicker _imagePicker = ImagePicker();
  String? _profilePicturePath;
  bool _isNewImage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { _maybeShowTutorial(); });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.teacherData != null) {
      _teacher = Teacher.fromJson(auth.teacherData!);
      _nameController = TextEditingController(
        text: _teacher!.name.isNotEmpty ? _teacher!.name : '',
      );
      _emailController = TextEditingController(
        text: _teacher!.email.isNotEmpty ? _teacher!.email : '',
      );
      _phoneController = TextEditingController(text: _teacher!.phone ?? '');
      _profilePicturePath = _teacher!.profilePicture;
    } else {
      _nameController = TextEditingController(
        text: auth.userName?.isNotEmpty == true ? auth.userName! : '',
      );
      _emailController = TextEditingController(
        text: auth.userEmail?.isNotEmpty == true ? auth.userEmail! : '',
      );
      _phoneController = TextEditingController();
      _profilePicturePath = null;
    }
    // Load fresh teacher data from API
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.teacherId != null) {
      try {
        final teacherData = await ApiService.getTeacher(auth.teacherId!);
        setState(() {
          _teacher = Teacher.fromJson(teacherData);
          _nameController.text = _teacher!.name;
          _emailController.text = _teacher!.email;
          _phoneController.text = _teacher!.phone ?? '';
          _profilePicturePath = _teacher!.profilePicture;
        });
      } catch (e) {
        debugPrint('Failed to load teacher data: $e');
        // Keep existing data if API fails
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Let image_picker handle permissions automatically
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _profilePicturePath = pickedFile.path;
          _isNewImage = true;
        });
      } else {
        // User cancelled or permission was denied
        debugPrint('Image picking was cancelled or permission denied');
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      
      // Check if it's a permission issue
      if (e.toString().contains('photo') || 
          e.toString().contains('Permission') ||
          e.toString().contains('permission')) {
        
        // Check for permanently denied permissions
        bool cameraPermissionDenied = false;
        bool galleryPermissionDenied = false;
        
        if (source == ImageSource.camera) {
          final status = await Permission.camera.status;
          cameraPermissionDenied = status.isPermanentlyDenied;
        } else {
          // Check both photos and storage permissions
          final photosStatus = await Permission.photos.status;
          final storageStatus = await Permission.storage.status;
          galleryPermissionDenied = photosStatus.isPermanentlyDenied || 
                                     storageStatus.isPermanentlyDenied;
        }
        
        if (cameraPermissionDenied || galleryPermissionDenied) {
          if (mounted) {
            _showPermissionDialog(
              source == ImageSource.camera 
                  ? 'Camera Permission Required'
                  : 'Gallery Permission Required',
              'Permission is required to ${source == ImageSource.camera ? "take photos" : "select photos from gallery"}. Please enable it in app settings.',
              'Open Settings',
              () => openAppSettings(),
            );
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _showPermissionDialog(
    String title,
    String message,
    String buttonText,
    VoidCallback onPressed,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onPressed();
              },
              child: Text(buttonText),
            ),
          ],
        );
      },
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text('Change Photo',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 16,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      )),
                  const SizedBox(height: 16),
                  _sheetTile(context, Icons.camera_alt_rounded, 'Take Photo',
                      const Color(0xFF4F46E5), () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.camera);
                  }),
                  const SizedBox(height: 8),
                  _sheetTile(context, Icons.photo_library_rounded,
                      'Choose from Gallery', const Color(0xFF7C3AED), () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.gallery);
                  }),
                  if (_profilePicturePath != null &&
                      _profilePicturePath!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _sheetTile(context, Icons.delete_rounded, 'Remove Photo',
                        Colors.red, () {
                      Navigator.of(context).pop();
                      setState(() {
                        _profilePicturePath = null;
                        _isNewImage = false;
                      });
                    }),
                  ],
                  const SizedBox(height: 8),
                  _sheetTile(context, Icons.cancel_rounded, 'Cancel',
                      Colors.grey, () => Navigator.of(context).pop()),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sheetTile(BuildContext context, IconData icon, String label,
      Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Text(label,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500, fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.teacherId == null) {
        throw Exception('Teacher ID not found');
      }

      String? savedImagePath;

      // Handle profile picture
      if (_profilePicturePath != null && _isNewImage) {
        // This is a newly picked image that needs to be saved
        final imageFile = File(_profilePicturePath!);
        if (await imageFile.exists()) {
          debugPrint('Saving new profile picture...');
          // Delete old profile picture if it exists
          await ImageStorageService.deleteOldProfilePicture(
            _teacher?.profilePicture,
          );

          // Save new profile picture
          savedImagePath = await ImageStorageService.saveProfilePicture(
            imageFile,
            auth.teacherId!,
          );
          debugPrint('New profile picture saved at: $savedImagePath');
        }
      } else {
        // Keep existing profile picture path
        savedImagePath = _profilePicturePath;
        debugPrint('Keeping existing profile picture: $savedImagePath');
      }

      final updatedData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'profilePicture': savedImagePath,
      };

      debugPrint('Updating teacher with data: $updatedData');

      // Call API to update teacher
      final updatedTeacherData = await ApiService.updateTeacher(
        auth.teacherId!,
        updatedData,
      );

      // Debug: Print the API response
      debugPrint('API Response: $updatedTeacherData');

      // Create updated teacher object with proper null handling
      final updatedTeacher = Teacher.fromJson(updatedTeacherData);

      // Debug: Print the teacher object
      debugPrint(
        'Updated Teacher: ${updatedTeacher.name}, ${updatedTeacher.email}, Profile: ${updatedTeacher.profilePicture}',
      );

      // Update local auth provider
      await auth.login(
        updatedTeacher.email.isNotEmpty
            ? updatedTeacher.email
            : auth.userEmail ?? '',
        updatedTeacher.name.isNotEmpty
            ? updatedTeacher.name
            : auth.userName ?? '',
        teacherId: updatedTeacher.teacherId ?? updatedTeacher.id,
        teacherData: updatedTeacher.toJson(),
      );

      if (mounted) {
        setState(() {
          _teacher = updatedTeacher;
          _profilePicturePath = updatedTeacher.profilePicture;
          _isNewImage = false;
          _isEditing = false;
        });
        debugPrint('State updated with new profile picture: $_profilePicturePath');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Profile updated successfully'),
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
      debugPrint('Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final displayName = _teacher?.name ?? auth.userName ?? 'Teacher';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'T';

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0E17) : const Color(0xFFF5F5FA),
      body: CustomScrollView(
        slivers: [
          // ── Gradient Hero Header ─────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: const Color(0xFF3730A3),
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              if (!_isEditing)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                  ),
                  onPressed: () => setState(() => _isEditing = true),
                  tooltip: 'Edit Profile',
                )
              else ...[
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () {
                    if (_teacher != null) {
                      _nameController.text = _teacher!.name;
                      _emailController.text = _teacher!.email;
                      _phoneController.text = _teacher!.phone ?? '';
                      _profilePicturePath = _teacher!.profilePicture;
                      _isNewImage = false;
                    }
                    setState(() => _isEditing = false);
                  },
                  tooltip: 'Cancel',
                ),
                IconButton(
                  icon: const Icon(Icons.check_rounded, color: Colors.white),
                  onPressed: _isLoading ? null : _updateProfile,
                  tooltip: 'Save Changes',
                ),
              ],
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF3730A3), Color(0xFF6D28D9), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 48),
                      // Avatar
                      GestureDetector(
                        onTap: _isEditing ? _showImagePickerOptions : null,
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: _profilePicturePath != null &&
                                      _profilePicturePath!.isNotEmpty
                                  ? ClipOval(
                                      child: _profilePicturePath!.startsWith('/')
                                          ? Image.file(
                                              File(_profilePicturePath!),
                                              key: ValueKey(_profilePicturePath),
                                              fit: BoxFit.cover,
                                              width: 100,
                                              height: 100,
                                              errorBuilder: (_, __, ___) => Center(
                                                child: Text(initial,
                                                    style: GoogleFonts.poppins(
                                                        fontSize: 40,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white)),
                                              ),
                                            )
                                          : Image.network(
                                              _profilePicturePath!,
                                              key: ValueKey(_profilePicturePath),
                                              fit: BoxFit.cover,
                                              width: 100,
                                              height: 100,
                                              cacheWidth: 200,
                                              errorBuilder: (_, __, ___) => Center(
                                                child: Text(initial,
                                                    style: GoogleFonts.poppins(
                                                        fontSize: 40,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white)),
                                              ),
                                              loadingBuilder: (_, child, progress) {
                                                if (progress == null) return child;
                                                return Center(
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white.withValues(alpha: 0.8),
                                                  ),
                                                );
                                              },
                                            ),
                                    )
                                  : Center(
                                      child: Text(initial,
                                          style: GoogleFonts.poppins(
                                              fontSize: 40,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white)),
                                    ),
                            ),
                            if (_isEditing) ...[
                              if (_profilePicturePath != null &&
                                  _profilePicturePath!.isNotEmpty)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () => setState(
                                        () => _profilePicturePath = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(Icons.close,
                                          size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                          color: const Color(0xFF4F46E5)
                                              .withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3)),
                                    ],
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded,
                                      size: 16, color: Colors.white),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        displayName,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (_teacher?.email != null || auth.userEmail != null)
                        Text(
                          _teacher?.email ?? auth.userEmail ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Body Content ─────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Loading bar
                if (_isLoading)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation(
                                Color(0xFF4F46E5)),
                            backgroundColor:
                                const Color(0xFF4F46E5).withValues(alpha: 0.2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('Updating profile...',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF4F46E5),
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),

                // ── Section label ────────────────────────────────────────
                _sectionLabel('Personal Information'),
                const SizedBox(height: 10),

                // ── Profile Form Card ────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            )
                          ],
                    border: isDark
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.06))
                        : null,
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _premiumField(
                          context,
                          controller: _nameController,
                          label: 'Full Name',
                          icon: Icons.person_outline_rounded,
                          enabled: _isEditing,
                          gradient: const [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Name is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _premiumField(
                          context,
                          controller: _emailController,
                          label: 'Email Address',
                          icon: Icons.email_outlined,
                          enabled: _isEditing,
                          keyboardType: TextInputType.emailAddress,
                          gradient: const [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Email is required';
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(v)) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _premiumField(
                          context,
                          controller: _phoneController,
                          label: 'Phone Number',
                          icon: Icons.phone_outlined,
                          enabled: _isEditing,
                          keyboardType: TextInputType.phone,
                          gradient: const [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        if (_teacher?.teacherId != null) ...[
                          const SizedBox(height: 16),
                          _premiumReadOnly(
                            context,
                            value: _teacher!.teacherId!,
                            label: 'Teacher ID',
                            icon: Icons.badge_outlined,
                            gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Status badge
                if (_teacher?.status != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _teacher!.status == 'active'
                          ? Colors.green.withValues(alpha: isDark ? 0.2 : 0.1)
                          : Colors.orange.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _teacher!.status == 'active'
                            ? Colors.green.withValues(alpha: 0.4)
                            : Colors.orange.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _teacher!.status == 'active'
                              ? Icons.check_circle_rounded
                              : Icons.pause_circle_rounded,
                          size: 16,
                          color: _teacher!.status == 'active'
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Account Status: ${_teacher!.status.toUpperCase()}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: _teacher!.status == 'active'
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Save button when editing
                if (_isEditing) ...[
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _isLoading ? null : _updateProfile,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: _isLoading
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                        color: _isLoading
                            ? cs.onSurface.withValues(alpha: 0.12)
                            : null,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _isLoading
                            ? []
                            : [
                                BoxShadow(
                                  color: const Color(0xFF4F46E5)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                )
                              ],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.save_rounded,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Text('Save Changes',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // ── Account Section ──────────────────────────────────────
                _sectionLabel('Account'),
                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            )
                          ],
                    border: isDark
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.06))
                        : null,
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logout button
                      GestureDetector(
                        onTap: () async {
                          final auth = Provider.of<AuthProvider>(context,
                              listen: false);
                          await auth.logout();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const AccountSelectionScreen(),
                              ),
                              (route) => false,
                            );
                          }
                        },
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFDC2626)
                                    .withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.logout_rounded,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Text('Logout',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
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
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4F46E5),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
    required List<Color> gradient,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: TextStyle(
        color: cs.onSurface,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13),
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFF4F46E5), width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        filled: !enabled,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }

  Widget _premiumReadOnly(
    BuildContext context, {
    required String value,
    required String label,
    required IconData icon,
    required List<Color> gradient,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      initialValue: value,
      enabled: false,
      style: TextStyle(
        color: cs.onSurface.withValues(alpha: 0.6),
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.5), fontSize: 13),
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
