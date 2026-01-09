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
  final MobileScannerController controller = MobileScannerController();
  bool isScanned = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onBarcodeDetect(BarcodeCapture capture) {
    if (isScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final scannedValue = barcodes.first.rawValue;
    if (scannedValue == null || scannedValue.isEmpty) return;

    setState(() => isScanned = true);

    // Check if scanned barcode matches the expected order ID
    if (scannedValue == widget.expectedOrderId) {
      // Success
      Navigator.pop(context, true);
    } else {
      // Failed - show error and allow retry
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
              const Text('Scanned barcode does not match the order.'),
              const SizedBox(height: 12),
              Text(
                'Expected: ${widget.expectedOrderId}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Scanned: $scannedValue',
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
              child: const Text('Scan Again'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Order Barcode'),
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
                const SizedBox(height: 40),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
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
