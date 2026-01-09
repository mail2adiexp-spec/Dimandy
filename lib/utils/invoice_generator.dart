import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class InvoiceGenerator {
  static Future<Uint8List> generateInvoice({
    required Map<String, dynamic> orderData,
    required String orderId,
    required Map<String, dynamic> sellerData,
  }) async {
    final pdf = pw.Document();
    
    // Extract order details
    final items = orderData['items'] as List<dynamic>? ?? [];
    final customerName = orderData['shippingAddress']?['name'] ?? 'N/A';
    final customerPhone = orderData['shippingAddress']?['phone'] ?? 'N/A';
    final customerAddress = _formatAddress(orderData['shippingAddress']);
    final orderDate = (orderData['createdAt'] as dynamic)?.toDate() ?? DateTime.now();
    final totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final shippingCharges = (orderData['shippingCharges'] as num?)?.toDouble() ?? 0.0;
    final paymentMethod = orderData['paymentMethod'] ?? 'COD';
    
    // Calculate subtotal and tax
    final subtotal = totalAmount - shippingCharges;
    final taxRate = 0.18; // 18% GST
    final taxableAmount = subtotal / (1 + taxRate);
    final taxAmount = subtotal - taxableAmount;
    
    // Seller details
    final sellerName = sellerData['businessName'] ?? sellerData['name'] ?? 'Dimandy';
    final sellerPhone = sellerData['phone'] ?? 'N/A';
    final sellerEmail = sellerData['email'] ?? 'N/A';
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(sellerName),
              pw.SizedBox(height: 20),
              
              // Invoice Details
              _buildInvoiceDetails(orderId, orderDate),
              pw.SizedBox(height: 20),
              
              // Seller and Customer Info
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _buildSellerInfo(sellerName, sellerPhone, sellerEmail),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: _buildCustomerInfo(customerName, customerPhone, customerAddress),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              
              // Items Table
              _buildItemsTable(items),
              pw.SizedBox(height: 20),
              
              // Totals
              _buildTotals(taxableAmount, taxAmount, shippingCharges, totalAmount),
              pw.SizedBox(height: 20),
              
              // Payment Info
              _buildPaymentInfo(paymentMethod),
              
              pw.Spacer(),
              
              // Footer
              _buildFooter(),
            ],
          );
        },
      ),
    );
    
    return pdf.save();
  }
  
  static pw.Widget _buildHeader(String sellerName) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                sellerName,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'E-Commerce Platform',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.blue700,
                ),
              ),
            ],
          ),
          pw.Text(
            'INVOICE',
            style: pw.TextStyle(
              fontSize: 32,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildInvoiceDetails(String orderId, DateTime orderDate) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Invoice Number',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'INV-${orderId.substring(0, 8).toUpperCase()}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Invoice Date',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                DateFormat('dd MMM yyyy').format(orderDate),
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildSellerInfo(String name, String phone, String email) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'FROM (SELLER)',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            name,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Phone: $phone', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Email: $email', style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
  
  static pw.Widget _buildCustomerInfo(String name, String phone, String address) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'TO (CUSTOMER)',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            name,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Phone: $phone', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text(
            address,
            style: const pw.TextStyle(fontSize: 10),
            maxLines: 3,
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildItemsTable(List<dynamic> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue900),
          children: [
            _buildTableCell('Item', isHeader: true),
            _buildTableCell('Qty', isHeader: true),
            _buildTableCell('Price', isHeader: true),
            _buildTableCell('Total', isHeader: true),
          ],
        ),
        // Items
        ...items.map((item) {
          final productName = item['productName'] ?? 'N/A';
          final quantity = item['quantity'] ?? 0;
          final price = (item['price'] as num?)?.toDouble() ?? 0.0;
          final total = price * quantity;
          
          return pw.TableRow(
            children: [
              _buildTableCell(productName),
              _buildTableCell(quantity.toString()),
              _buildTableCell('₹${price.toStringAsFixed(2)}'),
              _buildTableCell('₹${total.toStringAsFixed(2)}'),
            ],
          );
        }).toList(),
      ],
    );
  }
  
  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }
  
  static pw.Widget _buildTotals(
    double taxableAmount,
    double taxAmount,
    double shippingCharges,
    double totalAmount,
  ) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 250,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Column(
          children: [
            _buildTotalRow('Subtotal:', taxableAmount),
            pw.SizedBox(height: 4),
            _buildTotalRow('GST (18%):', taxAmount),
            pw.SizedBox(height: 4),
            _buildTotalRow('Shipping:', shippingCharges),
            pw.Divider(color: PdfColors.grey400),
            _buildTotalRow(
              'TOTAL:',
              totalAmount,
              isBold: true,
              fontSize: 14,
            ),
          ],
        ),
      ),
    );
  }
  
  static pw.Widget _buildTotalRow(
    String label,
    double amount, {
    bool isBold = false,
    double fontSize = 11,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          '₹${amount.toStringAsFixed(2)}',
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }
  
  static pw.Widget _buildPaymentInfo(String paymentMethod) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            'Payment Method: ',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            paymentMethod.toUpperCase(),
            style: const pw.TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 8),
        pw.Text(
          'Thank you for your business!',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'For any queries, please contact the seller.',
          style: const pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey600,
          ),
        ),
      ],
    );
  }
  
  static String _formatAddress(Map<String, dynamic>? address) {
    if (address == null) return 'N/A';
    
    final parts = <String>[];
    if (address['street'] != null) parts.add(address['street']);
    if (address['city'] != null) parts.add(address['city']);
    if (address['state'] != null) parts.add(address['state']);
    if (address['pincode'] != null) parts.add(address['pincode']);
    
    return parts.isEmpty ? 'N/A' : parts.join(', ');
  }
}
