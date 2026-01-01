import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/image_service.dart';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final authService = AuthService();
  final imageService = ImageService();
  final storageService = StorageService();
  final firestoreService = FirestoreService();

  bool _isUploading = false;
  String? _profilePhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadProfilePhoto();
  }

  Future<void> _loadProfilePhoto() async {
    if (user != null) {
      try {
        final profile = await firestoreService.getUserProfile(user!.uid);
        if (profile != null && mounted) {
          setState(() {
            _profilePhotoUrl = profile.photoURL;
          });
        }
      } catch (e) {
        print('Error loading profile: $e');
        // Se não existe perfil, não faz nada
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _updateProfilePicture(useCamera: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _updateProfilePicture(useCamera: false);
              },
            ),
            if (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteProfilePicture();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateProfilePicture({required bool useCamera}) async {
    setState(() => _isUploading = true);

    try {
      // Step 1: Pick image
      File? imageFile;
      if (useCamera) {
        imageFile = await imageService.pickImageFromCamera();
      } else {
        imageFile = await imageService.pickImageFromGallery();
      }

      if (imageFile == null) {
        setState(() => _isUploading = false);
        return;
      }

      print('Image picked: ${imageFile.path}');

      // Step 2: Upload to Storage
      final downloadUrl = await storageService.uploadProfilePicture(
        imageFile,
        onProgress: (progress) {
          print('Upload progress: ${(progress * 100).toInt()}%');
        },
      );

      if (downloadUrl == null) {
        throw Exception('Failed to upload image');
      }

      print('Upload successful: $downloadUrl');

      // Step 3: Update Firestore (ou criar se não existe)
      if (user != null) {
        try {
          // Tentar atualizar
          await firestoreService.updateUserProfile(user!.uid, {
            'photoURL': downloadUrl,
          });
        } catch (e) {
          print('Profile does not exist, creating...');
          // Se não existe, criar
          await firestoreService.createUserProfile(
            userId: user!.uid,
            email: user!.email ?? '',
            displayName: user!.displayName,
            photoURL: downloadUrl,
          );
        }

        setState(() {
          _profilePhotoUrl = downloadUrl;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('Error updating profile picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteProfilePicture() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile Picture?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUploading = true);

    try {
      // Delete from Storage
      await storageService.deleteProfilePicture();

      // Update Firestore
      if (user != null) {
        await firestoreService.updateUserProfile(user!.uid, {
          'photoURL': '',
        });

        setState(() {
          _profilePhotoUrl = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture removed'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  String _getAuthProvider() {
    if (user == null) return 'Unknown';

    if (user!.providerData.isNotEmpty) {
      final providerId = user!.providerData.first.providerId;
      if (providerId == 'password') {
        return 'Email/Password';
      } else if (providerId == 'google.com') {
        return 'Google';
      }
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No user logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Profile Picture with Edit Button
            Stack(
              children: [
                // Profile Picture - CLICÁVEL!
                GestureDetector(
                  onTap: _isUploading ? null : _showImageSourceDialog,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).primaryColor.withOpacity(0.3),
                        width: 3,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 70,
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      backgroundImage: _profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
                          ? NetworkImage(_profilePhotoUrl!)
                          : null,
                      child: _isUploading
                          ? const CircularProgressIndicator()
                          : (_profilePhotoUrl == null || _profilePhotoUrl!.isEmpty)
                          ? Icon(
                        Icons.person,
                        size: 70,
                        color: Theme.of(context).primaryColor,
                      )
                          : null,
                    ),
                  ),
                ),

                // Edit Button
                if (!_isUploading)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _showImageSourceDialog,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // Hint text
            Text(
              'Tap to change photo',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 16),

            // Display Name
            if (user!.displayName != null) ...[
              Text(
                user!.displayName!,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Email
            Text(
              user!.email ?? 'No email',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 32),

            // Account Information Card
            Card(
              elevation: 2,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.email, color: Theme.of(context).primaryColor),
                    title: const Text('Email'),
                    subtitle: Text(user!.email ?? 'Not available'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.login, color: Theme.of(context).primaryColor),
                    title: const Text('Sign-in Method'),
                    subtitle: Text(_getAuthProvider()),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      user!.emailVerified ? Icons.verified : Icons.warning,
                      color: user!.emailVerified ? Colors.green : Colors.orange,
                    ),
                    title: const Text('Email Verification'),
                    subtitle: Text(
                      user!.emailVerified ? 'Verified' : 'Not verified',
                    ),
                    trailing: !user!.emailVerified && _getAuthProvider() == 'Email/Password'
                        ? TextButton(
                      onPressed: () async {
                        await user!.sendEmailVerification();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Verification email sent!'),
                            ),
                          );
                        }
                      },
                      child: const Text('Verify'),
                    )
                        : null,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.calendar_today, color: Theme.of(context).primaryColor),
                    title: const Text('Account Created'),
                    subtitle: Text(
                      user!.metadata.creationTime != null
                          ? '${user!.metadata.creationTime!.day}/${user!.metadata.creationTime!.month}/${user!.metadata.creationTime!.year}'
                          : 'Unknown',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Sign Out'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Sign Out',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await authService.signOut();
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}