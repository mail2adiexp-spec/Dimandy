import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final String expectedOrderId;

  const BarcodeScannerScreen({
    super.key,
    required this.expectedOrderId,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    // By restricting formats, the scanner engine doesn't waste CPU checking for 15+ other barcode types,
    // which makes QR Code scanning significantly faster.
    formats: const [
      BarcodeFormat.qrCode,
      BarcodeFormat.code128, // Common for order packaging barcodes as well
    ],
  );
  bool isScanned = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _showErrorDialog(String scannedValue) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Invalid Barcode'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Entered barcode does not match the order.'),
            const SizedBox(height: 12),
            Text(
              'Expected: ${widget.expectedOrderId}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Entered: $scannedValue',
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => isScanned = false);
              Navigator.pop(ctx);
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showManualEntryDialog() {
    final TextEditingController _manualController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Barcode Manually'),
        content: TextField(
          controller: _manualController,
          decoration: const InputDecoration(
            labelText: 'Barcode / Order ID',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = _manualController.text.trim();
              if (val.isEmpty) return;
              Navigator.pop(ctx);
              if (_isMatch(val, widget.expectedOrderId)) {
                controller.stop();
                Navigator.pop(context, true);
              } else {
                _showErrorDialog(val);
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  bool _isMatch(String scannedValue, String expectedId) {
    // 1. Basic Cleaning: Remove #, trim, and toLowerCase
    String cleanScanned = scannedValue.trim().toLowerCase().replaceAll('#', '');
    String cleanExpected = expectedId.trim().toLowerCase();

    // 2. Exact Match
    if (cleanScanned == cleanExpected) return true;

    // 3. Super Cleaning: Keep only alphanumeric to ignore "Order:", "ID:", spaces, etc.
    final alphanumeric = RegExp(r'[a-z0-9]');
    String superCleanScanned = scannedValue.toLowerCase()
        .split('')
        .where((char) => alphanumeric.hasMatch(char))
        .join('');
    String superCleanExpected = expectedId.toLowerCase()
        .split('')
        .where((char) => alphanumeric.hasMatch(char))
        .join('');

    if (superCleanScanned == superCleanExpected) return true;

    // 4. Containment Check: If the QR code contains the ID somewhere (e.g. in a URL)
    // Or if the scanned value is a truncated version (at least 6 chars)
    if (superCleanScanned.length >= 6 && superCleanExpected.contains(superCleanScanned)) return true;
    if (superCleanExpected.length >= 6 && superCleanScanned.contains(superCleanExpected)) return true;

    return false;
  }

  void _onBarcodeDetect(BarcodeCapture capture) {
    if (isScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final scannedValue = barcodes.first.rawValue;
    if (scannedValue == null || scannedValue.isEmpty) return;

    setState(() => isScanned = true);

    if (_isMatch(scannedValue, widget.expectedOrderId)) {
      controller.stop();
      Navigator.pop(context, true);
    } else {
      _showErrorDialog(scannedValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan or Enter Barcode'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Scanner
          MobileScanner(
            controller: controller,
            onDetect: _onBarcodeDetect,
          ),
          
          // Overlay with scanning frame
          Positioned.fill(
            child: Column(
              children: [
                const Spacer(),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      // Corner decorations
                      Positioned(
                        top: -2,
                        left: -2,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.green, width: 5),
                              left: BorderSide(color: Colors.green, width: 5),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.green, width: 5),
                              right: BorderSide(color: Colors.green, width: 5),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -2,
                        left: -2,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.green, width: 5),
                              left: BorderSide(color: Colors.green, width: 5),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.green, width: 5),
                              right: BorderSide(color: Colors.green, width: 5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.keyboard),
                  label: const Text('Enter Barcode Manually'),
                  onPressed: _showManualEntryDialog,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Position the barcode within the frame',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Order: ${widget.expectedOrderId.substring(0, 8)}...',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
