import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/storage_service.dart';

class DriverImageUploadDialog extends StatefulWidget {
  const DriverImageUploadDialog({super.key});

  @override
  State<DriverImageUploadDialog> createState() =>
      _DriverImageUploadDialogState();
}

class _DriverImageUploadDialogState extends State<DriverImageUploadDialog> {
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;
  File? _licenseImage;
  Uint8List? _profileBytes;
  Uint8List? _licenseBytes;
  String? _profileExt;
  String? _licenseExt;
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.photo_camera, color: Colors.amber, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Upload Driver Images',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Please upload your profile picture and license ID card image',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 20),

              // Profile Picture Section
              _buildImageSection(
                title: 'Profile Picture',
                subtitle: 'Upload a clear photo of yourself',
                image: _profileImage,
                onTap: () => _pickImage(ImageSource.gallery, true),
              ),

              const SizedBox(height: 16),

              // License Image Section
              _buildImageSection(
                title: 'License ID Card',
                subtitle: 'Upload a clear photo of your driving license',
                image: _licenseImage,
                onTap: () => _pickImage(ImageSource.gallery, false),
              ),

              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canUpload() && !_isUploading
                      ? _uploadImages
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isUploading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.black,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Submitting...'),
                          ],
                        )
                      : const Text(
                          'Submit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection({
    required String title,
    required String subtitle,
    required File? image,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 12),

          if ((image != null && !kIsWeb) ||
              (kIsWeb &&
                  ((title == 'Profile Picture' && _profileBytes != null) ||
                      (title == 'License ID Card' &&
                          _licenseBytes != null)))) ...[
            // Show selected image
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: kIsWeb
                    ? Image.memory(
                        title == 'Profile Picture'
                            ? (_profileBytes ?? Uint8List(0))
                            : (_licenseBytes ?? Uint8List(0)),
                        fit: BoxFit.cover,
                      )
                    : Image.file(image!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Change'),
                style: TextButton.styleFrom(foregroundColor: Colors.amber),
              ),
            ),
          ] else ...[
            // Show upload options
            GestureDetector(
              onTap: onTap,
              child: Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 28,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap to select image',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.photo_library, size: 16),
              label: const Text('Gallery'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.amber,
                side: const BorderSide(color: Colors.amber),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, bool isProfileImage) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        File? file;
        Uint8List? bytes;
        if (kIsWeb) {
          bytes = await pickedFile.readAsBytes();
        } else {
          file = File(pickedFile.path);
        }

        // Validate picked file using MIME type first, then extension fallback
        final mimeType = pickedFile.mimeType ?? '';
        final isImageByMime = mimeType.startsWith('image/');
        final extension = path.extension(pickedFile.name).toLowerCase();
        const allowedExtensions = [
          '.jpg',
          '.jpeg',
          '.png',
          '.webp',
          '.heic',
          '.heif',
        ];
        final isImageByExt = allowedExtensions.contains(extension);

        if (!(isImageByMime || isImageByExt)) {
          _showErrorSnackBar(
            'Please select a valid image (JPG, JPEG, PNG, WebP)',
          );
          return;
        }

        // Check file size (max 5MB)
        final sizeInMB = kIsWeb
            ? StorageService.getImageSizeInMBFromBytes(bytes!)
            : await StorageService.getImageSizeInMB(file!);
        if (sizeInMB > 5.0) {
          _showErrorSnackBar('Image size should be less than 5MB');
          return;
        }

        setState(() {
          if (isProfileImage) {
            _profileImage = file;
            _profileBytes = bytes;
            _profileExt = extension;
          } else {
            _licenseImage = file;
            _licenseBytes = bytes;
            _licenseExt = extension;
          }
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking image: $e');
    }
  }

  bool _canUpload() {
    if (kIsWeb) {
      return _profileBytes != null && _licenseBytes != null;
    }
    return _profileImage != null && _licenseImage != null;
  }

  Future<void> _uploadImages() async {
    if (!_canUpload()) return;

    setState(() {
      _isUploading = true;
    });

    try {
      // Upload images to Firebase Storage
      Map<String, String?> imageUrls;
      if (kIsWeb) {
        final profileUrl = await StorageService.uploadProfilePictureBytes(
          _profileBytes!,
          _profileExt ?? '.jpg',
        ).timeout(const Duration(seconds: 30));
        final licenseUrl = await StorageService.uploadLicenseImageBytes(
          _licenseBytes!,
          _licenseExt ?? '.jpg',
        ).timeout(const Duration(seconds: 30));
        imageUrls = {
          'profileImageUrl': profileUrl,
          'licenseImageUrl': licenseUrl,
        };
      } else {
        imageUrls = await StorageService.uploadDriverImages(
          profileImage: _profileImage,
          licenseImage: _licenseImage,
        ).timeout(const Duration(seconds: 30));
      }

      // Ensure both uploads succeeded
      if ((imageUrls['profileImageUrl'] == null ||
              (imageUrls['profileImageUrl'] ?? '').isEmpty) ||
          (imageUrls['licenseImageUrl'] == null ||
              (imageUrls['licenseImageUrl'] ?? '').isEmpty)) {
        _showErrorSnackBar('Upload failed. Please try again.');
        if (kDebugMode) {
          // ignore: avoid_print
          print('Upload result: $imageUrls');
        }
        return;
      }

      // Update driver data in Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final updateData = <String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
        };

        updateData['profileImageUrl'] = imageUrls['profileImageUrl'];
        updateData['licenseImageUrl'] = imageUrls['licenseImageUrl'];

        // Update both users and drivers collections atomically
        final batch = FirebaseFirestore.instance.batch();
        final usersDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);
        final driversDoc = FirebaseFirestore.instance
            .collection('drivers')
            .doc(user.uid);
        batch.set(usersDoc, updateData, SetOptions(merge: true));
        batch.set(driversDoc, updateData, SetOptions(merge: true));
        await batch.commit().timeout(const Duration(seconds: 20));

        if (mounted) {
          // Show success first, then close the dialog to avoid disposed context
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Images uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          await Future.delayed(const Duration(milliseconds: 250));
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      }
    } on TimeoutException catch (_) {
      _showErrorSnackBar('Network timeout. Please try again.');
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error uploading images: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
