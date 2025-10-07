import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cloudinary configuration (provided by user)
  // Note: For production, do NOT commit secrets. Use environment configs.
  static const String _cloudinaryCloudName = 'dgvz1qkgy';
  static const String _cloudinaryApiKey = '334918734196399';
  static const String _cloudinaryApiSecret = 'sZdzjfj_C8aO1qcpjFi8kNPmR3o';

  static Uri _cloudinaryUploadUri([String? folder]) {
    final base =
        'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload';
    return Uri.parse(base);
  }

  static Future<String?> _uploadToCloudinaryBytes({
    required Uint8List data,
    required String fileName,
    String? folder,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final paramsToSign = {
        if (folder != null && folder.isNotEmpty) 'folder': folder,
        'timestamp': timestamp.toString(),
      };
      final signatureBase = paramsToSign.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final sigString =
          signatureBase.map((e) => '${e.key}=${e.value}').join('&') +
          _cloudinaryApiSecret;
      final signature = sha1.convert(utf8.encode(sigString)).toString();

      final request = http.MultipartRequest(
        'POST',
        _cloudinaryUploadUri(folder),
      );
      request.fields['api_key'] = _cloudinaryApiKey;
      request.fields['timestamp'] = timestamp.toString();
      if (folder != null && folder.isNotEmpty) {
        request.fields['folder'] = folder;
      }
      request.fields['signature'] = signature;
      request.files.add(
        http.MultipartFile.fromBytes('file', data, filename: fileName),
      );

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        return body['secure_url'] as String? ?? body['url'] as String?;
      } else {
        // Print response for debugging unauthorized or other errors
        try {
          final body = resp.body.isNotEmpty ? resp.body : '';
          // ignore: avoid_print
          print('Cloudinary upload failed (${resp.statusCode}): $body');
        } catch (_) {}
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<String?> _uploadToCloudinaryFile({
    required File file,
    required String fileName,
    String? folder,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      return _uploadToCloudinaryBytes(
        data: bytes,
        fileName: fileName,
        folder: folder,
      );
    } catch (e) {
      return null;
    }
  }

  static String _contentTypeForExt(String ext) {
    final e = ext.toLowerCase().replaceAll('.', '');
    switch (e) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'image/*';
    }
  }

  // Upload profile picture
  static Future<String?> uploadProfilePicture(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final fileName =
          'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';

      // Prefer Cloudinary upload
      final url = await _uploadToCloudinaryFile(
        file: imageFile,
        fileName: fileName,
        folder: 'driver_images/profile_pictures',
      );

      return url;
    } catch (e) {
      print('❌ Error uploading profile picture: $e');
      return null;
    }
  }

  // Web: upload profile bytes
  static Future<String?> uploadProfilePictureBytes(
    Uint8List data,
    String extension,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final normalizedExt = extension.startsWith('.')
          ? extension
          : '.$extension';
      final fileName =
          'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}$normalizedExt';

      final url = await _uploadToCloudinaryBytes(
        data: data,
        fileName: fileName,
        folder: 'driver_images/profile_pictures',
      );
      return url;
    } catch (e) {
      print('❌ Error uploading profile bytes: $e');
      return null;
    }
  }

  // Upload license image
  static Future<String?> uploadLicenseImage(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final fileName =
          'license_${user.uid}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';

      final url = await _uploadToCloudinaryFile(
        file: imageFile,
        fileName: fileName,
        folder: 'driver_images/license_images',
      );
      return url;
    } catch (e) {
      print('❌ Error uploading license image: $e');
      return null;
    }
  }

  // Web: upload license bytes
  static Future<String?> uploadLicenseImageBytes(
    Uint8List data,
    String extension,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final normalizedExt = extension.startsWith('.')
          ? extension
          : '.$extension';
      final fileName =
          'license_${user.uid}_${DateTime.now().millisecondsSinceEpoch}$normalizedExt';

      final url = await _uploadToCloudinaryBytes(
        data: data,
        fileName: fileName,
        folder: 'driver_images/license_images',
      );
      return url;
    } catch (e) {
      print('❌ Error uploading license bytes: $e');
      return null;
    }
  }

  // Upload both images and return URLs
  static Future<Map<String, String?>> uploadDriverImages({
    required File? profileImage,
    required File? licenseImage,
  }) async {
    final Map<String, String?> result = {
      'profileImageUrl': null,
      'licenseImageUrl': null,
    };

    try {
      // Upload profile picture if provided
      if (profileImage != null) {
        result['profileImageUrl'] = await uploadProfilePicture(profileImage);
      }

      // Upload license image if provided
      if (licenseImage != null) {
        result['licenseImageUrl'] = await uploadLicenseImage(licenseImage);
      }

      return result;
    } catch (e) {
      print('❌ Error uploading driver images: $e');
      return result;
    }
  }

  // Delete old images when updating
  static Future<void> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      print('✅ Image deleted successfully: $imageUrl');
    } catch (e) {
      print('❌ Error deleting image: $e');
    }
  }

  // Get image size in MB
  static Future<double> getImageSizeInMB(File imageFile) async {
    try {
      final bytes = await imageFile.length();
      return bytes / (1024 * 1024);
    } catch (e) {
      print('❌ Error getting image size: $e');
      return 0.0;
    }
  }

  // Web: size from bytes
  static double getImageSizeInMBFromBytes(Uint8List data) {
    return data.lengthInBytes / (1024 * 1024);
  }

  // Validate image file
  static bool validateImageFile(File imageFile) {
    final extension = path.extension(imageFile.path).toLowerCase();
    final allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp'];

    if (!allowedExtensions.contains(extension)) {
      return false;
    }

    return true;
  }
}
