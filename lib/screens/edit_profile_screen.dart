import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/locations_data.dart';

class EditProfileScreen extends StatefulWidget {
  static const routeName = '/edit-profile';
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pincodeController = TextEditingController(); // Added Pincode Controller
  final _passwordController = TextEditingController();

  File? _imageFile;
  Uint8List? _imageBytes;
  String? _imageUrl;
  String? _pickedFileName;
  bool _isLoading = false;
  bool _showPasswordField = false;
  bool _isPasswordInputVisible = false;

  String? _selectedState;
  final List<String> _availableStates = LocationsData.cities.map((e) => e.state).toSet().toList()..sort();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phoneNumber ?? '';
      _pincodeController.text = user.pincode ?? ''; // Init Pincode
      _imageUrl = user.photoURL;
      if (_availableStates.contains(user.state)) {
        _selectedState = user.state;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _pincodeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (pickedFile != null) {
        _pickedFileName = pickedFile.name;
        if (kIsWeb) {
          // Web: read as bytes
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _imageBytes = bytes;
          });
        } else {
          // Mobile/Desktop: use File
          setState(() {
            _imageFile = File(pickedFile.path);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthProvider>();
      final currentUser = auth.currentUser!;

      // Update name, state, or pincode if changed
      if (_nameController.text.trim() != currentUser.name || 
          _selectedState != currentUser.state ||
          _pincodeController.text.trim() != (currentUser.pincode ?? '')) {
        await auth.updateProfile(
          name: _nameController.text,
          state: _selectedState,
          pincode: _pincodeController.text.trim().isNotEmpty ? _pincodeController.text.trim() : null,
        );
      }

      // Update email if changed
      if (_emailController.text.trim() != currentUser.email) {
        if (_passwordController.text.isEmpty) {
          throw Exception('Password required for email change');
        }
        try {
          await auth.updateEmail(
            email: _emailController.text,
            password: _passwordController.text,
          );
        } catch (e) {
          final msg = e.toString();
          // If it's the verification info message, show it and continue
          if (msg.contains('Verification email sent')) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(msg.replaceFirst('Exception: ', ''))),
              );
            }
          } else {
            rethrow;
          }
        }
      }

      // Update phone number if changed
      if (_phoneController.text.trim() != (currentUser.phoneNumber ?? '')) {
        if (_phoneController.text.trim().isNotEmpty) {
          await auth.updatePhoneNumber(phoneNumber: _phoneController.text);
        }
      }

      // Update profile image if selected
      if (_imageFile != null || _imageBytes != null) {
        await auth.updateProfileImage(
          imageFile: _imageFile,
          imageBytes: _imageBytes,
          fileName: _pickedFileName,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        // Defer pop to the next frame to avoid popping during an active frame
        // which can lead to rendering a disposed view on Flutter Web.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(icon: const Icon(Icons.save), onPressed: _saveProfile),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile Image with error handling
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: _imageBytes != null
                          ? ClipOval(
                              child: Image.memory(
                                _imageBytes!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            )
                          : _imageFile != null && !kIsWeb
                          ? ClipOval(
                              child: Image.file(
                                _imageFile!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            )
                          : _imageUrl != null
                          ? ClipOval(
                              child: Image.network(
                                _imageUrl!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Text(
                                    _nameController.text.isNotEmpty
                                        ? _nameController.text[0].toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  );
                                },
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) {
                                        return child;
                                      }
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      );
                                    },
                              ),
                            )
                          : Text(
                              _nameController.text.isNotEmpty
                                  ? _nameController.text[0].toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: _pickImage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Name Field
              TextFormField(
                controller: _nameController,
                readOnly: true, // READ-ONLY
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white70, // Visual cue
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
              ),
              const SizedBox(height: 16),
              
              // State Dropdown (Editable)
              DropdownButtonFormField<String>(
                value: _selectedState,
                decoration: const InputDecoration(
                  labelText: 'State',
                  prefixIcon: Icon(Icons.location_city),
                  border: OutlineInputBorder(),
                ),
                items: _availableStates.map((state) {
                  return DropdownMenuItem(value: state, child: Text(state));
                }).toList(),
                onChanged: (val) => setState(() => _selectedState = val),
                validator: (v) => v == null ? 'Please select your state' : null,
              ),
              const SizedBox(height: 16),

              // Pincode Field (Editable)
              TextFormField(
                controller: _pincodeController,
                decoration: const InputDecoration(
                  labelText: 'PIN Code',
                  prefixIcon: Icon(Icons.pin_drop_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    if (v.length != 6) return 'PIN code must be 6 digits';
                    if (!RegExp(r'^[0-9]+$').hasMatch(v)) return 'Only numbers allowed';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email Field
              TextFormField(
                controller: _emailController,
                readOnly: true, // READ-ONLY
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white70,
                  // Remove helper text and suffix icon since it's read-only and password change logic implies editing
                ),
              ),

              // Password Field (shown when email is changed)
              if (_showPasswordField) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    helperText: 'Required for email change',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordInputVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordInputVisible = !_isPasswordInputVisible;
                        });
                      },
                    ),
                  ),
                  obscureText: !_isPasswordInputVisible,
                  validator: _showPasswordField
                      ? (v) => (v == null || v.isEmpty)
                            ? 'Password required'
                            : null
                      : null,
                ),
              ],
              const SizedBox(height: 16),

              // Phone Number Field
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
                maxLength: 10,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                   if (v != null && v.isNotEmpty && v.length != 10) {
                     return 'Phone number must be 10 digits';
                   }
                   return null;
                },
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveProfile,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? 'Saving...' : 'Save Changes'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
