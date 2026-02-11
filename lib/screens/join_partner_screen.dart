import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/service_category_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

class JoinPartnerScreen extends StatefulWidget {
  static const routeName = '/join-partner';

  const JoinPartnerScreen({super.key});

  @override
  State<JoinPartnerScreen> createState() => _JoinPartnerScreenState();
}

class _JoinPartnerScreenState extends State<JoinPartnerScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  String _role = 'Seller';
  String _gender = 'Male';
  String? _selectedServiceCategoryId;
  
  // Common Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _districtController = TextEditingController(); // Treated as Address for Delivery Partner
  final _pincodeController = TextEditingController();
  final _panController = TextEditingController();
  final _aadhaarController = TextEditingController();

  // Seller/Service Provider Specific
  final _businessController = TextEditingController();
  final _minChargeController = TextEditingController();

  // Delivery Partner Specific
  String _vehicleType = 'Bike';
  final _vehicleNumberController = TextEditingController();

  Uint8List? _profileImageBytes;
  bool _isSubmitting = false;

  final List<String> _vehicleTypes = [
    'Bike',
    'Scooter',
    'Bicycle',
    'Car',
    'Van',
  ];

  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (!mounted) return;
        setState(() => _profileImageBytes = bytes);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  final List<String> _indianStates = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand',
    'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur',
    'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab',
    'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura',
    'Uttar Pradesh', 'Uttarakhand', 'West Bengal', 'Andaman and Nicobar Islands',
    'Chandigarh', 'Dadra and Nagar Haveli and Daman and Diu', 'Delhi',
    'Jammu and Kashmir', 'Ladakh', 'Lakshadweep', 'Puducherry',
  ];

  String? _selectedState;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _districtController.dispose();
    _pincodeController.dispose();
    _businessController.dispose();
    _panController.dispose();
    _aadhaarController.dispose();
    _minChargeController.dispose();
    _vehicleNumberController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    FocusScope.of(context).unfocus();

    try {
      String? profilePicUrl;

      // Upload profile picture if selected
      if (_profileImageBytes != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('partner_profiles')
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

        final uploadTask = await storageRef.putData(
          _profileImageBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        profilePicUrl = await uploadTask.ref.getDownloadURL();
      }

      // Create partner request document
      final docRef = FirebaseFirestore.instance
          .collection('partner_requests')
          .doc();

      Map<String, dynamic> requestData = {
        'id': docRef.id,
        'role': _role,
        'gender': _gender,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text.trim(),
        'state': _selectedState, // Added State
        'district': _districtController.text.trim(), // Acts as 'address' for Delivery Partner
        'address': _districtController.text.trim(), // Saving as address too for clarity
        'pincode': _pincodeController.text.trim(),
        'panNumber': _panController.text.trim().toUpperCase(),
        'aadhaarNumber': _aadhaarController.text.trim(),
        'profilePicUrl': profilePicUrl,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_role == 'Delivery Partner') {
        requestData.addAll({
          'vehicleType': _vehicleType,
          'vehicleNumber': _vehicleNumberController.text.trim(),
          'service_pincode': _pincodeController.text.trim(), // For delivery partners
        });
      } else {
        // Sellers & Service Providers
        
        // Add Min Charge ONLY for Service Providers
        if (_role == 'Service Provider') {
           requestData.addAll({
             'minCharge': double.parse(_minChargeController.text.trim()),
           });
           
           if (_selectedServiceCategoryId != null) {
             try {
               final catDoc = await FirebaseFirestore.instance
                   .collection('service_categories')
                   .doc(_selectedServiceCategoryId)
                   .get();
               if (catDoc.exists) {
                 requestData.addAll({
                   'serviceCategoryId': catDoc.id,
                   'serviceCategoryName': catDoc.data()!['name'] ?? '',
                 });
               }
             } catch (_) {}
           }
           requestData['businessName'] = _businessController.text.trim().isEmpty
               ? (requestData['serviceCategoryName'] ?? '')
               : _businessController.text.trim();
        } else {
          // Seller
          requestData['businessName'] = _businessController.text.trim();
          requestData['minCharge'] = 0.0; // Default for Seller
        }
      }


      await docRef.set(requestData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Request submitted successfully! We\'ll contact you soon.',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit request: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDeliveryPartner = _role == 'Delivery Partner';
    final isServiceProvider = _role == 'Service Provider'; // Helper

    return Scaffold(
      appBar: AppBar(title: const Text('Join as Partner'), centerTitle: true),
      body: SingleChildScrollView(
        // Add bottom padding to prevent content from being hidden behind bottom bar
        padding: const EdgeInsets.only(top: 16, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // Role Dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _role,
                        decoration: const InputDecoration(
                          labelText: 'Select Role',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        isExpanded: true,
                        items: ['Seller', 'Service Provider', 'Delivery Partner']
                            .map((role) => DropdownMenuItem(
                                  value: role,
                                  child: Text(
                                    role,
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _role = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Gender Dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: const InputDecoration(
                          labelText: 'Select Gender',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        isExpanded: true, // Prevent overflow
                        items: ['Male', 'Female', 'Other']
                            .map((gender) => DropdownMenuItem(
                                  value: gender,
                                  child: Text(gender),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _gender = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            // Keep the rest content neatly padded
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Profile picture uploader
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.1),
                          backgroundImage: _profileImageBytes != null
                              ? MemoryImage(_profileImageBytes!)
                              : null,
                          child: _profileImageBytes == null
                              ? Icon(
                                  Icons.person,
                                  size: 36,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        // Expanded hata diya, sirf button direct Row ke andar
                        ElevatedButton.icon(
                          onPressed: _pickProfileImage,
                          icon: const Icon(Icons.photo_camera_back),
                          label: const Text('Upload Profile Picture'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().length < 3
                          ? 'Please enter your full name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 10,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter phone number';
                        if (v.trim().length != 10) return 'Phone number must be 10 digits';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Please enter email';
                        final email = v.trim();
                        final emailRegex = RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        );
                        if (!emailRegex.hasMatch(email))
                          return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Set Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      validator: (v) => v == null || v.trim().length < 6
                          ? 'Password kam se kam 6 character ka hona chahiye'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _districtController,
                      decoration: InputDecoration(
                        labelText: isDeliveryPartner ? 'Full Address' : 'District/City',
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: isDeliveryPartner ? 3 : 1,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please enter details'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    // State Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedState,
                      decoration: const InputDecoration(
                        labelText: 'State',
                        border: OutlineInputBorder(),
                      ),
                      items: _indianStates.map((state) {
                        return DropdownMenuItem(value: state, child: Text(state));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedState = val),
                      validator: (val) => val == null ? 'Please select a state' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pincodeController,
                      decoration: const InputDecoration(
                        labelText: 'PIN Code',
                        hintText: '6-digit PIN code',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter PIN code';
                        }
                        final pin = v.replaceAll(RegExp(r'\s'), '');
                        final pinRegex = RegExp(r'^\d{6}$');
                        if (!pinRegex.hasMatch(pin)) {
                          return 'Enter a valid 6-digit PIN code';
                        }
                        return null;
                      },
                    ),
                    
                    if (isDeliveryPartner) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _vehicleType,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle Type',
                          border: OutlineInputBorder(),
                        ),
                        items: _vehicleTypes
                            .map(
                              (type) =>
                                  DropdownMenuItem(value: type, child: Text(type)),
                            )
                            .toList(),
                        onChanged: (val) => setState(() => _vehicleType = val!),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _vehicleNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle Number (Optional)',
                          hintText: 'e.g. DL01AB1234',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],

                    if (!isDeliveryPartner) ...[
                        const SizedBox(height: 12),
                        // If Service Provider, show category dropdown + optional display name
                        if (_role == 'Service Provider') ...[
                          Consumer<ServiceCategoryProvider>(
                            builder: (context, provider, _) {
                              final categories = provider.serviceCategories;
                              return DropdownButtonFormField<String>(
                                value: _selectedServiceCategoryId,
                                decoration: const InputDecoration(
                                  labelText: 'Service Category',
                                  border: OutlineInputBorder(),
                                ),
                                items: categories
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) => setState(
                                  () => _selectedServiceCategoryId = val,
                                ),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Select a service category'
                                    : null,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _businessController,
                            decoration: const InputDecoration(
                              labelText: 'Service Display Name (Optional)',
                              hintText: 'If different from category name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ] else ...[
                          TextFormField(
                            controller: _businessController,
                            decoration: const InputDecoration(
                              labelText: 'Business Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Please enter your business name'
                                : null,
                          ),
                        ],
                    ],
                    
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _panController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'PAN Card Number',
                        hintText: 'ABCDE1234F',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null) return 'Enter PAN number';
                        final pan = v.trim().toUpperCase();
                        final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
                        if (!panRegex.hasMatch(pan)) {
                          return 'Enter a valid PAN (e.g., ABCDE1234F)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _aadhaarController,
                      decoration: const InputDecoration(
                        labelText: 'Aadhaar Number',
                        hintText: '12-digit number',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null) return 'Enter Aadhaar number';
                        final a = v.replaceAll(RegExp(r'\s'), '');
                        final aadhaarRegex = RegExp(r'^\d{12}$');
                        if (!aadhaarRegex.hasMatch(a)) {
                          return 'Enter a valid 12-digit Aadhaar number';
                        }
                        return null;
                      },
                    ),

                    if (isServiceProvider) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _minChargeController,
                        decoration: const InputDecoration(
                          labelText: 'Minimum Charge (₹)',
                          hintText: 'e.g., 199',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: false,
                          decimal: true,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter your minimum charge';
                          }
                          final value = double.tryParse(v.trim());
                          if (value == null || value <= 0) {
                            return 'Enter a valid amount';
                          }
                          return null;
                        },
                      ),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, -4),
              blurRadius: 10,
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(_isSubmitting ? 'Submitting...' : 'Submit Application'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
