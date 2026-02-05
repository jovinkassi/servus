// lib/worker/screens/worker_registration.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'worker_dashboard.dart';
import '../../services/notification_service.dart';
import '../../widgets/location_picker.dart';

class WorkerRegistrationScreen extends StatefulWidget {
  const WorkerRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<WorkerRegistrationScreen> createState() =>
      _WorkerRegistrationScreenState();
}

class _WorkerRegistrationScreenState extends State<WorkerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  int _currentStep = 0;

  // Form controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _experienceController = TextEditingController();
  final _hourlyRateController = TextEditingController();

  // Location coordinates
  double? _latitude;
  double? _longitude;

  String _selectedCategory = 'plumber';

  final List<Map<String, dynamic>> _categories = [
    {'value': 'plumber', 'label': 'Plumber', 'icon': Icons.plumbing},
    {'value': 'electrician', 'label': 'Electrician', 'icon': Icons.electrical_services},
    {'value': 'ac_technician', 'label': 'AC Technician', 'icon': Icons.ac_unit},
    {'value': 'carpenter', 'label': 'Carpenter', 'icon': Icons.carpenter},
    {'value': 'appliance_repair', 'label': 'Appliance Repair', 'icon': Icons.kitchen},
    {'value': 'cleaning', 'label': 'Cleaning', 'icon': Icons.cleaning_services},
    {'value': 'computer_repair', 'label': 'Computer Repair', 'icon': Icons.computer},
    {'value': 'mobile_repair', 'label': 'Mobile Repair', 'icon': Icons.phone_android},
    {'value': 'pest_control', 'label': 'Pest Control', 'icon': Icons.bug_report},
    {'value': 'locksmith', 'label': 'Locksmith', 'icon': Icons.lock},
    {'value': 'painter', 'label': 'Painter', 'icon': Icons.format_paint},
    {'value': 'general_contractor', 'label': 'General Contractor', 'icon': Icons.construction},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _experienceController.dispose();
    _hourlyRateController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFE53935) : const Color(0xFF43A047),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _registerWorker() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/worker/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'location': _locationController.text.trim(),
          'latitude': _latitude,
          'longitude': _longitude,
          'category': _selectedCategory,
          'experience': _experienceController.text.trim(),
          'hourly_rate': double.tryParse(_hourlyRateController.text) ?? 0,
        }),
      );

      final data = json.decode(response.body);

      if (data['success'] == true) {
        // Register for push notifications
        final workerId = data['worker_id'];
        await NotificationService().registerForNotifications(
          userId: workerId,
          userType: 'worker',
        );

        if (mounted) {
          _showSnackBar('Registration successful! Welcome aboard.');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WorkerDashboard(workerId: workerId),
            ),
          );
        }
      } else {
        if (mounted) {
          _showSnackBar(data['error'] ?? 'Registration failed', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Connection error. Please try again.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3A5F),
              Color(0xFF2D5478),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Join as Provider',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Progress Indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    _buildProgressDot(0),
                    _buildProgressLine(0),
                    _buildProgressDot(1),
                    _buildProgressLine(1),
                    _buildProgressDot(2),
                  ],
                ),
              ),

              // Form Content
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Step Title
                          Text(
                            _getStepTitle(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A5F),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getStepSubtitle(),
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Step Content
                          if (_currentStep == 0) _buildPersonalInfoStep(),
                          if (_currentStep == 1) _buildProfessionalInfoStep(),
                          if (_currentStep == 2) _buildPricingStep(),

                          const SizedBox(height: 32),

                          // Navigation Buttons
                          Row(
                            children: [
                              if (_currentStep > 0)
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setState(() => _currentStep--);
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF1E3A5F),
                                      side: const BorderSide(color: Color(0xFF1E3A5F)),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'Back',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              if (_currentStep > 0) const SizedBox(width: 16),
                              Expanded(
                                flex: _currentStep > 0 ? 1 : 2,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleNext,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E3A5F),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              _currentStep == 2 ? 'Complete Registration' : 'Continue',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              _currentStep == 2 ? Icons.check : Icons.arrow_forward,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDot(int step) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white24,
        borderRadius: BorderRadius.circular(18),
        border: isCurrent
            ? Border.all(color: Colors.white, width: 3)
            : null,
      ),
      child: Center(
        child: isActive && !isCurrent
            ? const Icon(Icons.check, color: Color(0xFF1E3A5F), size: 20)
            : Text(
                '${step + 1}',
                style: TextStyle(
                  color: isActive ? const Color(0xFF1E3A5F) : Colors.white54,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildProgressLine(int step) {
    final isActive = _currentStep > step;
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Personal Information';
      case 1:
        return 'Professional Details';
      case 2:
        return 'Set Your Pricing';
      default:
        return '';
    }
  }

  String _getStepSubtitle() {
    switch (_currentStep) {
      case 0:
        return 'Let\'s start with your basic details';
      case 1:
        return 'Tell us about your expertise';
      case 2:
        return 'Set your hourly rate';
      default:
        return '';
    }
  }

  Widget _buildPersonalInfoStep() {
    return Column(
      children: [
        _buildTextField(
          controller: _nameController,
          label: 'Full Name',
          hint: 'Enter your full name',
          icon: Icons.person_outline,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your name';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _phoneController,
          label: 'Phone Number',
          hint: 'Enter your phone number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your phone number';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        LocationPicker(
          initialAddress: _locationController.text.isNotEmpty ? _locationController.text : null,
          onLocationSelected: (address, lat, lng) {
            setState(() {
              _locationController.text = address;
              _latitude = lat;
              _longitude = lng;
            });
          },
        ),
      ],
    );
  }

  Widget _buildProfessionalInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Your Service Category',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E3A5F),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            final isSelected = _selectedCategory == category['value'];
            return GestureDetector(
              onTap: () {
                setState(() => _selectedCategory = category['value']);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1E3A5F) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF1E3A5F) : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1E3A5F).withAlpha(51),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      category['icon'],
                      size: 28,
                      color: isSelected ? Colors.white : const Color(0xFF1E3A5F),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      category['label'],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF1E3A5F),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _experienceController,
          label: 'Years of Experience',
          hint: 'e.g., 5 years',
          icon: Icons.work_history_outlined,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your experience';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPricingStep() {
    return Column(
      children: [
        // Pricing Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withAlpha(26),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.currency_rupee,
                  size: 36,
                  color: Color(0xFF1E3A5F),
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _hourlyRateController,
                label: 'Hourly Rate (₹)',
                hint: 'e.g., 500',
                icon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your hourly rate';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Tips
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF81C784)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lightbulb_outline, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pricing Tip',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Research local rates to stay competitive. You can update this anytime.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF558B2F),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Terms
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_user_outlined, color: Color(0xFF1E3A5F)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'By registering, you agree to our Terms of Service and Privacy Policy.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E3A5F),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontWeight: FontWeight.normal,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF1E3A5F), size: 20),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  void _handleNext() {
    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty ||
          _phoneController.text.trim().isEmpty) {
        _showSnackBar('Please fill in all fields', isError: true);
        return;
      }
      if (_locationController.text.trim().isEmpty || _latitude == null || _longitude == null) {
        _showSnackBar('Please select your location', isError: true);
        return;
      }
      setState(() => _currentStep++);
    } else if (_currentStep == 1) {
      if (_experienceController.text.trim().isEmpty) {
        _showSnackBar('Please enter your experience', isError: true);
        return;
      }
      setState(() => _currentStep++);
    } else {
      _registerWorker();
    }
  }
}
