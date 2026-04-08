import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaction_model.dart';
import '../models/order_model.dart';
import '../utils/locations_data.dart';

class AdminFinancialScreen extends StatefulWidget {
  const AdminFinancialScreen({super.key});

  @override
  State<AdminFinancialScreen> createState() => _AdminFinancialScreenState();
}

class _AdminFinancialScreenState extends State<AdminFinancialScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _enhancedTransactions = [];
  
  // 8 Metrics
  double _totalProfit = 0;
  double _adminProfit = 0;
  double _partnerCommissions = 0;
  double _deliveryCost = 0;
  double _adminSales = 0;
  double _partnerSales = 0;
  double _totalPurchase = 0;
  double _totalWithdrawals = 0;
  double _totalDeliveryPayouts = 0;
  double _totalDeliveryProfit = 0;


  // Filters
  String? _selectedState;
  DateTimeRange? _selectedDateRange;
  List<String> _states = [];

  @override
  void initState() {
    super.initState();
    _loadStates();
    _fetchFinancialData();
  }

  Future<void> _loadStates() async {
    await LocationsData.loadCities();
    if (!mounted) return;
    
    final states = LocationsData.cities.map((e) => e.state).toSet().toList();
    states.sort();
    setState(() {
      _states = states;
    });
  }

  Future<void> _fetchFinancialData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Orders for Sales/Profit/Commissions
      Query orderQuery = FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'delivered');

      if (_selectedDateRange != null) {
        orderQuery = orderQuery
            .where('orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.start))
            .where('orderDate', isLessThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.end.add(const Duration(hours: 23, minutes: 59))));
      }
      
      if (_selectedState != null) {
        orderQuery = orderQuery.where('state', isEqualTo: _selectedState);
      }

      final orderSnapshot = await orderQuery.get();

      double adminSales = 0;
      double partnerSales = 0;
      double adminPurchaseCost = 0;
      double partnerCommissions = 0;
      double deliveryFees = 0; // What users paid
      double deliveryPayouts = 0; // What partners earned

      for (var doc in orderSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final fee = (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;
        final payout = (data['partnerPayout'] as num?)?.toDouble() ?? fee;
        
        deliveryFees += fee;
        deliveryPayouts += payout;
        
        final items = (data['items'] as List<dynamic>?) ?? [];
        for (var item in items) {
          final price = (item['price'] as num?)?.toDouble() ?? 0.0;
          final qty = (item['quantity'] as num?)?.toInt() ?? 1;
          final basePrice = (item['basePrice'] as num?)?.toDouble() ?? 0.0;
          final profitShare = (item['adminProfitPercentage'] as num?)?.toDouble() ?? 25.0; // Default to 25% as per business model
          final sellerId = item['sellerId'] as String? ?? 'admin';

          final itemRevenue = price * qty;
          final itemCost = basePrice * qty;
          final itemProfit = itemRevenue - itemCost;

          if (sellerId == 'admin') {
            adminSales += itemRevenue;
            adminPurchaseCost += itemCost;
          } else {
            partnerSales += itemRevenue;
            if (itemProfit > 0) {
              partnerCommissions += (itemProfit * (profitShare / 100));
            }
          }
        }
      }

      // 2. Fetch Bookings for Service Commissions
      Query bookingQuery = FirebaseFirestore.instance
          .collection('bookings')
          .where('status', isEqualTo: 'completed');

      if (_selectedDateRange != null) {
        bookingQuery = bookingQuery
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.start))
            .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.end.add(const Duration(hours: 23, minutes: 59))));
      }

      final bookingSnapshot = await bookingQuery.get();
      for (var doc in bookingSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final platformFee = (data['platformFee'] as num?)?.toDouble() ?? 0.0;
        partnerCommissions += platformFee;
      }

      // 3. Fetch Payouts for Withdrawals
      Query payoutQuery = FirebaseFirestore.instance
          .collection('payouts')
          .where('status', isEqualTo: 'approved')
          .where('type', isEqualTo: 'withdrawal');

      if (_selectedDateRange != null) {
        payoutQuery = payoutQuery
            .where('processedDate', isGreaterThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.start))
            .where('processedDate', isLessThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.end.add(const Duration(hours: 23, minutes: 59))));
      }

      final payoutSnapshot = await payoutQuery.get();
      double totalWithdrawals = 0;
      for (var doc in payoutSnapshot.docs) {
        totalWithdrawals += (doc.data() as Map<String, dynamic>)['amount'] as num;
      }

      // 3. Keep Recent Transactions for the list view
      final txSnapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final List<Map<String, dynamic>> enhancedTxns = [];
      for (var doc in txSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final tx = TransactionModel.fromMap(data, doc.id);
        
        String displayType = 'Payment';
        if (tx.description.contains('Commission')) {
          displayType = 'Commission';
        } else if ((tx.metadata ?? {})['type'] == 'delivery_earning' || tx.description.contains('Delivery')) {
          displayType = 'Delivery Fee';
        } else if ((tx.metadata ?? {})['type'] == 'product_earning') {
          displayType = 'Product Sale';
        }

        enhancedTxns.add({
          'tx': tx,
          'type': displayType,
          'amount': tx.amount,
          'storeName': (tx.metadata ?? {})['storeName'] ?? (tx.metadata ?? {})['orderId']?.toString().substring(0, 8) ?? 'N/A',
        });
      }

      if (mounted) {
        setState(() {
          _adminSales = adminSales;
          _partnerSales = partnerSales;
          _adminProfit = adminSales - adminPurchaseCost;
          _partnerCommissions = partnerCommissions;
          _deliveryCost = deliveryFees;
          _totalPurchase = adminPurchaseCost;
          _totalWithdrawals = totalWithdrawals;
          _enhancedTransactions = enhancedTxns;
          
          _totalDeliveryPayouts = deliveryPayouts;
          _totalDeliveryProfit = deliveryFees - deliveryPayouts; // Income - Expense
          
          // Total Platform Net Profit = (Own Profit on direct items + Commissions on partner items + Booking Platform Fees + Delivery Profit)
          _totalProfit = (_adminProfit + _partnerCommissions + _totalDeliveryProfit);
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching financials: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _fetchFinancialData();
    }
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Financial Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Generated by Admin Panel', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
                    if (_selectedState != null) pw.Text('Region: $_selectedState'),
                  ],
                )
              ]
          ),
          pw.SizedBox(height: 20),

          // KPIs Summary
          pw.Table.fromTextArray(
            headers: ['Category', 'Amount / Count'],
            data: [
              ['Total Net Profit', 'INR ${_totalProfit.toStringAsFixed(2)}'],
              ['Admin Sales', 'INR ${_adminSales.toStringAsFixed(2)}'],
              ['Admin Profit', 'INR ${_adminProfit.toStringAsFixed(2)}'],
              ['Partner Commissions', 'INR ${_partnerCommissions.toStringAsFixed(2)}'],
              ['Partner Sales', 'INR ${_partnerSales.toStringAsFixed(2)}'],
              ['Delivery Costs', '(INR ${_deliveryCost.toStringAsFixed(2)})'],
              ['Total Withdrawals', '(INR ${_totalWithdrawals.toStringAsFixed(2)})'],
              ['Admin Purchase Cost', 'INR ${_totalPurchase.toStringAsFixed(2)}'],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {1: pw.Alignment.centerRight},
          ),
          pw.SizedBox(height: 20),

          pw.Header(level: 1, child: pw.Text('Recent Transactions')),
          pw.Table.fromTextArray(
            headers: ['Date', 'Type', 'Store/Description', 'Amount'],
            data: _enhancedTransactions.take(100).map((e) {
              final tx = e['tx'] as TransactionModel;
              return [
                DateFormat('yyyy-MM-dd').format(tx.createdAt),
                e['type'],
                e['storeName'],
                'INR ${e['amount'].toStringAsFixed(2)}',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 10),
          ),
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Authorized Computer Generated Report', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Financial_Report.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Financial Overview',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: 'Download PDF',
                  onPressed: _generatePdf,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _fetchFinancialData,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: Colors.grey[100],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                const Icon(Icons.filter_list, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedState,
                  hint: const Text('All States'),
                  underline: const SizedBox(),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All States')),
                    ..._states.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedState = val);
                    _fetchFinancialData();
                  },
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(_selectedDateRange == null 
                    ? 'All Time' 
                    : '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d').format(_selectedDateRange!.end)}'),
                  onPressed: _selectDateRange,
                ),
                if (_selectedDateRange != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      setState(() => _selectedDateRange = null);
                      _fetchFinancialData();
                    },
                  )
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        
        // 8 KPI Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _buildKpiCard('Total Net Profit', _totalProfit, Icons.account_balance, Colors.green),
            _buildKpiCard('Admin Sales', _adminSales, Icons.trending_up, Colors.blue),
            _buildKpiCard('Admin Profit', _adminProfit, Icons.storefront, Colors.teal),
            _buildKpiCard('Partner Commissions', _partnerCommissions, Icons.account_balance_wallet, Colors.orange),
            _buildKpiCard('Partner Sales', _partnerSales, Icons.shopping_bag, Colors.indigo),
            _buildKpiCard('Total Delivery Fees', _deliveryCost, Icons.wallet, Colors.blue),
            _buildKpiCard('Delivery Partner Payouts', _totalDeliveryPayouts, Icons.payments_outlined, Colors.orange),
            _buildKpiCard('Net Delivery Profit/Loss', _totalDeliveryProfit, Icons.local_shipping, Colors.teal),
            _buildKpiCard('Withdrawals Approved', _totalWithdrawals, Icons.outbox, Colors.red),
            _buildKpiCard('Admin Purchase Cost', _totalPurchase, Icons.inventory, Colors.blueGrey),
          ],
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildKpiCard(String title, double value, IconData icon, Color color, {bool isCount = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isCount ? value.toInt().toString() : '₹${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }


}
