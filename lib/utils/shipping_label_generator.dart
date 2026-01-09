import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:barcode_widget/barcode_widget.dart' as bw;

class ShippingLabelGenerator {
  static Future<Uint8List> generateShippingLabel({
    required Map<String, dynamic> orderData,
    required String orderId,
    required List<dynamic> sellerItems,
    required String sellerId,
    String? customerName,
  }) async {
    final pdf = pw.Document();
    
    // Extract shipping details
    final effectiveCustomerName = customerName ?? orderData['shippingAddress']?['name'] ?? 'N/A';
    final customerPhone = orderData['shippingAddress']?['phone'] ?? 'N/A';
    final customerAddress = _formatAddress(orderData['shippingAddress']);
    final orderDate = DateTime.now();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue900,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SHIPPING LABEL',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Order ID: ${orderId.substring(0, 12)}...',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
              
              // Ship To Section (Large and prominent)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey800, width: 2),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SHIP TO:',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      effectiveCustomerName,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Phone: $customerPhone',
                      style: const pw.TextStyle(
                        fontSize: 14,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        customerAddress,
                        style: const pw.TextStyle(
                          fontSize: 16,
                          lineSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
              
              // Order Details
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Order Details:',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(orderDate)}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Items: ${sellerItems.length}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Divider(color: PdfColors.blue200),
                    pw.SizedBox(height: 8),
                    ...sellerItems.map((item) {
                      final name = item['name'] ?? 'N/A';
                      final quantity = item['quantity'] ?? 0;
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Text(
                          '• $name x$quantity',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
              
              // Barcode Section
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Scan for Tracking',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.code128(),
                        data: orderId,
                        width: 300,
                        height: 80,
                        drawText: true,
                        textStyle: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.Spacer(),
              
              // Footer
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Text(
                'Handle with care • Keep this label visible during transit',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          );
        },
      ),
    );
    
    return pdf.save();
  }
  
  static String _formatAddress(Map<String, dynamic>? address) {
    if (address == null) return 'N/A';
    
    final parts = <String>[];
    if (address['street'] != null) parts.add(address['street']);
    if (address['city'] != null) parts.add(address['city']);
    if (address['state'] != null) parts.add(address['state']);
    if (address['pincode'] != null) parts.add('PIN: ${address['pincode']}');
    
    return parts.isEmpty ? 'N/A' : parts.join('\n');
  }
}
