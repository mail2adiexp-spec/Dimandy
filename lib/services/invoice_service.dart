import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';

class InvoiceService {
  static final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2, locale: 'en_IN');
  static final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  /// Generate and print/share a standard A4 Invoice
  static Future<void> generateInvoice(OrderModel order, {String? customerName}) async {
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();
    // Use a fallback image or logo if available in assets
    // final logo = await imageFromAssetBundle('assets/logo.png'); 

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
        ),
        build: (pw.Context context) {
          return [
            _buildInvoiceHeader(order),
            pw.SizedBox(height: 20),
            _buildCustomerAndOrderInfo(order, customerName),
            pw.SizedBox(height: 30),
            _buildItemsTable(order),
            pw.Divider(),
            _buildTotalSection(order),
            pw.Spacer(),
            _buildFooter(),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Invoice_${order.id}.pdf',
    );
  }

  /// Generate and print/share a Shipping Label (4x6 inch / A6)
  static Future<void> generateShippingLabel(OrderModel order, {String? customerName}) async {
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();
    
    final doc = pw.Document();

    // Standard Shipping Label size (4 x 6 inches)
    // 4 inch = 288 points, 6 inch = 432 points approximately.
    // Or use PdfPageFormat.a6
    final pageFormat = PdfPageFormat(101.6 * PdfPageFormat.mm, 152.4 * PdfPageFormat.mm); // 4x6 inch

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(16),
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
               pw.Center(
                child: pw.Text('DIMANDY', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Divider(),
              pw.SizedBox(height: 10),
              
              // DELIVERY ADDRESS (TO)
              pw.Text('DELIVER TO:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              // We don't have customer name separate in OrderModel, currently utilizing User ID or manual fetch. 
              // Assuming address contains name or just showing address.
              pw.Text(customerName ?? order.userId, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.Text(order.deliveryAddress, style: pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 4),
              pw.Text('Phone: ${order.phoneNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              
              pw.SizedBox(height: 20),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 20),

              // ORDER DETAILS
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ORDER ID', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text(order.id.substring(0, 8).toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text(dateFormat.format(order.orderDate), style: pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('PAYMENT', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text(
                        order.paymentMethod == 'qr_code' ? 'PREPAID (UPI)' : 'COD / CASH', 
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)
                      ),
                       pw.SizedBox(height: 4),
                      pw.Text('AMOUNT TO COLLECT', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text(
                        currencyFormat.format(order.totalAmount), 
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)
                      ),
                    ],
                  ),
                ],
              ),
              
              pw.Spacer(),
              
              // FROM ADDRESS
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('RETURN / SENDER:', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    pw.Text('DIMANDY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Text('Admin Office / Seller Hub', style: pw.TextStyle(fontSize: 10)),
                    // Add standard company address here if available
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                 child: pw.BarcodeWidget(
                  data: order.id,
                  barcode: pw.Barcode.code128(),
                  width: 200,
                  height: 40,
                  drawText: false,
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Label_${order.id}.pdf',
    );
  }

  // --- Helper Widgets for Invoice ---

  static pw.Widget _buildInvoiceHeader(OrderModel order) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('DIMANDY', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.Text('Your Trusted Shopping Partner', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('INVOICE', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('#${order.id}', style: pw.TextStyle(fontSize: 12)),
            pw.Text(dateFormat.format(order.orderDate), style: pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildCustomerAndOrderInfo(OrderModel order, String? customerName) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('BILL TO:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              // Again, using UserId/Address as Name isn't available directly in OrderModel yet. 
              // Ideally update OrderModel to store customerName.
              pw.Text(customerName ?? order.userId, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), 
              pw.Text(order.deliveryAddress),
              pw.Text(order.phoneNumber),
            ],
          ),
        ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('PAYMENT METHOD:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
              pw.Text(order.paymentMethod == 'qr_code' ? 'Online (UPI)' : 'Cash on Delivery', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
               pw.Text('STATUS:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
              pw.Text(order.status.toUpperCase()),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildItemsTable(OrderModel order) {
    return pw.TableHelper.fromTextArray(
      headers: ['Product', 'Qty', 'Price', 'Total'],
      border: null,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellHeight: 30,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      data: order.items.map((item) {
        return [
          item.productName,
          item.quantity.toString(),
          currencyFormat.format(item.price),
          currencyFormat.format(item.price * item.quantity),
        ];
      }).toList(),
    );
  }

  static pw.Widget _buildTotalSection(OrderModel order) {
    final subtotal = order.totalAmount; // Assuming totalAmount is final including everything. 
    // If delivery fee logic was "Free for customer", then subtotal = total.

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 200,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSummaryRow('Subtotal', currencyFormat.format(subtotal)),
              _buildSummaryRow('Delivery', 'FREE', isGreen: true),
              pw.Divider(),
              _buildSummaryRow('Grand Total', currencyFormat.format(subtotal), isBold: true),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value, {bool isBold = false, bool isGreen = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : null)),
        pw.Text(
          value, 
          style: pw.TextStyle(
            fontWeight: isBold ? pw.FontWeight.bold : null,
            color: isGreen ? PdfColors.green700 : null,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Divider(),
          pw.Text('Thank you for shopping with Dimandy!', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.Text('For support contact: support@dimandy.com', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        ],
      ),
    );
  }
}
