import 'dart:io';
import 'dart:typed_data';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../services/analytics_service.dart';
import '../utils/web_download_helper.dart';

class MasterReportsScreen extends StatelessWidget {
  const MasterReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: Theme.of(context).cardColor,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).primaryColor,
              tabs: const [
                Tab(text: 'General Overview', icon: Icon(Icons.analytics)),
                Tab(text: 'Sellers', icon: Icon(Icons.store)),
                Tab(text: 'Service Providers', icon: Icon(Icons.handyman)),
                Tab(text: 'Delivery Partners', icon: Icon(Icons.local_shipping)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                const _OverviewReportTab(),
                ReportListTab(
                  title: 'Seller Performance',
                  fetchData: (start, end) => AnalyticsService().getSellersPerformance(start: start, end: end),
                  dataLabel: 'Seller',
                ),
                ReportListTab(
                  title: 'Service Provider Performance',
                  fetchData: (start, end) => AnalyticsService().getServiceProvidersPerformance(start: start, end: end),
                  dataLabel: 'Provider',
                ),
                ReportListTab(
                  title: 'Delivery Partner Performance',
                  fetchData: (start, end) => AnalyticsService().getDeliveryPartnersPerformance(start: start, end: end),
                  dataLabel: 'Partner',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------- OVERVIEW TAB (Existing Logic) --------------------

class _OverviewReportTab extends StatefulWidget {
  const _OverviewReportTab();

  @override
  State<_OverviewReportTab> createState() => _OverviewReportTabState();
}

class _OverviewReportTabState extends State<_OverviewReportTab> {
  final AnalyticsService _analytics = AnalyticsService();
  
  String _selectedPeriod = 'All Time';
  String _selectedFormat = 'CSV';
  List<String> _selectedMetrics = [
    'Total Revenue',
    'Total Orders',
    'Products Sold',
    'Active Users'
  ];
  
  final List<String> _availableMetrics = [
    'Total Revenue',
    'Total Orders',
    'Products Sold',
    'Active Users'
  ];

  bool _isGenerating = false;

  void _onGenerateReport() async {
    setState(() => _isGenerating = true);
    await _generateAndDownloadReport(_selectedPeriod, _selectedMetrics, _selectedFormat);
    if (mounted) setState(() => _isGenerating = false);
  }

  Future<void> _generateAndDownloadReport(String period, List<String> metrics, String format) async {
    try {
      DateTime? start;
      DateTime? end;
      final now = DateTime.now();

      if (period == 'Last 30 Days') {
        start = now.subtract(const Duration(days: 30));
        end = now;
      } else if (period == 'Last 90 Days') {
        start = now.subtract(const Duration(days: 90));
        end = now;
      } else if (period == 'Last Year') {
        start = now.subtract(const Duration(days: 365));
        end = now;
      }

      if (format == 'CSV') {
        final csvData = await _analytics.downloadAnalyticsReport(
          start: start,
          end: end,
          metrics: metrics,
        );
        // await WebDownloadHelper.downloadCsv(csvData, 'admin_analytics_report'); // Broken
        await _saveOrDownloadFile(Uint8List.fromList(csvData.codeUnits), 'admin_analytics_report_${DateTime.now().millisecondsSinceEpoch}.csv', 'text/csv');
      } else {
        final pdfBytes = await _analytics.generatePdfReport(
          start: start,
          end: end,
          metrics: metrics,
        );
        // await WebDownloadHelper.downloadPdf(pdfBytes, 'admin_analytics_report'); // Broken
        await _saveOrDownloadFile(pdfBytes, 'admin_analytics_report_${DateTime.now().millisecondsSinceEpoch}.pdf', 'application/pdf');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report downloaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveOrDownloadFile(Uint8List bytes, String fileName, String mimeType) async {
    if (kIsWeb) {
      downloadFileWeb(bytes, fileName, mimeType);
    } else {
      try {
        String? filePath;
        
        if (Platform.isAndroid) {
          // Request storage permission
          var status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
          }

          // Try to save to the public Downloads folder
          final Directory directory = Directory('/storage/emulated/0/Download');
          if (await directory.exists()) {
              filePath = '${directory.path}/$fileName';
          } else {
              // Fallback to app documents
              final dir = await getApplicationDocumentsDirectory();
              filePath = '${dir.path}/$fileName';
          }
        } else if (Platform.isWindows) {
           final dir = await getDownloadsDirectory();
           filePath = '${dir?.path}/$fileName';
        } else {
           final dir = await getApplicationDocumentsDirectory();
           filePath = '${dir.path}/$fileName';
        }

        if (filePath != null) {
          final file = File(filePath);
          await file.writeAsBytes(bytes);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Saved to $filePath'), 
                backgroundColor: Colors.green,
                action: SnackBarAction(
                  label: 'OPEN',
                  textColor: Colors.white,
                  onPressed: () => OpenFilex.open(filePath!),
                ),
                duration: const Duration(seconds: 5),
              )
            );
          }
          
          // Try to open automatically
          final result = await OpenFilex.open(filePath);
          if (result.type != ResultType.done) {
             print('Could not open file: ${result.message}');
          }
        }
      } catch (e) {
        print('Error saving file: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving file: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               Icon(Icons.dashboard, size: 32, color: Theme.of(context).primaryColor),
               const SizedBox(width: 12),
               Text('Platform Overview Report', style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Export high-level metrics for the entire platform.'),
          const SizedBox(height: 24),

          // --- Live Summary Cards ---
          FutureBuilder<PlatformMetrics>(
            future: _analytics.getPlatformMetrics(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: LinearProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Error loading live metrics: ${snapshot.error}', style: const TextStyle(color: Colors.red));
              }

              final data = snapshot.data!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Live Platform Status', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final crossAxisCount = width < 600 ? 2 : 4;
                      const spacing = 12.0;
                      final totalSpacing = (crossAxisCount - 1) * spacing;
                      final itemWidth = (width - totalSpacing) / crossAxisCount;
                      const itemHeight = 160.0;
                      final aspectRatio = itemWidth / itemHeight;

                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                        childAspectRatio: aspectRatio,
                        children: [
                          _buildSummaryCard(context, 'Sellers', data.totalSellers, data.activeSellers, Icons.store),
                          _buildSummaryCard(context, 'Users', data.totalUsers, data.activeUsers, Icons.person),
                          _buildSummaryCard(context, 'Providers', data.totalProviders, data.activeProviders, Icons.handyman),
                          _buildSummaryCard(context, 'Delivery Partners', data.totalDrivers, data.activeDrivers, Icons.motorcycle),
                          _buildDetailedFeeCard(context, 'Platform Fees', data.totalPlatformFees, data.sellerPlatformFees, data.servicePlatformFees),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Time Period', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedPeriod,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'Last 30 Days', child: Text('Last 30 Days')),
                      DropdownMenuItem(value: 'Last 90 Days', child: Text('Last 90 Days')),
                      DropdownMenuItem(value: 'Last Year', child: Text('Last Year')),
                      DropdownMenuItem(value: 'All Time', child: Text('All Time')),
                    ],
                    onChanged: (val) => setState(() => _selectedPeriod = val!),
                  ),
                  const SizedBox(height: 24),
                  
                  const Text('File Format', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                     children: [
                       Expanded(
                         child: RadioListTile<String>(
                           title: const Text('CSV (Excel)'),
                           value: 'CSV',
                           groupValue: _selectedFormat,
                           onChanged: (val) => setState(() => _selectedFormat = val!),
                         ),
                       ),
                       Expanded(
                         child: RadioListTile<String>(
                           title: const Text('PDF Document'),
                           value: 'PDF',
                           groupValue: _selectedFormat,
                           onChanged: (val) => setState(() => _selectedFormat = val!),
                         ),
                       ),
                     ],
                  ),
                  const SizedBox(height: 24),
                  
                  const Text('Include Metrics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: _availableMetrics.map((metric) {
                      return FilterChip(
                        label: Text(metric),
                        selected: _selectedMetrics.contains(metric),
                        onSelected: (bool selected) {
                          setState(() {
                            if (selected) {
                              _selectedMetrics.add(metric);
                            } else {
                              _selectedMetrics.remove(metric);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _onGenerateReport,
                      icon: _isGenerating 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download),
                      label: Text(_isGenerating ? 'Generating...' : 'Download Overview Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, int total, int active, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            const Spacer(),
            Text('Total: $total', style: const TextStyle(fontSize: 12)),
            Text('Active: $active', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedFeeCard(BuildContext context, String title, double total, double sellerFees, double serviceFees) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Icon(Icons.monetization_on, color: Colors.green[700]),
                    const Tooltip(message: 'Estimated 10% of revenue', child: Icon(Icons.info_outline, size: 16, color: Colors.grey)),
                ]
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              '₹${total.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 16, color: Colors.green[800], fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Seller: ₹${sellerFees.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text('Service: ₹${serviceFees.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// -------------------- GENERIC REPORT LIST TAB --------------------



class ReportListTab extends StatefulWidget {
  final String title;
  final String dataLabel;
  final Future<List<EntityPerformance>> Function(DateTime? start, DateTime? end) fetchData;

  const ReportListTab({
    super.key,
    required this.title,
    required this.dataLabel,
    required this.fetchData,
  });

  @override
  State<ReportListTab> createState() => _ReportListTabState();
}

class _ReportListTabState extends State<ReportListTab> {
  DateTimeRange? _dateRange;
  List<EntityPerformance>? _data;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.fetchData(_dateRange?.start, _dateRange?.end);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _loadData();
    }
  }
  
  void _clearDateRange() {
     setState(() => _dateRange = null);
     _loadData();
  }

  Future<void> _downloadCsv() async {
    if (_data == null || _data!.isEmpty) return;
    
    final csvContent = AnalyticsService().generateEntityCsvReport(_data!, widget.title);
    final fileName = '${widget.title.replaceAll(' ', '_')}_Report_${DateTime.now().millisecondsSinceEpoch}.csv';
    
    // Reuse the save/download logic
    if (kIsWeb) {
      downloadFileWeb(Uint8List.fromList(csvContent.codeUnits), fileName, 'text/csv');
    } else {
      Directory? directory;
      if (Platform.isWindows) {
        directory = await getDownloadsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory != null) {
        final path = '${directory.path}/$fileName';
        final file = File(path);
        await file.writeAsString(csvContent);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to $path'), backgroundColor: Colors.green));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Controls
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
             child: Padding(
               padding: const EdgeInsets.all(12),
               child: Row(
                 children: [
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                         if (_dateRange != null)
                           Text(
                             '${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d, y').format(_dateRange!.end)}',
                             style: TextStyle(color: Colors.grey[600], fontSize: 12),
                           )
                         else
                           Text('All Time', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                       ],
                     ),
                   ),
                   IconButton(
                     icon: const Icon(Icons.date_range),
                     onPressed: _pickDateRange,
                     tooltip: 'Filter by Date',
                   ),
                   if (_dateRange != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearDateRange,
                        tooltip: 'Clear Date Filter',
                      ),
                   const SizedBox(width: 8),
                   ElevatedButton.icon(
                     onPressed: (_data == null || _data!.isEmpty) ? null : _downloadCsv,
                     icon: const Icon(Icons.file_download),
                     label: const Text('Export CSV'),
                   ),
                   const SizedBox(width: 8),
                   IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadData,
                      tooltip: 'Refresh',
                   ),
                 ],
               ),
             ),
          ),
        ),
        
        // Data Table
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _data == null || _data!.isEmpty
                  ? const Center(child: Text('No data available for selected period'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: [
                            DataColumn(label: Text(widget.dataLabel)), // Name
                            const DataColumn(label: Text('Count'), numeric: true),
                            const DataColumn(label: Text('Revenue/Earnings'), numeric: true),
                            const DataColumn(label: Text('Items/Qty'), numeric: true),
                          ],
                          rows: _data!.map((item) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                                      Text(item.id.length > 8 ? '${item.id.substring(0,8)}...' : item.id, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  )
                                ),
                                DataCell(Text(item.count.toString())),
                                DataCell(Text('₹${item.revenue.toStringAsFixed(2)}')),
                                DataCell(Text(item.items.toString())),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}
