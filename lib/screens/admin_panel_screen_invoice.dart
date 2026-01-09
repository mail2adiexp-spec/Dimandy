import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../services/invoice_generator.dart';

// Invoice Dialog Widget
class _InvoiceDialog extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final String sellerId;
  final Map<String, dynamic> sellerData;

  const _InvoiceDialog({
    required this.orderData,
    required this.sellerId,
    required this.sellerData,
  });

  @override
  State<_InvoiceDialog> createState() => _InvoiceDialogState();
}

class _InvoiceDialogState extends State<_InvoiceDialog> {
  bool _isGenerating = false;
  Uint8List? _pdfBytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generatePDF();
  }

  Future<void> _generatePDF() async {
    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final orderId = widget.orderData['id'] ?? 'UNKNOWN';
      final pdfBytes = await InvoiceGenerator.generateInvoice(
        orderData: widget.orderData,
        orderId: orderId,
        sellerData: widget.sellerData,
      );

      setState(() {
        _pdfBytes = pdfBytes;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isGenerating = false;
      });
    }
  }

  Future<void> _downloadPDF() async {
    if (_pdfBytes == null) return;

    try {
      final orderId = widget.orderData['id'] ?? 'UNKNOWN';
      final fileName = 'Invoice_${orderId.substring(0, 8)}.pdf';

      await Printing.sharePdf(
        bytes: _pdfBytes!,
        filename: fileName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printPDF() async {
    if (_pdfBytes == null) return;

    try {
      await Printing.layoutPdf(
        onLayout: (format) async => _pdfBytes!,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'INVOICE',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    if (_pdfBytes != null) ...[
                      IconButton(
                        icon: const Icon(Icons.download),
                        tooltip: 'Download PDF',
                        onPressed: _downloadPDF,
                      ),
                      IconButton(
                        icon: const Icon(Icons.print),
                        tooltip: 'Print',
                        onPressed: _printPDF,
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: _isGenerating
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Generating invoice...'),
                        ],
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error generating invoice',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _generatePDF,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _pdfBytes != null
                          ? PdfPreview(
                              build: (format) => _pdfBytes!,
                              canChangePageFormat: false,
                              canChangeOrientation: false,
                              canDebug: false,
                              allowPrinting: true,
                              allowSharing: true,
                            )
                          : const Center(
                              child: Text('No invoice data available'),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
