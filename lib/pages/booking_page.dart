import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class BookingPage extends StatefulWidget {
  final Map<String, dynamic> worker;
  final String searchQuery;
  final String detectedCategory;

  const BookingPage({
    Key? key,
    required this.worker,
    required this.searchQuery,
    required this.detectedCategory,
  }) : super(key: key);

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isBooking = false;

  int _selectedDateIndex = 0;
  int _selectedTimeIndex = 1; // Default to 10:00 AM

  final List<Map<String, String>> _dates = [];
  final List<String> _times = [
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '01:00 PM',
    '02:00 PM',
    '04:00 PM',
  ];

  // Track unavailable time slots (index based)
  final List<int> _unavailableTimeSlots = [5]; // 04:00 PM unavailable

  @override
  void initState() {
    super.initState();
    _generateDates();
  }

  void _generateDates() {
    final now = DateTime.now();
    final weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    for (int i = 0; i < 7; i++) {
      final date = now.add(Duration(days: i));
      _dates.add({
        'day': weekdays[date.weekday % 7],
        'date': date.day.toString(),
        'month': months[date.month - 1],
        'year': date.year.toString(),
      });
    }
  }

  String get _selectedMonth {
    if (_dates.isEmpty) return '';
    return '${_dates[_selectedDateIndex]['month']} ${_dates[_selectedDateIndex]['year']}';
  }

  String get _formattedSelectedDate {
    if (_dates.isEmpty) return '';
    final date = _dates[_selectedDateIndex];
    return '${date['day']}, ${date['month']!.substring(0, 3)} ${date['date']}';
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.worker['name'] ?? 'Worker';
    final title = widget.worker['title'] ?? '${widget.detectedCategory} Professional';
    final experience = widget.worker['experience'] ?? '5 years exp.';

    // Handle hourly rate
    int hourlyRate = 85;
    final rateValue = widget.worker['hourly_rate'] ?? widget.worker['rate'];
    if (rateValue != null) {
      if (rateValue is num) {
        hourlyRate = rateValue.toInt();
      } else if (rateValue is String) {
        hourlyRate = int.tryParse(rateValue.replaceAll(RegExp(r'[^\d]'), '')) ?? 85;
      }
    }

    // Handle rating
    double rating = 4.9;
    if (widget.worker['rating'] != null) {
      if (widget.worker['rating'] is num) {
        rating = widget.worker['rating'].toDouble();
      } else if (widget.worker['rating'] is String) {
        rating = double.tryParse(widget.worker['rating']) ?? 4.9;
      }
    }

    final bookingFee = 2.50;
    final totalEstimate = hourlyRate + bookingFee;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Book Appointment',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Worker Info Card
            _buildWorkerCard(name, title, experience, hourlyRate, rating),

            const SizedBox(height: 24),

            // Date Selection
            _buildDateSelection(),

            const SizedBox(height: 24),

            // Time Selection
            _buildTimeSelection(),

            const SizedBox(height: 24),

            // Booking Summary
            _buildBookingSummary(hourlyRate, bookingFee, totalEstimate),

            const SizedBox(height: 16),

            // Info Notice
            _buildInfoNotice(),

            const SizedBox(height: 100), // Space for bottom button
          ],
        ),
      ),
      bottomSheet: _buildBottomSheet(totalEstimate),
    );
  }

  Widget _buildWorkerCard(String name, String title, String experience, int hourlyRate, double rating) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar with PRO badge
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'PRO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'GOLD TIER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 6,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$title • $experience',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '\$$hourlyRate/hr',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.star, color: Colors.amber[600], size: 16),
                    const SizedBox(width: 2),
                    Text(
                      rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Date',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _selectedMonth,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _dates.length,
              itemBuilder: (context, index) {
                final isSelected = index == _selectedDateIndex;
                final date = _dates[index];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDateIndex = index;
                    });
                  },
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF2196F3) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF2196F3) : Colors.grey[300]!,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          date['day']!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          date['date']!,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Time',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(_times.length, (index) {
              final isSelected = index == _selectedTimeIndex;
              final isUnavailable = _unavailableTimeSlots.contains(index);

              return GestureDetector(
                onTap: isUnavailable
                    ? null
                    : () {
                        setState(() {
                          _selectedTimeIndex = index;
                        });
                      },
                child: Container(
                  width: (MediaQuery.of(context).size.width - 56) / 3,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF2196F3)
                        : isUnavailable
                            ? Colors.grey[100]
                            : Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF2196F3)
                          : isUnavailable
                              ? Colors.grey[300]!
                              : Colors.grey[300]!,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _times[index],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : isUnavailable
                                ? Colors.grey[400]
                                : Colors.black87,
                        decoration: isUnavailable
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingSummary(int hourlyRate, double bookingFee, double totalEstimate) {
    // Create a service title based on detected category
    String serviceTitle = 'Service Request';
    if (widget.detectedCategory.isNotEmpty) {
      serviceTitle = _formatCategoryTitle(widget.detectedCategory);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Booking Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Service Info
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.build_outlined,
                  color: Color(0xFF2196F3),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Based on your "${widget.searchQuery}" query',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // Details
          _buildSummaryRow('Date & Time', '$_formattedSelectedDate • ${_times[_selectedTimeIndex]}'),
          const SizedBox(height: 8),
          _buildSummaryRow('Duration Estimate', '~1 Hour'),
          const SizedBox(height: 8),
          _buildSummaryRow('Hourly Rate', '\$${hourlyRate.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _buildSummaryRow('Booking Fee', '\$${bookingFee.toStringAsFixed(2)}'),

          const SizedBox(height: 12),
          Container(
            height: 1,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: CustomPaint(
              painter: DashedLinePainter(),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Estimate',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '\$${totalEstimate.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2196F3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCategoryTitle(String category) {
    // Convert category like "plumber" to "Emergency Leak Repair" style
    final categoryTitles = {
      'plumber': 'Emergency Leak Repair',
      'electrician': 'Electrical Service',
      'carpenter': 'Carpentry Work',
      'painter': 'Painting Service',
      'cleaner': 'Cleaning Service',
      'hvac': 'HVAC Service',
      'ac_technician': 'AC Repair Service',
      'appliance_repair': 'Appliance Repair',
      'pest_control': 'Pest Control Service',
      'gardener': 'Gardening Service',
      'locksmith': 'Locksmith Service',
      'roofer': 'Roofing Service',
      'mason': 'Masonry Work',
      'welder': 'Welding Service',
      'glass_fitter': 'Glass Fitting Service',
      'waterproofing': 'Waterproofing Service',
      'interior_designer': 'Interior Design',
      'general_contractor': 'General Service',
    };

    return categoryTitles[category.toLowerCase()] ??
           '${category[0].toUpperCase()}${category.substring(1)} Service';
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoNotice() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.blue[600],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You won\'t be charged until the job is completed. Cancellations are free up to 2 hours before the appointment.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(double totalEstimate) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Estimate',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '\$${totalEstimate.toStringAsFixed(2)} / visit',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: ElevatedButton(
                onPressed: _isBooking ? null : _confirmBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isBooking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'Confirm',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBooking() async {
    if (_isBooking) return;

    // Get worker ID - this is critical for the booking to appear in worker's dashboard
    final workerId = widget.worker['id']?.toString() ?? '';

    // Debug: Print worker data to verify ID is present
    print('DEBUG: Booking worker with data: ${widget.worker}');
    print('DEBUG: Worker ID being used: $workerId');

    if (workerId.isEmpty) {
      _showErrorSnackbar('Error: Worker ID is missing. Cannot create booking.');
      return;
    }

    setState(() {
      _isBooking = true;
    });

    final workerName = widget.worker['name'] ?? 'Worker';

    // Get selected date details
    final selectedDate = _dates[_selectedDateIndex];
    final now = DateTime.now();
    final bookingDate = now.add(Duration(days: _selectedDateIndex));

    // Prepare booking data
    final bookingData = {
      'workerId': workerId,
      'workerName': workerName,
      'workerCategory': widget.detectedCategory,
      'customerQuery': widget.searchQuery,
      'date': '${selectedDate['year']}-${selectedDate['month']}-${selectedDate['date']}',
      'time': _times[_selectedTimeIndex],
      'bookingDate': bookingDate.toIso8601String(),
      'hourlyRate': widget.worker['hourly_rate'] ?? widget.worker['rate'] ?? 0,
      'status': 'pending',
    };

    print('DEBUG: Creating booking with data: $bookingData');

    try {
      // Save booking to Firestore
      final bookingId = await _firestoreService.createBooking(bookingData);

      setState(() {
        _isBooking = false;
      });

      if (bookingId != null) {
        // Success - show confirmation dialog
        _showSuccessDialog(workerName);
      } else {
        // Failed to save
        _showErrorSnackbar('Failed to create booking. Please try again.');
      }
    } catch (e) {
      setState(() {
        _isBooking = false;
      });
      _showErrorSnackbar('Error: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessDialog(String workerName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                Icons.check,
                color: Colors.green[600],
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Booking Confirmed!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your appointment with $workerName has been scheduled for $_formattedSelectedDate at ${_times[_selectedTimeIndex]}.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to search results
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for dashed line
class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1;

    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
