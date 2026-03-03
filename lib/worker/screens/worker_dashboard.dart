// lib/worker/screens/worker_dashboard.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import '../services/worker_service.dart';
import '../widgets/notification_overlay.dart';
import '../../services/notification_service.dart';
import 'worker_jobs.dart';
import 'worker_chat_list_page.dart';
import 'worker_schedule_screen.dart';
import 'worker_profile_page.dart';
import 'worker_earnings_page.dart';

class WorkerDashboard extends StatefulWidget {
  final String? workerId;

  const WorkerDashboard({super.key, this.workerId});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  final WorkerService _workerService = WorkerService();
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _workerProfile = {};
  bool _isLoading = true;
  int _selectedNavIndex = 0;
  Uint8List? _profileImageBytes;
  List<Map<String, dynamic>> _recentBookings = [];
  int _unreadCount = 0;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    if (widget.workerId != null) {
      _workerService.setWorkerId(widget.workerId!);
    }
    _loadProfile();
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
            child: _WorkerNotificationsModal(
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

  Future<void> _loadProfile() async {
    final profile = await _workerService.getWorkerProfile();

    // Load profile image from Firestore
    Uint8List? profileImage;
    if (widget.workerId != null) {
      final doc = await FirebaseFirestore.instance
          .collection('workers')
          .doc(widget.workerId)
          .get();
      if (doc.exists) {
        final savedImage = doc.data()?['profileImageBase64'];
        if (savedImage != null && savedImage is String && savedImage.isNotEmpty) {
          profileImage = base64Decode(savedImage);
        }
      }
    }

    // Load recent bookings from Firestore
    List<Map<String, dynamic>> recentBookings = [];
    if (widget.workerId != null) {
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('workerId', isEqualTo: widget.workerId)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      for (final doc in bookingsSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        recentBookings.add(data);
      }
    }

    setState(() {
      _workerProfile = profile['worker'] ?? {};
      _stats = profile['stats'] ?? {};
      _profileImageBytes = profileImage;
      _recentBookings = recentBookings;
      _isLoading = false;
    });
  }

  Future<Uint8List> _compressImage(Uint8List bytes, int maxSize) async {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: maxSize, targetHeight: maxSize);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _pickProfileImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select a profile photo',
        type: FileType.any,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final extension = file.name.split('.').last.toLowerCase();
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

        if (file.bytes != null && widget.workerId != null) {
          final compressed = await _compressImage(file.bytes!, 200);
          final base64Image = base64Encode(compressed);
          await FirebaseFirestore.instance
              .collection('workers')
              .doc(widget.workerId)
              .update({'profileImageBase64': base64Image});

          setState(() {
            _profileImageBytes = compressed;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  String _formatCategory(dynamic category) {
    if (category == null) return 'Professional';
    String cat = category.toString();
    return cat.split('_').map((word) {
      if (word.isEmpty) return '';
      if (word.toLowerCase() == 'ac') return 'AC';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return NotificationOverlay(
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF1E3A5F)),
              )
            : RefreshIndicator(
                onRefresh: _loadProfile,
                color: const Color(0xFF1E3A5F),
                child: CustomScrollView(
                  slivers: [
                    // Custom App Bar
                    SliverToBoxAdapter(
                      child: _buildHeader(),
                    ),

                    // Stats Cards
                    SliverToBoxAdapter(
                      child: _buildStatsSection(),
                    ),

                    // Quick Actions
                    SliverToBoxAdapter(
                      child: _buildQuickActions(),
                    ),

                    // Recent Activity
                    SliverToBoxAdapter(
                      child: _buildRecentActivity(),
                    ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: 100),
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildHeader() {
    final name = _workerProfile['name'] ?? 'Worker';
    final category = _formatCategory(_workerProfile['category']);
    final rating = _stats['rating'] ?? 0.0;
    final earnings = _stats['total_earnings'] ?? 0.0;
    final location = _workerProfile['location'] ?? '';

    return Container(
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
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Top Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good ${_getGreeting()}',
                          style: TextStyle(
                            color: Colors.white.withAlpha(179),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (location.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on, color: Colors.white.withAlpha(179), size: 14),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  location,
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(179),
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _showNotificationsModal,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(26),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                                size: 24,
                              ),
                              if (_unreadCount > 0)
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    constraints: const BoxConstraints(
                                        minWidth: 16, minHeight: 16),
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
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _pickProfileImage,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: _profileImageBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.memory(
                                    _profileImageBytes!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'W',
                                    style: const TextStyle(
                                      color: Color(0xFF1E3A5F),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Info Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(26),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withAlpha(51),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Color(0xFFFFD700),
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                ' rating',
                                style: TextStyle(
                                  color: Colors.white.withAlpha(179),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 50,
                      width: 1,
                      color: Colors.white.withAlpha(51),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'Total Earnings',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₹${earnings.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A5F),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Active Jobs',
                  '${_stats['active_jobs'] ?? 0}',
                  Icons.work_outline,
                  const Color(0xFF2196F3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Pending',
                  '${_stats['pending_jobs'] ?? 0}',
                  Icons.schedule,
                  const Color(0xFFFF9800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Completed',
                  '${_stats['completed_jobs'] ?? 0}',
                  Icons.check_circle_outline,
                  const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total Jobs',
                  '${_stats['total_jobs'] ?? 0}',
                  Icons.assessment_outlined,
                  const Color(0xFF9C27B0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withAlpha(200),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(60),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withAlpha(200),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A5F),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  'View Jobs',
                  'See available jobs',
                  Icons.list_alt_rounded,
                  const Color(0xFF1E3A5F),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkerJobsScreen(
                          workerId: _workerService.currentWorkerId,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  'Schedule',
                  'Manage availability',
                  Icons.calendar_today_rounded,
                  const Color(0xFF4CAF50),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkerScheduleScreen(
                          workerId: _workerService.currentWorkerId,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  'Messages',
                  'Chat with customers',
                  Icons.chat_bubble_outline_rounded,
                  const Color(0xFFFF9800),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkerChatListPage(workerId: _workerService.currentWorkerId),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  'Earnings',
                  'View transactions',
                  Icons.account_balance_wallet_outlined,
                  const Color(0xFF9C27B0),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkerEarningsPage(workerId: widget.workerId),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(color: color, width: 3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color.withAlpha(220),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else {
      return '';
    }
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed': return Icons.check_circle_outline;
      case 'confirmed': return Icons.thumb_up_outlined;
      case 'pending': return Icons.schedule;
      case 'cancelled': return Icons.cancel_outlined;
      default: return Icons.work_outline;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed': return const Color(0xFF4CAF50);
      case 'confirmed': return const Color(0xFF2196F3);
      case 'pending': return const Color(0xFFFF9800);
      case 'cancelled': return Colors.red;
      default: return const Color(0xFF9C27B0);
    }
  }

  Widget _buildRecentActivity() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _selectedNavIndex = 1);
                },
                child: const Text(
                  'See All',
                  style: TextStyle(color: Color(0xFF1E3A5F)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _recentBookings.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(
                            'No recent activity',
                            style: TextStyle(color: Colors.grey[400], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: List.generate(_recentBookings.length, (index) {
                      final booking = _recentBookings[index];
                      final status = booking['status'] ?? 'pending';
                      final customerName = booking['customerName'] ?? 'Customer';
                      final service = booking['searchQuery'] ?? booking['category'] ?? 'Service';
                      final time = _timeAgo(booking['createdAt']);
                      final statusLabel = status[0].toUpperCase() + status.substring(1);

                      return _buildActivityItem(
                        '$statusLabel - $customerName',
                        service,
                        time,
                        _getStatusIcon(status),
                        _getStatusColor(status),
                        isFirst: index == 0,
                        isLast: index == _recentBookings.length - 1,
                      );
                    }),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String subtitle,
    String time,
    IconData icon,
    Color color, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: !isLast
            ? Border(
                bottom: BorderSide(color: Colors.grey.shade100),
              )
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFF1E3A5F), width: 2),
        ),
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
              _buildNavItem(0, Icons.dashboard_rounded, 'Home'),
              _buildNavItem(1, Icons.work_outline_rounded, 'Jobs'),
              _buildNavItem(2, Icons.chat_bubble_outline_rounded, 'Messages'),
              _buildNavItem(3, Icons.person_outline_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = _selectedNavIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedNavIndex = index);
        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WorkerJobsScreen(
                workerId: _workerService.currentWorkerId,
              ),
            ),
          );
        } else if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WorkerChatListPage(workerId: _workerService.currentWorkerId),
            ),
          );
        } else if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WorkerProfilePage(workerId: _workerService.currentWorkerId),
            ),
          ).then((_) => _loadProfile());
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1E3A5F) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.grey[400],
              size: 24,
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
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

class _WorkerNotificationsModal extends StatefulWidget {
  final List<AppNotification> notifications;
  final VoidCallback onMarkAllRead;

  const _WorkerNotificationsModal({
    required this.notifications,
    required this.onMarkAllRead,
  });

  @override
  State<_WorkerNotificationsModal> createState() =>
      _WorkerNotificationsModalState();
}

class _WorkerNotificationsModalState extends State<_WorkerNotificationsModal> {
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              _colorForType(n.type).withAlpha(26),
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
