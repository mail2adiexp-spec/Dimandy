import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/locations_data.dart';

class AddStorePartnerScreen extends StatefulWidget {
  final String? partnerId;
  final Map<String, dynamic>? initialData;
  const AddStorePartnerScreen({super.key, this.partnerId, this.initialData});

  @override
  State<AddStorePartnerScreen> createState() => _AddStorePartnerScreenState();
}

class _AddStorePartnerScreenState extends State<AddStorePartnerScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _aadhaarCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _servicePincodesCtrl = TextEditingController(); // NEW: comma separated
  final _minChargeCtrl = TextEditingController(text: '0');
  
  String? _selectedState;
  String _selectedGender = 'Male';
  String _selectedStatus = 'approved';
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  
  Uint8List? _profileImage;
  Uint8List? _panImage;
  Uint8List? _aadhaarImage;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameCtrl.text = widget.initialData!['name'] ?? '';
      _emailCtrl.text = widget.initialData!['email'] ?? '';
      _phoneCtrl.text = widget.initialData!['phone'] ?? '';
      _businessNameCtrl.text = widget.initialData!['businessName'] ?? '';
      _gstCtrl.text = widget.initialData!['gstNumber'] ?? '';
      _panCtrl.text = widget.initialData!['panNumber'] ?? '';
      _aadhaarCtrl.text = widget.initialData!['aadhaarNumber'] ?? '';
      _districtCtrl.text = widget.initialData!['district'] ?? '';
      _pincodeCtrl.text = widget.initialData!['pincode'] ?? '';
      _addressCtrl.text = widget.initialData!['address'] ?? '';
      _minChargeCtrl.text = (widget.initialData!['minCharge'] ?? '0').toString();
      _servicePincodesCtrl.text = (widget.initialData!['servicePincodes'] as List<dynamic>?)?.join(', ') ?? '';
      _selectedState = widget.initialData!['state'];
      _selectedGender = widget.initialData!['gender'] ?? 'Male';
      _selectedStatus = widget.initialData!['status'] ?? 'approved';
    }
  }

  Future<void> _pickImg(String type) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (bytes.length > 800 * 1024) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image size exceeds 800 KB limit.')));
          return;
        }
        setState(() {
          if (type == 'profile') _profileImage = bytes;
          if (type == 'pan') _panImage = bytes;
          if (type == 'aadhaar') _aadhaarImage = bytes;
        });
      }
    } catch (e) {
      print('Image picker error: $e');
    }
  }

  Future<String?> _uploadToStorage(Uint8List? bytes, String path) async {
    if (bytes == null) return null;
    final ref = FirebaseStorage.instance.ref().child(path).child('${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      String? uid = widget.partnerId;

      if (uid == null) {
        // Create new account
        final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
        final callable = functions.httpsCallable('createStaffAccount'); 
        
        final result = await callable.call({
          'email': _emailCtrl.text.trim(),
          'password': _passwordCtrl.text,
          'name': _nameCtrl.text.trim(),
          'role': 'store_partner',
          'phone': _phoneCtrl.text.trim(),
        });
        uid = result.data['userId'];
      }
      
      if (uid != null) {
        final profUrl = _profileImage != null ? await _uploadToStorage(_profileImage, 'partner_profiles') : widget.initialData?['photoURL'];
        final panUrl = _panImage != null ? await _uploadToStorage(_panImage, 'partner_documents') : widget.initialData?['panImageUrl'];
        final adhUrl = _aadhaarImage != null ? await _uploadToStorage(_aadhaarImage, 'partner_documents') : widget.initialData?['aadhaarImageUrl'];
        
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': _nameCtrl.text.trim(),
          'role': 'store_partner',
          'gender': _selectedGender,
          'state': _selectedState,
          'district': _districtCtrl.text.trim(),
          'pincode': _pincodeCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
          'businessName': _businessNameCtrl.text.trim(),
          'panNumber': _panCtrl.text.trim(),
          'panImageUrl': panUrl,
          'gstNumber': _gstCtrl.text.trim(),
          'aadhaarNumber': _aadhaarCtrl.text.trim(),
          'aadhaarImageUrl': adhUrl,
          'photoURL': profUrl,
          'status': _selectedStatus,
          'servicePincodes': _servicePincodesCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
          'minCharge': double.tryParse(_minChargeCtrl.text) ?? 0.0,
          if (widget.partnerId == null) 'email': _emailCtrl.text.trim(),
          'isVerified': _selectedStatus == 'approved',
          if (widget.partnerId == null) 'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.partnerId == null ? 'Store Partner added successfully!' : 'Partner details updated!'), backgroundColor: Colors.green)
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isNarrow = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.partnerId == null ? 'Add Store Partner' : 'Edit Store Partner'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Registration Form', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(widget.partnerId == null ? 'Enter full details to create a new Store Partner account.' : 'Update existing partner details.', style: const TextStyle(color: Colors.grey)),
                        const Divider(height: 48),

                        // Section 1: Authentication & Basic Info
                        _buildSectionHeader('Authentication & Profile'),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildImagePicker('profile', 'Profile Picture', _profileImage),
                            const SizedBox(width: 32),
                            Expanded(
                              child: Column(
                                children: [
                                  _buildTextField(_nameCtrl, 'Full Name *', Icons.person),
                                  const SizedBox(height: 16),
                                  _buildTextField(_emailCtrl, 'Email Address (Log-in ID) *', Icons.email, keyboardType: TextInputType.emailAddress, enabled: widget.partnerId == null),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (widget.partnerId == null) ...[
                          const SizedBox(height: 16),
                          _buildResponsiveRow(isNarrow, [
                            _buildPasswordField(),
                            _buildTextField(_phoneCtrl, 'Phone Number *', Icons.phone, keyboardType: TextInputType.phone),
                          ]),
                        ] else ...[
                          const SizedBox(height: 16),
                          _buildTextField(_phoneCtrl, 'Phone Number *', Icons.phone, keyboardType: TextInputType.phone),
                        ],
                        const SizedBox(height: 16),
                        _buildResponsiveRow(isNarrow, [
                          _buildDropdown('Gender', _selectedGender, ['Male', 'Female', 'Other'], (v) => setState(() => _selectedGender = v!)),
                          _buildDropdown('Initial Status', _selectedStatus, ['approved', 'pending'], (v) => setState(() => _selectedStatus = v!)),
                        ]),

                        const Divider(height: 48),

                        // Section 2: Business & Identity
                        _buildSectionHeader('Business & Identity'),
                        const SizedBox(height: 20),
                        _buildTextField(_businessNameCtrl, 'Business/Store Name *', Icons.business),
                        const SizedBox(height: 16),
                        _buildTextField(_gstCtrl, 'GST Number (Optional)', Icons.receipt_long, validator: (v) => null),
                        const SizedBox(height: 16),
                        _buildResponsiveRow(isNarrow, [
                          _buildUploadField('pan', 'PAN Number', _panCtrl, _panImage),
                          _buildUploadField('aadhaar', 'Aadhaar Number', _aadhaarCtrl, _aadhaarImage),
                        ]),

                        const Divider(height: 48),

                        // Section 3: Location
                        _buildSectionHeader('Location & Service Areas'),
                        const SizedBox(height: 20),
                        _buildTextField(_servicePincodesCtrl, 'Service Area Pincodes * (Comma separated: 742223, 742212)', Icons.map),
                        const SizedBox(height: 16),
                        _buildResponsiveRow(isNarrow, [
                          _buildStateDropdown(),
                          _buildTextField(_districtCtrl, 'District/City *', Icons.location_city),
                        ]),
                        const SizedBox(height: 16),
                        _buildResponsiveRow(isNarrow, [
                          _buildTextField(_pincodeCtrl, 'Pincode *', Icons.pin_drop, keyboardType: TextInputType.number),
                          _buildTextField(_addressCtrl, 'Full Address', Icons.home),
                        ]),

                        const SizedBox(height: 48),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _submitForm,
                            child: Text(widget.partnerId == null ? 'CREATE PARTNER ACCOUNT' : 'UPDATE PARTNER DETAILS', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo));
  }

  Widget _buildResponsiveRow(bool isNarrow, List<Widget> children) {
    if (isNarrow) {
      return Column(
        children: children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 16), child: c)).toList(),
      );
    }
    return Row(
      children: children.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {TextInputType? keyboardType, String? Function(String?)? validator, bool enabled = true}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey[100],
      ),
      validator: validator ?? (v) => v!.isEmpty ? 'Required field' : null,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordCtrl,
      obscureText: !_isPasswordVisible,
      decoration: InputDecoration(
        labelText: 'Account Password *',
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (v) => v!.length < 6 ? 'Minimum 6 characters' : null,
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i.toUpperCase()))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildStateDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedState,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'State *',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: LocationsData.cities.map((e) => e.state).toSet().toList().map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
      onChanged: (v) => setState(() => _selectedState = v),
      validator: (v) => v == null ? 'Required' : null,
    );
  }

  Widget _buildImagePicker(String type, String label, Uint8List? image) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _pickImg(type),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[200],
            backgroundImage: image != null ? MemoryImage(image) : null,
            child: image == null ? const Icon(Icons.add_a_photo, size: 32, color: Colors.indigo) : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const Text('512x512, 800KB', style: TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildUploadField(String type, String label, TextEditingController ctrl, Uint8List? image) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: IconButton(
              icon: Icon(image == null ? Icons.upload_file : Icons.check_circle, color: image == null ? Colors.grey : Colors.green),
              onPressed: () => _pickImg(type),
            ),
          ),
        ),
        if (image != null) const Padding(
          padding: EdgeInsets.only(left: 12, top: 4),
          child: Text('Document selected ✅', style: TextStyle(fontSize: 10, color: Colors.green)),
        ),
      ],
    );
  }
}
