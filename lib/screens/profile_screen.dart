import 'package:flutter/material.dart';
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
  bool _isLoading = false;
  Teacher? _teacher;
  final ImagePicker _imagePicker = ImagePicker();
  String? _profilePicturePath;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.teacherData != null) {
      _teacher = Teacher.fromJson(auth.teacherData!);
      _nameController = TextEditingController(text: _teacher!.name.isNotEmpty ? _teacher!.name : '');
      _emailController = TextEditingController(text: _teacher!.email.isNotEmpty ? _teacher!.email : '');
      _phoneController = TextEditingController(text: _teacher!.phone ?? '');
      _profilePicturePath = _teacher!.profilePicture;
    } else {
      _nameController = TextEditingController(text: auth.userName?.isNotEmpty == true ? auth.userName! : '');
      _emailController = TextEditingController(text: auth.userEmail?.isNotEmpty == true ? auth.userEmail! : '');
      _phoneController = TextEditingController();
      _profilePicturePath = null;
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
      // Request permissions if needed
      PermissionStatus permissionStatus;

      if (source == ImageSource.camera) {
        permissionStatus = await Permission.camera.request();
        if (permissionStatus.isPermanentlyDenied) {
          if (mounted) {
            _showPermissionDialog(
              'Camera Permission Required',
              'Camera permission is permanently denied. Please enable it in app settings.',
              'Open Settings',
              () => openAppSettings(),
            );
          }
          return;
        } else if (!permissionStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Camera permission is required to take photos')),
            );
          }
          return;
        }
      } else if (source == ImageSource.gallery) {
        // Try photos permission first (for Android 13+ and iOS)
        permissionStatus = await Permission.photos.request();

        // If photos permission is denied, try storage permission (for older Android)
        if (!permissionStatus.isGranted) {
          permissionStatus = await Permission.storage.request();
        }

        if (permissionStatus.isPermanentlyDenied) {
          if (mounted) {
            _showPermissionDialog(
              'Gallery Permission Required',
              'Gallery permission is permanently denied. Please enable it in app settings.',
              'Open Settings',
              () => openAppSettings(),
            );
          }
          return;
        } else if (!permissionStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gallery permission is required to select photos')),
            );
          }
          return;
        }
      }

      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _profilePicturePath = pickedFile.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _showPermissionDialog(String title, String message, String buttonText, VoidCallback onPressed) {
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
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
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
      if (_profilePicturePath != null && !_profilePicturePath!.startsWith('/')) {
        // This is a newly picked image that needs to be saved
        final imageFile = File(_profilePicturePath!);
        if (await imageFile.exists()) {
          // Delete old profile picture if it exists
          await ImageStorageService.deleteOldProfilePicture(_teacher?.profilePicture);

          // Save new profile picture
          savedImagePath = await ImageStorageService.saveProfilePicture(imageFile, auth.teacherId!);
        }
      } else {
        // Keep existing profile picture path
        savedImagePath = _profilePicturePath;
      }

      final updatedData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'profilePicture': savedImagePath,
      };

      // Call API to update teacher
      final updatedTeacherData = await ApiService.updateTeacher(auth.teacherId!, updatedData);

      // Debug: Print the API response
      debugPrint('API Response: $updatedTeacherData');

      // Create updated teacher object with proper null handling
      final updatedTeacher = Teacher.fromJson(updatedTeacherData);

      // Debug: Print the teacher object
      debugPrint('Updated Teacher: ${updatedTeacher.name}, ${updatedTeacher.email}');

      // Update local auth provider
      await auth.login(
        updatedTeacher.email.isNotEmpty ? updatedTeacher.email : auth.userEmail ?? '',
        updatedTeacher.name.isNotEmpty ? updatedTeacher.name : auth.userName ?? '',
        teacherId: updatedTeacher.teacherId ?? updatedTeacher.id,
        teacherData: updatedTeacher.toJson(),
      );

      setState(() {
        _teacher = updatedTeacher;
        _profilePicturePath = updatedTeacher.profilePicture;
        _isEditing = false;
      });

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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        elevation: 0,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit Profile',
            )
          else
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.cancel),
                  onPressed: () {
                    // Reset form
                    if (_teacher != null) {
                      _nameController.text = _teacher!.name;
                      _emailController.text = _teacher!.email;
                      _phoneController.text = _teacher!.phone ?? '';
                      _profilePicturePath = _teacher!.profilePicture;
                    }
                    setState(() => _isEditing = false);
                  },
                  tooltip: 'Cancel',
                ),
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _isLoading ? null : _updateProfile,
                  tooltip: 'Save Changes',
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Avatar
            GestureDetector(
              onTap: _isEditing ? _showImagePickerOptions : null,
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: _profilePicturePath != null && _profilePicturePath!.isNotEmpty
                        ? ClipOval(
                            child: _profilePicturePath!.startsWith('/')
                                ? Image.file(
                                    File(_profilePicturePath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Theme.of(context).colorScheme.onPrimary,
                                      );
                                    },
                                  )
                                : Image.network(
                                    _profilePicturePath!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Theme.of(context).colorScheme.onPrimary,
                                      );
                                    },
                                  ),
                          )
                        : Icon(
                            Icons.person,
                            size: 60,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                  ),
                  if (_isEditing)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Profile Form
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name Field
                      TextFormField(
                        controller: _nameController,
                        enabled: _isEditing,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: !_isEditing,
                          fillColor: _isEditing
                              ? null
                              : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        enabled: _isEditing,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: !_isEditing,
                          fillColor: _isEditing
                              ? null
                              : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Phone Field
                      TextFormField(
                        controller: _phoneController,
                        enabled: _isEditing,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          prefixIcon: Icon(
                            Icons.phone_outlined,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: !_isEditing,
                          fillColor: _isEditing
                              ? null
                              : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Teacher ID (Read-only)
                      if (_teacher?.teacherId != null)
                        TextFormField(
                          initialValue: _teacher!.teacherId,
                          enabled: false,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Teacher ID',
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            prefixIcon: Icon(
                              Icons.badge_outlined,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          ),
                        ),

                      // Status (Read-only)
                      if (_teacher?.status != null)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _teacher!.status == 'active'
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _teacher!.status == 'active'
                                  ? Colors.green
                                  : Colors.orange,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _teacher!.status == 'active'
                                    ? Icons.check_circle
                                    : Icons.pause_circle,
                                size: 16,
                                color: _teacher!.status == 'active'
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Status: ${_teacher!.status.toUpperCase()}',
                                style: TextStyle(
                                  color: _teacher!.status == 'active'
                                      ? Colors.green
                                      : Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Account Actions
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final auth = Provider.of<AuthProvider>(context, listen: false);
                          await auth.logout();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const AccountSelectionScreen(),
                              ),
                              (route) => false,
                            );
                          }
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(context).colorScheme.onError,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
                      'Updating profile...',
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
}