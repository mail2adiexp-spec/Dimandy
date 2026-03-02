import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaction_model.dart';
import '../utils/locations_data.dart';

class AdminFinancialScreen extends StatefulWidget {
  const AdminFinancialScreen({super.key});

  @override
  State<AdminFinancialScreen> createState() => _AdminFinancialScreenState();
}

class _AdminFinancialScreenState extends State<AdminFinancialScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _enhancedTransactions = [];
  double _totalEarnings = 0;
  double _sellerEarnings = 0;
  double _storeProfit = 0; // New variable for Direct Store Sales
  double _serviceEarnings = 0;
  double _deliveryCosts = 0;

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

  int _orderCount = 0;
  int _serviceCount = 0;
  int _deliveryCount = 0;



  Future<void> _fetchFinancialData() async {
    setState(() => _isLoading = true);
    try {
      Query query = FirebaseFirestore.instance
          .collection('transactions')
          .orderBy('createdAt', descending: true);

      // Date Filter
      if (_selectedDateRange != null) {
        query = query
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.start))
            .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.end.add(const Duration(days: 1))));
      } else {
        query = query.limit(500); 
      }

      final querySnapshot = await query.get();

      final List<Map<String, dynamic>> enhancedTxns = [];
      double sellerTotal = 0; 
      double storeTotal = 0;  
      double serviceTotal = 0;
      double deliveryTotal = 0;
      
      int orders = 0;
      int services = 0;
      int deliveries = 0;

      final Map<String, Map<String, String>> _storeCache = {}; 

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final tx = TransactionModel.fromMap(data, doc.id);
        final metadata = tx.metadata ?? {};
        
        // Temporary holding vars
        bool isRelevant = false;
        double tempAmount = 0.0;
        String tempType = '';
        
        // 1. Identify Type & Potential Amount
        if (metadata.containsKey('platformFee')) {
          final fee = (metadata['platformFee'] as num?)?.toDouble() ?? 0.0;
          if (fee > 0) {
            isRelevant = true;
            tempAmount = fee;
            if (metadata.containsKey('isPlatformOwned') && metadata['isPlatformOwned'] == true) {
               tempType = 'Store Owned Earnings';
            } else if (metadata.containsKey('orderId')) {
              tempType = 'Order Commission';
            } else if (metadata.containsKey('bookingId')) {
              tempType = 'Service Fee';
            }
          }
        } else if (metadata['source'] == 'delivery_fee') {
          isRelevant = true;
          tempAmount = tx.amount;
          tempType = 'Delivery Payout';
        }

        if (!isRelevant) continue;

        // 2. Resolve State/Store
        String storeName = 'N/A';
        String state = 'Unknown';
          
        if (metadata.containsKey('sellerId')) {
            final sellerId = metadata['sellerId'];
            if (_storeCache.containsKey(sellerId)) {
              storeName = _storeCache[sellerId]!['name']!;
              state = _storeCache[sellerId]!['state']!;
            } else {
              try {
                 final userDoc = await FirebaseFirestore.instance.collection('users').doc(sellerId).get();
                 if (userDoc.exists) {
                   final storeId = userDoc.data()?['storeId'];
                   if (storeId != null) {
                     final storeDoc = await FirebaseFirestore.instance.collection('stores').doc(storeId).get();
                     if (storeDoc.exists) {
                       final sData = storeDoc.data()!;
                       storeName = sData['name'] ?? 'Unknown Store';
                       state = sData['state'] ?? 'Unknown';
                     }
                   }
                 }
                 _storeCache[sellerId] = {'name': storeName, 'state': state};
              } catch (e) { }
            }
        }

        // 3. Apply State Filter
        if (_selectedState != null && state != _selectedState && state != 'Unknown') {
          continue; 
        }

        // 4. Add to Totals and List
        if (tempType == 'Store Owned Earnings') {
            storeTotal += tempAmount;
            orders++;
        } else if (tempType == 'Order Commission') {
            sellerTotal += tempAmount;
            orders++;
        } else if (tempType == 'Service Fee') {
            serviceTotal += tempAmount;
            services++;
        } else if (tempType == 'Delivery Payout') {
            deliveryTotal += tempAmount;
            deliveries++;
        }

        enhancedTxns.add({
            'tx': tx,
            'type': tempType,
            'amount': tempAmount,
            'storeName': storeName,
            'state': state,
            'metadata': metadata,
            'isDelivery': tempType == 'Delivery Payout',
        });
      }

      if (mounted) {
        setState(() {
          _enhancedTransactions = enhancedTxns;
          _sellerEarnings = sellerTotal;
          _storeProfit = storeTotal;
          _serviceEarnings = serviceTotal;
          _deliveryCosts = deliveryTotal;
          _totalEarnings = (sellerTotal + storeTotal + serviceTotal) - deliveryTotal;
          _orderCount = orders;
          _serviceCount = services;
          _deliveryCount = deliveries;
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
          
          // KPIs
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _pdfKpiCard('Total Orders', _orderCount.toString(), PdfColors.blue),
              _pdfKpiCard('Total Services', _serviceCount.toString(), PdfColors.orange),
              _pdfKpiCard('Deliveries', _deliveryCount.toString(), PdfColors.red),
            ]
          ),
          pw.SizedBox(height: 20),

          // Summary Table
          pw.Table.fromTextArray(
            headers: ['Category', 'Amount'],
            data: [
              ['Net Earnings', 'INR ${_totalEarnings.toStringAsFixed(2)}'],
              ['Store Owned Earnings', 'INR ${_storeProfit.toStringAsFixed(2)}'],
              ['Commissions', 'INR ${_sellerEarnings.toStringAsFixed(2)}'],
              ['Service Fees', 'INR ${_serviceEarnings.toStringAsFixed(2)}'],
              ['Delivery Costs', '(INR ${_deliveryCosts.toStringAsFixed(2)})'],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {1: pw.Alignment.centerRight},
          ),
          pw.SizedBox(height: 20),
          
          pw.Header(level: 1, child: pw.Text('Recent Transactions')),
          pw.Table.fromTextArray(
            headers: ['Date', 'Type', 'Store', 'Amount'],
            data: _enhancedTransactions.take(100).map((e) {
              final tx = e['tx'] as TransactionModel;
              return [
                DateFormat('yyyy-MM-dd').format(tx.createdAt),
                e['type'],
                e['storeName'],
                '${e['isDelivery'] ? '-' : '+'} INR ${e['amount'].toStringAsFixed(2)}',
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

  pw.Widget _pdfKpiCard(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
        ]
      )
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
        Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildSummaryCard('Net Earnings', _totalEarnings, _totalEarnings >= 0 ? Colors.green : Colors.red)),
                const SizedBox(width: 16),
                Expanded(child: _buildSummaryCard('Store Owned Earnings', _storeProfit, Colors.blue)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildSummaryCard('Commissions', _sellerEarnings, Colors.deepPurple)),
                const SizedBox(width: 16),
                Expanded(child: _buildSummaryCard('Service Fees', _serviceEarnings, Colors.orange)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildSummaryCard('Delivery Costs', _deliveryCosts, Colors.redAccent)),
                Expanded(child: Container()),
              ],
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text(
          'Transactions (${_enhancedTransactions.length})',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
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
                    final isDelivery = item['isDelivery'] as bool;
                    final amount = item['amount'] as double;
                    
                    return Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isDelivery ? Colors.red[50] : Colors.green[50],
                            child: Icon(
                              isDelivery ? Icons.local_shipping : Icons.attach_money, 
                              color: isDelivery ? Colors.red : Colors.green,
                              size: 20,
                            ),
                          ),
                          title: Text(item['storeName'] != 'N/A' ? item['storeName'] : item['type']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${DateFormat('MMM d, yyyy HH:mm').format(tx.createdAt)} • ${item['state']}'),
                              if (item['storeName'] != 'N/A') Text(item['type'], style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          trailing: Text(
                            '${isDelivery ? '-' : '+'}₹${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              color: isDelivery ? Colors.red : Colors.green, 
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
        const SizedBox(height: 80), // Extra bottom padding to ensure FAB or navigation doesn't block
      ],
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monetization_on, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 24, 
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
