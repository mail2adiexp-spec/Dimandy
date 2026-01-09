import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentProofUploadWidget extends StatefulWidget {
  final String orderId;
  final String deliveryPartnerId;
  final VoidCallback onUploadComplete;

  const PaymentProofUploadWidget({
    super.key,
    required this.orderId,
    required this.deliveryPartnerId,
    required this.onUploadComplete,
  });

  @override
  State<PaymentProofUploadWidget> createState() => _PaymentProofUploadWidgetState();
}

class _PaymentProofUploadWidgetState extends State<PaymentProofUploadWidget> {
  File? _proofFile;
  Uint8List? _proofBytes;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
      );

      if (image == null) return;

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() {
          _proofBytes = bytes;
          _proofFile = null;
        });
      } else {
        setState(() {
          _proofFile = File(image.path);
          _proofBytes = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  Future<void> _uploadProof() async {
    if (_proofFile == null && _proofBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select payment screenshot first')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Upload to Firebase Storage
      final fileName = 'payment_proof_${widget.orderId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('payment_proofs')
          .child(widget.orderId)
          .child(fileName);

      String downloadUrl;
      if (kIsWeb) {
        await ref.putData(
          _proofBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        downloadUrl = await ref.getDownloadURL();
      } else {
        await ref.putFile(_proofFile!);
        downloadUrl = await ref.getDownloadURL();
      }

      // Update order document
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'paymentMethod': 'qr_code',
        'paymentProofUrl': downloadUrl,
        'paymentProofUploadedAt': FieldValue.serverTimestamp(),
        'paymentProofUploadedBy': widget.deliveryPartnerId,
        'paymentVerified': false, // Admin will verify
      });

      // Clear selection
      setState(() {
        _proofFile = null;
        _proofBytes = null;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment proof uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onUploadComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isUploading = false);
    }
  }

  void _clearSelection() {
    setState(() {
      _proofFile = null;
      _proofBytes = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.cloud_upload_outlined, color: Colors.blue[700]),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Proof',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Upload screenshot of payment',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Image Picker / Preview Area
            if (_proofFile == null && _proofBytes == null)
              InkWell(
                onTap: _isUploading ? null : _pickImage,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!, style: BorderStyle.values[1]), // Dashed border simulated
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.blue[300]),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to select screenshot',
                        style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              )
            else
              Stack(
                children: [
                  Container(
                    constraints: const BoxConstraints(maxHeight: 250),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: kIsWeb
                          ? Image.memory(_proofBytes!, fit: BoxFit.contain)
                          : Image.file(_proofFile!, fit: BoxFit.contain),
                    ),
                  ),
                  if (!_isUploading)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _clearSelection,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                ],
              ),
            
            const SizedBox(height: 16),

            // Actions
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: (_proofFile == null && _proofBytes == null) || _isUploading
                    ? null
                    : _uploadProof,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isUploading ? 'Uploading & Verifying...' : 'Submit Payment Proof',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[600],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
