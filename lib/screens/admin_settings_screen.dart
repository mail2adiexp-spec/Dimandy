import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/app_settings_model.dart';
import '../providers/auth_provider.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _upiIdController = TextEditingController();
  final _deliveryFeePercentageController = TextEditingController();
  final _deliveryFeeMaxCapController = TextEditingController(); // This is correctly defined
  final _freeDeliveryThresholdController = TextEditingController(); // New
  final _partnerDeliveryRateController = TextEditingController(); // New
  final _servicePlatformFeeController = TextEditingController();
  final _announcementController = TextEditingController();
  final _contactPhoneController = TextEditingController(); // New
  Map<String, double> _pincodeOverrides = {}; // New
  bool _isAnnouncementEnabled = false;
  bool _isLoading = true;
  bool _isUploading = false;
  AppSettingsModel? _settings;
  
  File? _qrCodeFile;
  Uint8List? _qrCodeBytes;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('general')
          .get();
      
      if (doc.exists) {
        setState(() {
          _settings = AppSettingsModel.fromMap(doc.data()!, doc.id);
          _upiIdController.text = _settings?.upiId ?? '';
          _deliveryFeePercentageController.text = _settings?.deliveryFeePercentage.toString() ?? '0.0';
          _deliveryFeeMaxCapController.text = _settings?.deliveryFeeMaxCap.toString() ?? '0.0';
          _freeDeliveryThresholdController.text = _settings?.freeDeliveryThreshold.toString() ?? '0.0';
          _partnerDeliveryRateController.text = _settings?.partnerDeliveryRate.toString() ?? '0.0';
          _pincodeOverrides = Map<String, double>.from(_settings?.pincodeOverrides ?? {});
          _servicePlatformFeeController.text = _settings?.servicePlatformFeePercentage.toString() ?? '0.0';
          _announcementController.text = _settings?.announcementText ?? '';
          _isAnnouncementEnabled = _settings?.isAnnouncementEnabled ?? false;
          _contactPhoneController.text = _settings?.contactPhoneNumber ?? ''; // New
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickQRCodeImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() {
          _qrCodeBytes = bytes;
          _qrCodeFile = null;
        });
      } else {
        setState(() {
          _qrCodeFile = File(image.path);
          _qrCodeBytes = null;
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

  Future<void> _saveSettings() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final adminId = auth.currentUser?.uid;
    
    if (adminId == null) return;

    setState(() => _isUploading = true);

    try {
      String? downloadUrl = _settings?.upiQRCodeUrl;

      // Upload new image if selected
      if (_qrCodeFile != null || _qrCodeBytes != null) {
        final fileName = 'upi_qr_code_${DateTime.now().millisecondsSinceEpoch}.png';
        final ref = FirebaseStorage.instance
            .ref()
            .child('app_settings')
            .child(fileName);

        if (kIsWeb) {
          await ref.putData(_qrCodeBytes!, SettableMetadata(contentType: 'image/png'));
          downloadUrl = await ref.getDownloadURL();
        } else {
          await ref.putFile(_qrCodeFile!);
          downloadUrl = await ref.getDownloadURL();
        }
      }

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('general')
          .set({
        'upiQRCodeUrl': downloadUrl,
        'upiId': _upiIdController.text.trim(),
        'deliveryFeePercentage': double.tryParse(_deliveryFeePercentageController.text.trim()) ?? 0.0,
        'deliveryFeeMaxCap': double.tryParse(_deliveryFeeMaxCapController.text.trim()) ?? 0.0,
        'freeDeliveryThreshold': double.tryParse(_freeDeliveryThresholdController.text.trim()) ?? 0.0,
        'partnerDeliveryRate': double.tryParse(_partnerDeliveryRateController.text.trim()) ?? 0.0,
        'pincodeOverrides': _pincodeOverrides,
        'servicePlatformFeePercentage': double.tryParse(_servicePlatformFeeController.text.trim()) ?? 0.0,
        'announcementText': _announcementController.text.trim(),
        'isAnnouncementEnabled': _isAnnouncementEnabled,
        'contactPhoneNumber': _contactPhoneController.text.trim(), // New
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': adminId,
      }, SetOptions(merge: true));

      // Reload settings
      await _loadSettings();

      // Clear selection
      setState(() {
        _qrCodeFile = null;
        _qrCodeBytes = null;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Settings',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure UPI QR code and Delivery Fees',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 32),

          // Platform Fee Settings (High Priority)
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    children: [
                       Icon(Icons.monetization_on, color: Colors.blue.shade800),
                       const SizedBox(width: 8),
                       Text(
                        'Platform Fees',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                   ),
                   const SizedBox(height: 8),
                    Text(
                      'Set commission rate for Service Providers (for Booking Services).',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                    ),
                   const SizedBox(height: 16),
                   TextField(
                     controller: _servicePlatformFeeController,
                     keyboardType: TextInputType.number,
                     decoration: const InputDecoration(
                       labelText: 'Service Provider Fee (%) - for Services',
                       filled: true,
                       fillColor: Colors.white,
                       border: OutlineInputBorder(),
                       prefixIcon: Icon(Icons.handyman),
                       suffixText: '%',
                     ),
                   ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // PART 1: Customer Delivery Fees
          Card(
             color: Colors.blue.shade50,
             child: Padding(
               padding: const EdgeInsets.all(16),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Row(
                     children: [
                       Icon(Icons.person_outline, color: Colors.blue.shade800),
                       const SizedBox(width: 8),
                       Text(
                         'Customer Delivery Fees',
                         style: TextStyle(
                           fontSize: 18,
                           fontWeight: FontWeight.bold,
                           color: Colors.blue.shade900,
                         ),
                       ),
                     ],
                   ),
                   const SizedBox(height: 8),
                   Text(
                     'Manage how much the customer is charged for delivery.',
                     style: TextStyle(
                       fontSize: 12, 
                       color: Colors.blue.shade800,
                     ),
                   ),
                   const SizedBox(height: 16),
                   
                   // Percentage and Max Cap
                   Row(
                     children: [
                       Expanded(
                         child: TextField(
                           controller: _deliveryFeePercentageController,
                           keyboardType: TextInputType.number,
                           decoration: const InputDecoration(
                             labelText: 'Customer Fee (%)',
                             hintText: 'e.g. 5',
                             filled: true,
                             fillColor: Colors.white,
                             border: OutlineInputBorder(),
                             prefixIcon: Icon(Icons.percent),
                             suffixText: '%',
                           ),
                         ),
                       ),
                       const SizedBox(width: 16),
                       Expanded(
                         child: TextField(
                           controller: _deliveryFeeMaxCapController,
                           keyboardType: TextInputType.number,
                           decoration: const InputDecoration(
                             labelText: 'Max Fee Cap (₹)',
                             hintText: 'e.g. 40',
                             filled: true,
                             fillColor: Colors.white,
                             border: OutlineInputBorder(),
                             prefixIcon: Icon(Icons.currency_rupee),
                           ),
                         ),
                       ),
                     ],
                   ),
                   const SizedBox(height: 16),
                   
                   // Free Threshold
                   TextField(
                     controller: _freeDeliveryThresholdController,
                     keyboardType: TextInputType.number,
                     decoration: const InputDecoration(
                       labelText: 'Free Delivery on Orders Above (₹)',
                       hintText: 'e.g. 500 (Set 0 for No Free Delivery)',
                       filled: true,
                       fillColor: Colors.white,
                       border: OutlineInputBorder(),
                       prefixIcon: Icon(Icons.shopping_bag),
                     ),
                   ),
                   const SizedBox(height: 24),

                   // Pincode Overrides
                   Text(
                     'Pincode Specific Fees (Customer)',
                     style: TextStyle(
                       fontWeight: FontWeight.bold,
                       color: Colors.blue.shade900,
                     ),
                   ),
                   const SizedBox(height: 8),
                   ..._pincodeOverrides.entries.map((entry) => ListTile(
                     dense: true,
                     title: Text('Pincode: ${entry.key}'),
                     trailing: Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Text('₹${entry.value.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                         IconButton(
                           icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                           onPressed: () => setState(() => _pincodeOverrides.remove(entry.key)),
                         ),
                       ],
                     ),
                   )),
                   TextButton.icon(
                     onPressed: _showAddPincodeDialog,
                     icon: const Icon(Icons.add_location_alt),
                     label: const Text('Add Pincode Override'),
                     style: TextButton.styleFrom(foregroundColor: Colors.blue.shade900),
                   ),
                 ],
               ),
             ),
          ),
          const SizedBox(height: 24),

          // PART 2: Delivery Partner Payout Settings
          Card(
             color: Colors.orange.shade50,
             child: Padding(
               padding: const EdgeInsets.all(16),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Row(
                     children: [
                       Icon(Icons.delivery_dining, color: Colors.orange.shade800),
                       const SizedBox(width: 8),
                       Text(
                         'Delivery Partner Payout',
                         style: TextStyle(
                           fontSize: 18,
                           fontWeight: FontWeight.bold,
                           color: Colors.orange.shade900,
                         ),
                       ),
                     ],
                   ),
                   const SizedBox(height: 8),
                   Text(
                     'Set the amount paid to the delivery partner for each order.',
                     style: TextStyle(
                       fontSize: 12, 
                       color: Colors.orange.shade800,
                     ),
                   ),
                   const SizedBox(height: 16),

                   TextField(
                     controller: _partnerDeliveryRateController,
                     keyboardType: TextInputType.number,
                     decoration: const InputDecoration(
                       labelText: 'Partner Commission Rate (₹)',
                       hintText: 'Payable to Delivery Boy per Order',
                       filled: true,
                       fillColor: Colors.white,
                       border: OutlineInputBorder(),
                       prefixIcon: Icon(Icons.motorcycle),
                       suffixText: '₹/Order',
                     ),
                   ),
                   const SizedBox(height: 8),
                   Text(
                     'This is the fixed cost subtracted from Gross Profit for each order.',
                     style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontStyle: FontStyle.italic),
                   ),
                 ],
               ),
             ),
          ),
          const SizedBox(height: 24),

          // Announcement/Marquee Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Text(
                        'Home Page Announcement',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Switch(
                        value: _isAnnouncementEnabled,
                        onChanged: (val) => setState(() => _isAnnouncementEnabled = val),
                      ),
                    ],
                   ),
                   const SizedBox(height: 12),
                   TextField(
                     controller: _announcementController,
                     decoration: const InputDecoration(
                       labelText: 'Announcement Text',
                       hintText: 'e.g. Free Delivery on orders above ₹199 ✨',
                       border: OutlineInputBorder(),
                       prefixIcon: Icon(Icons.campaign),
                     ),
                     maxLines: 2,
                   ),
                   const SizedBox(height: 8),
                   Text(
                     'This text will scroll horizontally on the home screen.',
                     style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                   ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Contact & Order Settings
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    children: [
                       Icon(Icons.phone_in_talk, color: Colors.green.shade800),
                       const SizedBox(width: 8),
                       Text(
                        'Call & Order Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ],
                   ),
                   const SizedBox(height: 8),
                   Text(
                     'Enter the phone number where customers can call to place orders without signing up.',
                     style: TextStyle(fontSize: 12, color: Colors.green.shade800),
                   ),
                   const SizedBox(height: 16),
                   TextField(
                     controller: _contactPhoneController,
                     keyboardType: TextInputType.phone,
                     decoration: const InputDecoration(
                       labelText: 'Contact Phone Number',
                       hintText: 'e.g. +91 9876543210',
                       filled: true,
                       fillColor: Colors.white,
                       border: OutlineInputBorder(),
                       prefixIcon: Icon(Icons.call),
                     ),
                   ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Current QR Code Section
          if (_settings?.upiQRCodeUrl != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Current QR Code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Image.network(
                          _settings!.upiQRCodeUrl!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    if (_settings?.upiId != null && _settings!.upiId!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'UPI ID: ${_settings!.upiId}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Settings Card (QR Upload + Fee Settings)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configuration',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // UPI ID Input
                  TextField(
                    controller: _upiIdController,
                    decoration: InputDecoration(
                      labelText: 'UPI ID (Optional)',
                      hintText: 'yourname@upi',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance_wallet),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    _settings?.upiQRCodeUrl == null
                        ? 'Upload QR Code'
                        : 'Update QR Code',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Image Preview
                  if (_qrCodeFile != null || _qrCodeBytes != null) ...[
                    Center(
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: kIsWeb
                            ? Image.memory(_qrCodeBytes!, fit: BoxFit.contain)
                            : Image.file(_qrCodeFile!, fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isUploading ? null : _pickQRCodeImage,
                          icon: const Icon(Icons.image),
                          label: Text(
                            _qrCodeFile == null && _qrCodeBytes == null
                                ? 'Select Image'
                                : 'Change Image',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isUploading ? null : _saveSettings,
                          icon: _isUploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(_isUploading ? 'Saving...' : 'Save Settings'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    _deliveryFeePercentageController.dispose();
    _deliveryFeeMaxCapController.dispose();
    _freeDeliveryThresholdController.dispose(); // New
    _partnerDeliveryRateController.dispose(); // New
    _servicePlatformFeeController.dispose();
    _announcementController.dispose();
    _contactPhoneController.dispose(); // New
    super.dispose();
  }

  void _showAddPincodeDialog() {
    final pinController = TextEditingController();
    final feeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Pincode Override'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Pincode', hintText: 'e.g. 700001'),
            ),
            TextField(
              controller: feeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Delivery Fee (₹)', hintText: '0 for FREE'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (pinController.text.isNotEmpty) {
                setState(() {
                  _pincodeOverrides[pinController.text.trim()] = double.tryParse(feeController.text.trim()) ?? 0.0;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
