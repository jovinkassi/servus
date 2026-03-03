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
import '../services/notification_service.dart';
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
  int _unreadCount = 0;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadCustomerInfo();
    _notificationService.addListener(_onNotification);
    setState(() {
      _unreadCount = _notificationService.unreadCount;
    });
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotification);
    super.dispose();
  }

  void _onNotification(AppNotification _) {
    setState(() {
      _unreadCount = _notificationService.unreadCount;
    });
  }

  void _showNotificationsModal() async {
    final notifications = await _notificationService.getNotifications();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (context) => Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 72, right: 12),
          child: Material(
            color: Colors.transparent,
            child: _NotificationsModal(
              notifications: notifications,
              onMarkAllRead: () async {
                await _notificationService.markAllAsRead();
                setState(() => _unreadCount = 0);
              },
            ),
          ),
        ),
      ),
    );
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
        if (response.statusCode == 503) {
          _showErrorDialog('Server is still starting up. Please try again in a minute.');
        } else {
          _showErrorDialog('Error: ${response.statusCode}');
        }
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });

      // Show user-friendly error
      _showErrorDialog(
        'Could not reach the server. It may be waking up — please try again in a moment.',
      );
    }
  }


  // ─── NEW: sends image (+ optional text) to your image model endpoint ───
Future<void> _classifyIssueWithImage(Uint8List imageBytes, String description) async {
  setState(() => _loading = true);

  try {
    final base64Image = base64Encode(imageBytes);
    final ext = _selectedImageName?.split('.').last.toLowerCase() ?? 'jpg';
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

    final response = await http.post(
      Uri.parse("${ApiConfig().baseUrl}/analyze-image"),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'image': base64Image,
        'mime_type': mimeType,
        'problem': description, // optional text, can be empty string
      }),
    );

    print("Sending image to backend, size: ${imageBytes.length} bytes");
    print("Response: ${response.body}");

    setState(() => _loading = false);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchResultsPage(
            searchQuery: description.isNotEmpty ? description : 'Image upload',
            detectedCategory: data['detected_category'] ?? 'General',
            quickFix: data['quick_fix'] ?? '',
            workers: data['available_workers'] ?? [],
          ),
        ),
      );
    } else {
      if (response.statusCode == 503) {
        _showErrorDialog('Server is still starting up. Please try again in a minute.');
      } else {
        _showErrorDialog('Error: ${response.statusCode}');
      }
    }
  } catch (e) {
    setState(() => _loading = false);
    _showErrorDialog(
      'Could not reach the server. It may be waking up — please try again in a moment.',
    );
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

// ─── MODIFIED: routes to image or text path ───
void _handleFindHelp() {
  final hasText = _issueController.text.trim().isNotEmpty;
  final hasImage = _selectedImageBytes != null;

  if (!hasText && !hasImage) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please describe your issue or upload an image'),
        duration: Duration(seconds: 2),
      ),
    );
    return;
  }

  if (hasImage) {
    // Image takes priority — text is sent along as optional context
    _classifyIssueWithImage(_selectedImageBytes!, _issueController.text.trim());
  } else {
    _classifyIssue(_issueController.text.trim());
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
                  GestureDetector(
                    onTap: _showNotificationsModal,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(51),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          const Icon(Icons.notifications, size: 24, color: Colors.white),
                          if (_unreadCount > 0)
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
                                child: Text(
                                  _unreadCount > 9 ? '9+' : '$_unreadCount',
                                  style: const TextStyle(
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

class _NotificationsModal extends StatefulWidget {
  final List<AppNotification> notifications;
  final VoidCallback onMarkAllRead;

  const _NotificationsModal({
    required this.notifications,
    required this.onMarkAllRead,
  });

  @override
  State<_NotificationsModal> createState() => _NotificationsModalState();
}

class _NotificationsModalState extends State<_NotificationsModal> {
  late List<AppNotification> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = widget.notifications;
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'new_booking': return Icons.work_outline;
      case 'job_status_update': return Icons.update;
      case 'payment': return Icons.payment;
      default: return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'new_booking': return const Color(0xFF1E3A5F);
      case 'job_status_update': return Colors.green;
      case 'payment': return Colors.orange;
      default: return Colors.blueGrey;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                if (_notifications.any((n) => !n.read))
                  TextButton(
                    onPressed: () {
                      widget.onMarkAllRead();
                      setState(() {
                        _notifications = _notifications
                            .map((n) => AppNotification(
                                  id: n.id,
                                  title: n.title,
                                  body: n.body,
                                  type: n.type,
                                  jobId: n.jobId,
                                  createdAt: n.createdAt,
                                  read: true,
                                ))
                            .toList();
                      });
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                    ),
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(color: Color(0xFF1E3A5F), fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: _notifications.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_none, size: 40, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No notifications yet',
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 56),
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      return ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: _colorForType(n.type).withAlpha(26),
                          child: Icon(_iconForType(n.type),
                              color: _colorForType(n.type), size: 18),
                        ),
                        title: Text(
                          n.title,
                          style: TextStyle(
                            fontWeight:
                                n.read ? FontWeight.normal : FontWeight.bold,
                            fontSize: 13,
                            color: const Color(0xFF1E3A5F),
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                            Text(_timeAgo(n.createdAt),
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        trailing: n.read
                            ? null
                            : Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1E3A5F),
                                  shape: BoxShape.circle,
                                ),
                              ),
                        isThreeLine: true,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
