// pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/service_category.dart';
import '../services/firestore_service.dart';
import '../services/api_config.dart';
import '../worker/widgets/notification_overlay.dart';
import 'search/search_results_page.dart';
import 'booking/booking_history_page.dart';
import 'profile/profile_page.dart';
import 'search/nearby_workers_map_page.dart';
import 'chat/chat_list_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _issueController = TextEditingController();
  bool _loading = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String _customerName = 'User';
  String _customerLocation = 'Set your location';
  Uint8List? _profileImageBytes;

  @override
  void initState() {
    super.initState();
    _loadCustomerInfo();
  }

  Future<void> _loadCustomerInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('customer_name') ?? 'User';
    var location = 'Set your location';

    // Load location and profile image from Firestore
    final customerId = prefs.getString('customer_id');
    Uint8List? profileImage;
    if (customerId != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('customers')
            .doc(customerId)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          if (data['location'] != null && (data['location'] as String).isNotEmpty) {
            location = data['location'];
          }
          // Load profile image from Firestore
          final savedImage = data['profileImageBase64'];
          if (savedImage != null && savedImage is String && savedImage.isNotEmpty) {
            profileImage = base64Decode(savedImage);
          }
        }
      } catch (_) {}
    }

    setState(() {
      _customerName = name;
      _customerLocation = location;
      _profileImageBytes = profileImage;
    });
  }

  final List<ServiceCategory> _categories = [
    ServiceCategory('Plumber', Icons.build, const Color(0xFF2196F3)),
    ServiceCategory('Electric', Icons.bolt, const Color(0xFFFF9800)),
    ServiceCategory('Wood', Icons.carpenter, const Color(0xFFFF6B35)),
    ServiceCategory('Clean', Icons.cleaning_services, const Color(0xFF4DD0E1)),
    ServiceCategory('HVAC', Icons.ac_unit, const Color(0xFFEF5350)),
    ServiceCategory('Paint', Icons.format_paint, const Color(0xFFAB47BC)),
    ServiceCategory('Water', Icons.water_drop, const Color(0xFF42A5F5)),
    ServiceCategory('More', Icons.more_horiz, const Color(0xFF78909C)),
  ];

  // Map UI category names to Firestore category values
  static const Map<String, List<String>> _categoryMapping = {
    'Plumber': ['plumber'],
    'Electric': ['electrician'],
    'Wood': ['carpenter'],
    'Clean': ['cleaning'],
    'HVAC': ['ac_technician'],
    'Paint': ['painter'],
    'Water': ['plumber'],
  };

  Future<void> _onCategoryTap(String categoryName) async {
    if (categoryName == 'More') {
      // Fetch all workers
      setState(() => _loading = true);
      final workers = await FirestoreService().getAllWorkers();
      setState(() => _loading = false);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchResultsPage(
            searchQuery: 'All Services',
            detectedCategory: 'All',
            quickFix: '',
            workers: workers,
          ),
        ),
      );
      return;
    }

    final firestoreCategories = _categoryMapping[categoryName];
    if (firestoreCategories == null) return;

    setState(() => _loading = true);
    List<Map<String, dynamic>> allWorkers = [];
    for (final cat in firestoreCategories) {
      final workers = await FirestoreService().getWorkersByCategory(cat);
      allWorkers.addAll(workers);
    }
    setState(() => _loading = false);

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsPage(
          searchQuery: categoryName,
          detectedCategory: categoryName.toLowerCase(),
          quickFix: '',
          workers: allWorkers,
        ),
      ),
    );
  }

  // ---------------- BACKEND CALL ----------------
  Future<void> _classifyIssue(String description) async {
    setState(() {
      _loading = true;
    });

    try {
      // Send POST request to FastAPI backend
      final response = await http.post(
        Uri.parse("${ApiConfig().baseUrl}/analyze"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'problem': description}),
      );

      // Debug prints
      print("Sending to backend: $description");
      print("Response: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          _loading = false;
        });

        // Navigate to search results page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SearchResultsPage(
              searchQuery: description,
              detectedCategory: data['detected_category'] ?? 'General',
              quickFix: data['quick_fix'] ?? '',
              workers: data['available_workers'] ?? [],
            ),
          ),
        );
      } else {
        setState(() {
          _loading = false;
        });

        // Show error dialog
        _showErrorDialog('Error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });

      // Show error dialog
      _showErrorDialog('Error: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleFindHelp() {
    print("Button pressed with text: ${_issueController.text}");
    if (_issueController.text.trim().isNotEmpty || _selectedImageBytes != null) {
      _classifyIssue(_issueController.text);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe your issue or upload an image'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      // Use withData: true to get bytes (works on web and desktop)
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select an image',
        type: FileType.any,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final name = file.name;
        final extension = name.split('.').last.toLowerCase();

        // Check if it's an image file
        final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
        if (!imageExtensions.contains(extension)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select an image file (jpg, png, gif, etc.)'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        if (file.bytes != null) {
          setState(() {
            _selectedImageBytes = file.bytes;
            _selectedImageName = name;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
      if (_issueController.text == "Issue shown in the uploaded image") {
        _issueController.clear();
      }
    });
  }

  // ------------------- UI -------------------
  @override
  Widget build(BuildContext context) {
    return NotificationOverlay(
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchSection(),
                    _buildNearbyActivity(),
                    _buildQuickAccess(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF1E88E5), Color(0xFF42A5F5)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(51),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: _profileImageBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(22),
                                    child: Image.memory(
                                      _profileImageBytes!,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(Icons.person,
                                    color: Colors.white, size: 28),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.greenAccent,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LOCATION',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withAlpha(179),
                              letterSpacing: 1,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                _customerLocation,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.location_on,
                                  color: Colors.white, size: 18),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(51),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        const Icon(Icons.notifications, size: 24, color: Colors.white),
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: const Text(
                              '3',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  children: [
                    const TextSpan(text: 'Good evening, '),
                    TextSpan(
                        text: _customerName, style: const TextStyle(color: Color(0xFFFFD54F))),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Describe your issue, and our AI will find the best pro nearby.',
                style: TextStyle(fontSize: 14, color: Colors.white.withAlpha(204)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2196F3).withAlpha(77), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2196F3).withAlpha(26),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text field
                Expanded(
                  child: TextField(
                    controller: _issueController,
                    maxLines: 3,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _handleFindHelp(),
                    decoration: const InputDecoration(
                      hintText:
                          'e.g., The kitchen sink is leaking under the cabinet...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
                ),
                // Image upload button
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _selectedImageBytes != null
                            ? const Color(0xFF2196F3)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedImageBytes != null
                              ? const Color(0xFF2196F3)
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: _selectedImageBytes != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.memory(
                                    _selectedImageBytes!,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: GestureDetector(
                                    onTap: _removeImage,
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt_outlined,
                                  color: Colors.grey[600],
                                  size: 24,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Photo',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _handleFindHelp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.search, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Find Help',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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

  Widget _buildNearbyActivity() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nearby Activity',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NearbyWorkersMapPage(),
                    ),
                  );
                },
                child: const Text('View Map'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1E88E5).withAlpha(26),
                  const Color(0xFF42A5F5).withAlpha(51),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2196F3).withAlpha(51)),
            ),
            child: Stack(
              children: [
                // Decorative circles to simulate map markers
                Positioned(
                  top: 30,
                  left: 40,
                  child: _buildMapMarker(Colors.blue),
                ),
                Positioned(
                  top: 60,
                  right: 60,
                  child: _buildMapMarker(Colors.green),
                ),
                Positioned(
                  bottom: 40,
                  left: 80,
                  child: _buildMapMarker(Colors.orange),
                ),
                Positioned(
                  bottom: 50,
                  right: 100,
                  child: _buildMapMarker(Colors.red),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 40,
                        color: const Color(0xFF2196F3).withAlpha(128),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '4 pros nearby',
                        style: TextStyle(
                          color: const Color(0xFF1565C0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapMarker(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(128),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccess() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Access',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              return GestureDetector(
                onTap: () => _onCategoryTap(category.name),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: category.color.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          category.icon,
                          color: category.color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, 'Home', true, () {}),
              _buildNavItem(Icons.calendar_today_rounded, 'Bookings', false, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BookingHistoryPage(),
                  ),
                );
              }),
              _buildNavItem(Icons.chat_bubble_outline_rounded, 'Messages', false, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChatListPage(),
                  ),
                );
              }),
              _buildNavItem(Icons.person_outline_rounded, 'Profile', false, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfilePage(),
                  ),
                ).then((_) => _loadCustomerInfo());
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2196F3).withAlpha(26) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF2196F3) : Colors.grey,
              size: 24,
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF2196F3),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
