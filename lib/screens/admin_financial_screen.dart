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
  double _storeProfit = 0;
  double _sellerCommission = 0;
  double _serviceCommission = 0;
  double _deliveryCost = 0;
  double _totalProfit = 0;
  double _totalPurchase = 0;
  double _totalSell = 0;
  int _totalServices = 0;

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
      Query query = FirebaseFirestore.instance
          .collection('transactions')
          .orderBy('createdAt', descending: true);

      if (_selectedDateRange != null) {
        query = query
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.start))
            .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.end.add(const Duration(days: 1))));
      } else {
        query = query.limit(500); 
      }

      final querySnapshot = await query.get();

      // Initialize totals
      double storeRevenue = 0;
      double storePurchaseCost = 0;
      double sellerComm = 0;
      double serviceComm = 0;
      double deliveryFeePaid = 0;
      double totalSalesRevenue = 0;
      int serviceCount = 0;

      final List<Map<String, dynamic>> enhancedTxns = [];
      final Map<String, Map<String, dynamic>> _userCache = {};
      final Map<String, Map<String, dynamic>> _orderCache = {};

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final tx = TransactionModel.fromMap(data, doc.id);
        final metadata = tx.metadata ?? {};
        
        bool isRelevant = false;
        double amount = tx.amount;
        String typeLabel = '';
        
        // --- 1. Identify Logic ---
        
        // Delivery Cost
        if (metadata['source'] == 'delivery_fee' || tx.description.toLowerCase().contains('delivery payout')) {
          isRelevant = true;
          typeLabel = 'Delivery Cost';
          deliveryFeePaid += tx.amount;
        } 
        
        // Order Related
        else if (metadata.containsKey('orderId')) {
          isRelevant = true;
          final orderId = metadata['orderId'];
          
          // Check if it's a commission (debit from seller) or payment
          if (tx.description.contains('Commission') || metadata.containsKey('platformFee')) {
            // It's a commission
            final fee = (metadata['platformFee'] as num?)?.toDouble() ?? tx.amount;
            if (metadata['isPlatformOwned'] == true) {
               // Should not happen for commissions usually, but handle if so
               typeLabel = 'Store Owned';
            } else {
               typeLabel = 'Seller Commission';
               sellerComm += fee;
            }
          } else if (tx.type == TransactionType.credit) {
            // It's a direct payment
             typeLabel = 'Order Payment';
             totalSalesRevenue += tx.amount;
             
             // Check ownership via seller profile
             final sellerId = metadata['sellerId'] ?? tx.userId;
             Map<String, dynamic>? uData;
             if (_userCache.containsKey(sellerId)) {
               uData = _userCache[sellerId];
             } else {
               final uDoc = await FirebaseFirestore.instance.collection('users').doc(sellerId).get();
               if (uDoc.exists) {
                 uData = uDoc.data();
                 _userCache[sellerId] = uData!;
               }
             }

             final role = (uData?['role'] as String? ?? '').toLowerCase();
             final platformRoles = ['admin', 'super_admin', 'state_admin', 'store_manager', 'core_staff', 'manager'];
             
             if (platformRoles.contains(role)) {
               typeLabel = 'Store Owned';
               storeRevenue += tx.amount;
               
               // Calculate Purchase Cost for this order
               if (!_orderCache.containsKey(orderId)) {
                 final oDoc = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
                 if (oDoc.exists) {
                   _orderCache[orderId] = oDoc.data()!;
                 }
               }
               
               if (_orderCache.containsKey(orderId)) {
                 final oData = _orderCache[orderId]!;
                 final items = (oData['items'] as List<dynamic>?) ?? [];
                 for (var item in items) {
                    final itemBasePrice = (item['basePrice'] as num?)?.toDouble() ?? 0.0;
                    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                    storePurchaseCost += (itemBasePrice * qty);
                 }
               }
             }
          }
        }
        
        // Service Related
        else if (metadata.containsKey('bookingId')) {
          isRelevant = true;
          serviceCount++;
          if (tx.description.contains('Commission') || metadata.containsKey('platformFee')) {
            final fee = (metadata['platformFee'] as num?)?.toDouble() ?? tx.amount;
            typeLabel = 'Service Commission';
            serviceComm += fee;
          } else {
            typeLabel = 'Service Payment';
            totalSalesRevenue += tx.amount;
          }
        }

        if (!isRelevant) continue;

        enhancedTxns.add({
          'tx': tx,
          'type': typeLabel,
          'amount': amount,
          'storeName': metadata['storeName'] ?? 'N/A',
        });
      }

      if (mounted) {
        setState(() {
          _enhancedTransactions = enhancedTxns;
          _storeProfit = storeRevenue - storePurchaseCost;
          _sellerCommission = sellerComm;
          _serviceCommission = serviceComm;
          _deliveryCost = deliveryFeePaid;
          _totalPurchase = storePurchaseCost;
          _totalSell = totalSalesRevenue;
          _totalServices = serviceCount;
          _totalProfit = _storeProfit + _sellerCommission + _serviceCommission - _deliveryCost;
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
              ['Total Profit', 'INR ${_totalProfit.toStringAsFixed(2)}'],
              ['Store Profit', 'INR ${_storeProfit.toStringAsFixed(2)}'],
              ['Seller Commission', 'INR ${_sellerCommission.toStringAsFixed(2)}'],
              ['Service Commission', 'INR ${_serviceCommission.toStringAsFixed(2)}'],
              ['Delivery Cost', '(INR ${_deliveryCost.toStringAsFixed(2)})'],
              ['Total Purchase (Buying Cost)', 'INR ${_totalPurchase.toStringAsFixed(2)}'],
              ['Total Sell (Revenue)', 'INR ${_totalSell.toStringAsFixed(2)}'],
              ['Total Services Booked', _totalServices.toString()],
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
            _buildKpiCard('Total Profit', _totalProfit, Icons.account_balance_wallet, Colors.green),
            _buildKpiCard('Store Profit', _storeProfit, Icons.storefront, Colors.blue),
            _buildKpiCard('Seller Commission', _sellerCommission, Icons.people, Colors.deepPurple),
            _buildKpiCard('Service Commission', _serviceCommission, Icons.build, Colors.orange),
            _buildKpiCard('Delivery Cost', _deliveryCost, Icons.local_shipping, Colors.red),
            _buildKpiCard('Total Purchase', _totalPurchase, Icons.shopping_basket, Colors.blueGrey),
            _buildKpiCard('Total Sell', _totalSell, Icons.trending_up, Colors.indigo),
            _buildKpiCard('Total Services', _totalServices.toDouble(), Icons.event_available, Colors.teal, isCount: true),
          ],
        ),

        const SizedBox(height: 32),
        Text(
          'Transactions (${_enhancedTransactions.length})',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: _enhancedTransactions.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No earning records found'),
                  ),
                )
              : Column(
                  children: List.generate(_enhancedTransactions.length, (index) {
                    final item = _enhancedTransactions[index];
                    final tx = item['tx'] as TransactionModel;
                    final amount = item['amount'] as double;
                    final type = item['type'] as String;
                    
                    return Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getColorForType(type).withValues(alpha: 0.1),
                            child: Icon(_getIconForType(type), color: _getColorForType(type), size: 20),
                          ),
                          title: Text(item['storeName'] != 'N/A' ? item['storeName'] : type),
                          subtitle: Text(DateFormat('MMM d, yyyy HH:mm').format(tx.createdAt)),
                          trailing: Text(
                            '₹${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              color: tx.type == TransactionType.debit ? Colors.red : Colors.green, 
                              fontSize: 16
                            ),
                          ),
                        ),
                        if (index < _enhancedTransactions.length - 1) const Divider(height: 1),
                      ],
                    );
                  }),
                ),
        ),
        const SizedBox(height: 80),
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

  Color _getColorForType(String type) {
    if (type.contains('Delivery')) return Colors.red;
    if (type.contains('Store')) return Colors.blue;
    if (type.contains('Seller')) return Colors.deepPurple;
    if (type.contains('Service')) return Colors.orange;
    return Colors.green;
  }

  IconData _getIconForType(String type) {
    if (type.contains('Delivery')) return Icons.local_shipping;
    if (type.contains('Store')) return Icons.store;
    if (type.contains('Seller')) return Icons.people;
    if (type.contains('Service')) return Icons.build;
    return Icons.attach_money;
  }
}
