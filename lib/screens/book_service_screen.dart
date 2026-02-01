import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../models/product_model.dart';
import '../models/product_model.dart';
import 'cart_screen.dart';
import '../utils/locations_data.dart';
import '../widgets/location_autocomplete.dart';

class BookServiceScreen extends StatefulWidget {
  static const routeName = '/book-service';

  final String serviceName;
  final String providerName;
  final String providerId;
  final String? providerImage;
  final double ratePerKm; // Rate per kilometer
  final double minBookingAmount; // Minimum booking amount
  final double preBookingAmount; // Pre-booking/advance amount

  const BookServiceScreen({
    super.key,
    required this.serviceName,
    required this.providerName,
    required this.providerId,
    this.providerImage,
    this.ratePerKm = 0.0,
    this.minBookingAmount = 0.0,
    this.preBookingAmount = 0.0,
  });

  @override
  State<BookServiceScreen> createState() => _BookServiceScreenState();
}

class _BookServiceScreenState extends State<BookServiceScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _pickupLocationController = TextEditingController();
  final _dropLocationController = TextEditingController();

  final _distanceController = TextEditingController();
  
  City? _pickupCity;
  City? _dropCity;

  void _calculateDistance() {
    if (_pickupCity != null && _dropCity != null) {
      final dist = LocationsData.calculateDistance(
        _pickupCity!.lat, 
        _pickupCity!.lng, 
        _dropCity!.lat, 
        _dropCity!.lng
      );
      setState(() {
        _distanceController.text = dist.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Distance calculated: $dist km')),
      );
    }
  }
  
  // Payment method selection
  String _paymentMethod = 'prebooking'; // 'prebooking' or 'full'
  
  @override
  void initState() {
    super.initState();
    print('DEBUG BOOKING SCREEN: ratePerKm=${widget.ratePerKm}, minBookingAmount=${widget.minBookingAmount}, preBookingAmount=${widget.preBookingAmount}');
  }
  
  double get _calculatedTotal {
    // For vehicle services: Rate × Distance, with minimum check
    print('DEBUG CALC: ratePerKm=${widget.ratePerKm}, distance=${_distanceController.text}, minBookingAmount=${widget.minBookingAmount}');
    final dist = double.tryParse(_distanceController.text) ?? 0;
    final calculated = widget.ratePerKm * dist;
    // Apply minimum if set, otherwise use calculated amount
    final total = widget.minBookingAmount > 0 
        ? (calculated > widget.minBookingAmount ? calculated : widget.minBookingAmount)
        : calculated;
    print('DEBUG CALC: total = $total (max of $calculated or minimum ${widget.minBookingAmount})');
    return total;
  }

  bool get _isVehicleService {
    final serviceLower = widget.serviceName.toLowerCase();
    return serviceLower.contains('car') ||
        serviceLower.contains('bike') ||
        serviceLower.contains('auto') ||
        serviceLower.contains('taxi') ||
        serviceLower.contains('cab') ||
        serviceLower.contains('vehicle') ||
        serviceLower.contains('vehical') || // Handle common typo
        serviceLower.contains('transport');
  }

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    _pickupLocationController.dispose();
    _dropLocationController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('hh:mm a').format(dt);
  }

  void _confirmBooking() {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Vehicle service validation
    if (_isVehicleService) {
      if (_pickupLocationController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter pickup location'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_dropLocationController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter drop location'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      if (_distanceController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please enter approximate distance'), 
          backgroundColor: Colors.red,
        ));
        return;
      }
    } else {
      // Regular service validation
      if (_addressController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your address'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Add calculated amount to cart based on payment method
    final finalCharge = _calculatedTotal >= 50 ? _calculatedTotal : 50.0;
    
    // Determine the amount to charge now based on payment method
    final amountToCharge = _paymentMethod == 'prebooking' && widget.preBookingAmount > 0
        ? widget.preBookingAmount
        : finalCharge;
    
    final product = Product(
      id: 'svc_${widget.serviceName.replaceAll(' ', '_').toLowerCase()}_${widget.providerName.replaceAll(' ', '_').toLowerCase()}',
      name: '${widget.serviceName} Booking - ${widget.providerName}',
      description: 'Service booking (Dist: ${_distanceController.text}km)',
      price: amountToCharge,
      imageUrl:
          widget.providerImage ??
          'https://via.placeholder.com/120x120.png?text=Service',
      category: 'Services',
      unit: 'service',
      sellerId: widget.providerId,
    );

    // Collect booking metadata
    final metadata = {
      'bookingDate': _selectedDate!.toIso8601String(),
      'bookingTime': '${_selectedTime!.hour}:${_selectedTime!.minute}',
      'formattedDate': _formatDate(_selectedDate!),
      'formattedTime': _formatTime(_selectedTime!),
      'notes': _notesController.text.trim(),
      'address': _isVehicleService 
          ? 'Pickup: ${_pickupLocationController.text}, Drop: ${_dropLocationController.text}' 
          : _addressController.text.trim(),
      'serviceType': _isVehicleService ? 'transport' : 'general',
      'pickupLocation': _isVehicleService ? _pickupLocationController.text.trim() : null,
      'dropLocation': _isVehicleService ? _dropLocationController.text.trim() : null,
      'distanceKm': _isVehicleService ? _distanceController.text.trim() : null,
      'ratePerKm': widget.ratePerKm,
      'paymentMethod': _paymentMethod,
      'preBookingAmount': widget.preBookingAmount,
      'totalAmount': finalCharge,
      'remainingAmount': _paymentMethod == 'prebooking' 
          ? finalCharge - widget.preBookingAmount 
          : 0.0,
    };

    context.read<CartProvider>().addProduct(product, metadata: metadata);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _paymentMethod == 'prebooking'
              ? 'Added to cart: Pre-booking ₹${amountToCharge.toStringAsFixed(0)} (Remaining: ₹${(finalCharge - amountToCharge).toStringAsFixed(0)} - Pay on Trip)'
              : 'Added to cart: Full amount ₹${finalCharge.toStringAsFixed(0)}',
        ),
      ),
    );

    // Navigate to cart
    Navigator.pushReplacementNamed(context, CartScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: BookServiceScreen build. Service: ${widget.serviceName}, RatePerKm: ${widget.ratePerKm}'); // DEBUG PRINT
    return Scaffold(
      appBar: AppBar(title: const Text('Book Service'), elevation: 2),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service Provider Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blue[100],
                      child: widget.providerImage != null
                          ? ClipOval(
                              child: Image.network(
                                widget.providerImage!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.person, size: 30);
                                },
                              ),
                            )
                          : const Icon(Icons.person, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.serviceName,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.providerName,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Date Selection
            Text(
              'Select Date',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDate != null
                            ? _formatDate(_selectedDate!)
                            : 'Select date',
                        style: TextStyle(
                          fontSize: 16,
                          color: _selectedDate != null
                              ? Colors.black
                              : Colors.grey,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Time Selection
            Text(
              'Select Time',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _selectTime,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedTime != null
                            ? _formatTime(_selectedTime!)
                            : 'Select time',
                        style: TextStyle(
                          fontSize: 16,
                          color: _selectedTime != null
                              ? Colors.black
                              : Colors.grey,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Conditional fields based on service type
            if (_isVehicleService) ...[
              // Pickup Location
              LocationAutocompleteField(
                label: 'Pickup Location',
                icon: Icons.my_location,
                controller: _pickupLocationController,
                onSelected: (City city) {
                  setState(() {
                    _pickupCity = city;
                    _pickupLocationController.text = city.toString();
                    _calculateDistance();
                  });
                },
                onChanged: (val) {
                   // If user types manually, clear the city object to ensure we don't calculate wrong distance using old coordinates
                   // unless the text still matches perfectly. 
                   if (_pickupCity != null && val != _pickupCity.toString()) {
                     _pickupCity = null; 
                   }
                },
              ),
              const SizedBox(height: 16),

              // Drop Location
              LocationAutocompleteField(
                label: 'Drop Location',
                icon: Icons.location_on,
                controller: _dropLocationController,
                onSelected: (City city) {
                  setState(() {
                    _dropCity = city;
                    _dropLocationController.text = city.toString();
                    _calculateDistance();
                  });
                },
                onChanged: (val) {
                   if (_dropCity != null && val != _dropCity.toString()) {
                     _dropCity = null;
                   }
                },
              ),
              const SizedBox(height: 16),
              
              // Distance field - always required for vehicle services
              Text(
                'Approximate Distance (km) *',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _distanceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'e.g. 5.5',
                  suffixText: 'km',
                  helperText: _distanceController.text.trim().isEmpty
                      ? 'Rate: ₹${widget.ratePerKm}/km${widget.minBookingAmount > 0 ? ", Min: ₹${widget.minBookingAmount.toStringAsFixed(0)}" : ""}'
                      : () {
                          final dist = double.tryParse(_distanceController.text) ?? 0;
                          final calculated = widget.ratePerKm * dist;
                          final isMinApplied = widget.minBookingAmount > 0 && calculated < widget.minBookingAmount;
                          return 'Amount: ₹${_calculatedTotal.toStringAsFixed(0)}${isMinApplied ? " (Minimum applied)" : ""}${widget.preBookingAmount > 0 ? " | Pre-booking: ₹${widget.preBookingAmount.toStringAsFixed(0)}" : ""}';
                        }(),
                  helperStyle: _distanceController.text.trim().isNotEmpty
                      ? const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ] else ...[
              // Service Address for non-vehicle services
              Text(
                'Service Address',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter your complete address',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Additional Notes
            Text(
              'Additional Notes (Optional)',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Any special instructions or requirements',
                prefixIcon: const Icon(Icons.note),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
            ),
            const SizedBox(height: 24),

            // Payment Method Selection (only for vehicle services with pre-booking)
            if (_isVehicleService && widget.preBookingAmount > 0) ...[
              Text(
                'Payment Method',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text(
                        'Pre-booking Amount Only',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Pay ₹${widget.preBookingAmount.toStringAsFixed(0)} now\nRemaining amount: Pay on Trip Completion',
                        style: const TextStyle(fontSize: 12, color: Colors.green),
                      ),
                      value: 'prebooking',
                      groupValue: _paymentMethod,
                      activeColor: Colors.green,
                      onChanged: (value) {
                        setState(() {
                          _paymentMethod = value!;
                        });
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<String>(
                      title: const Text(
                        'Full Payment',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Pay full amount ₹${_calculatedTotal.toStringAsFixed(0)} now',
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: 'full',
                      groupValue: _paymentMethod,
                      onChanged: (value) {
                        setState(() {
                          _paymentMethod = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, -4),
              blurRadius: 10,
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirmBooking,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Confirm Booking',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
