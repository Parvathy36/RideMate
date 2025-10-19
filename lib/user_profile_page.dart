import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert'; // Add this import for JSON parsing
import 'services/auth_service.dart';
import 'services/firestore_service.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  // Controllers for the form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  
  // Image picker
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  String? _profileImageUrl;

  // Cloudinary configuration
  static const String CLOUDINARY_CLOUD_NAME = 'your-cloud-name'; // Replace with your Cloudinary cloud name
  static const String CLOUDINARY_UPLOAD_PRESET = 'your-upload-preset'; // Replace with your Cloudinary upload preset

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final userData = await FirestoreService.getUserData(user.uid);
        setState(() {
          _userData = userData;
          _profileImageUrl = userData?['profileImageUrl'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Method to pick an image from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedImage = await _picker.pickImage(source: source);
      if (pickedImage != null) {
        setState(() {
          _selectedImage = File(pickedImage.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to pick image'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Method to upload image to Cloudinary
  Future<String?> _uploadImageToCloudinary(File imageFile) async {
    try {
      // Create the upload URL
      final url = Uri.parse(
          'https://api.cloudinary.com/v1_1/$CLOUDINARY_CLOUD_NAME/image/upload');

      // Create multipart request
      final request = http.MultipartRequest('POST', url);
      
      // Add upload preset
      request.fields['upload_preset'] = CLOUDINARY_UPLOAD_PRESET;
      
      // Add file
      final file = await http.MultipartFile.fromPath('file', imageFile.path);
      request.files.add(file);

      // Send the request
      final response = await request.send();
      
      // Get the response
      final respStr = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        // Parse the JSON response to get the URL
        final jsonResponse = json.decode(respStr);
        final imageUrl = jsonResponse['secure_url'] as String?;
        return imageUrl;
      }
      
      print('Cloudinary upload failed with status: ${response.statusCode}');
      print('Response: $respStr');
      return null;
    } catch (e) {
      print('Error uploading image to Cloudinary: $e');
      return null;
    }
  }

  // Method to show image source selection dialog
  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Camera'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Method to show the edit profile dialog
  void _showEditProfileDialog() {
    final user = _authService.currentUser;
    
    // Initialize controllers with current data
    _nameController.text = user?.displayName ?? '';
    _phoneController.text = _userData?['phoneNumber'] ?? '';
    _dobController.text = _userData?['dateOfBirth'] ?? '';
    _selectedImage = null; // Reset selected image

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Profile image section
                GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: _selectedImage != null
                            ? FileImage(_selectedImage!)
                            : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty
                                ? NetworkImage(_profileImageUrl!)
                                : null) as ImageProvider?,
                        backgroundColor: Colors.deepPurple.shade100,
                        child: (_selectedImage == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty))
                            ? Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.deepPurple,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          height: 30,
                          width: 30,
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter your full name',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'Enter your phone number',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _dobController,
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    hintText: 'Enter your date of birth',
                  ),
                  onTap: () async {
                    // Prevent keyboard from appearing
                    FocusScope.of(context).requestFocus(FocusNode());
                    // Show date picker
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (pickedDate != null) {
                      setState(() {
                        _dobController.text =
                            "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateProfile();
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // Method to update user profile
  Future<void> _updateProfile() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text('Saving profile...'),
                ],
              ),
            );
          },
        );
      }

      String? newProfileImageUrl = _profileImageUrl;

      // Upload image if selected
      if (_selectedImage != null) {
        newProfileImageUrl = await _uploadImageToCloudinary(_selectedImage!);
        if (newProfileImageUrl == null) {
          if (mounted) {
            Navigator.of(context).pop(); // Remove loading dialog
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to upload profile image'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // Update display name in Firebase Auth
      if (_nameController.text.isNotEmpty && _nameController.text != user.displayName) {
        await user.updateDisplayName(_nameController.text);
      }

      // Update user data in Firestore
      final updateData = <String, dynamic>{};
      
      if (_phoneController.text.isNotEmpty) {
        updateData['phoneNumber'] = _phoneController.text;
      }
      
      if (_dobController.text.isNotEmpty) {
        updateData['dateOfBirth'] = _dobController.text;
      }
      
      // Add profile image URL if changed
      if (newProfileImageUrl != _profileImageUrl) {
        updateData['profileImageUrl'] = newProfileImageUrl;
      }
      
      updateData['updatedAt'] = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updateData);

      // Update local state
      setState(() {
        _profileImageUrl = newProfileImageUrl;
      });

      // Reload user data to reflect changes
      await _loadUserData();

      // Remove loading dialog and show success message
      if (mounted) {
        Navigator.of(context).pop(); // Remove loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error updating profile: $e');
      // Remove loading dialog and show error message
      if (mounted) {
        Navigator.of(context).pop(); // Remove loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update profile'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile header
                  Center(
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.deepPurple.shade300,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurple.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundImage: (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                                ? NetworkImage(_profileImageUrl!)
                                : null,
                            backgroundColor: Colors.deepPurple.shade100,
                            child: (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                                ? Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Colors.deepPurple,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user?.displayName ?? 'User',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user?.email ?? 'No email',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // User details section
                  const Text(
                    'Account Information',
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard('Full Name', user?.displayName ?? 'Not set'),
                  const SizedBox(height: 16),
                  _buildInfoCard('Email Address', user?.email ?? 'Not available'),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    'Phone Number',
                    _userData?['phoneNumber'] ?? 'Not set',
                  ),
                  const SizedBox(height: 16),
                  if (_userData?['dateOfBirth'] != null)
                    _buildInfoCard(
                      'Date of Birth',
                      _userData!['dateOfBirth'],
                    ),
                  const SizedBox(height: 16),
                  if (_userData?['address'] != null)
                    _buildInfoCard(
                      'Address',
                      _userData!['address'],
                    ),
                  const SizedBox(height: 16),
                  if (_userData?['dateJoined'] != null)
                    _buildInfoCard(
                      'Member Since',
                      _userData!['dateJoined'],
                    ),
                  const SizedBox(height: 32),
                  // Action buttons
                  Center(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showEditProfileDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.edit),
                        label: const Text(
                          'Edit Profile',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await _authService.signOut();
                          if (mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/login',
                              (route) => false,
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(
                          Icons.logout,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value.isEmpty ? 'Not provided' : value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }
}