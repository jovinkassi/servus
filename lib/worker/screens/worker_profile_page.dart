import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../../main.dart';
import '../../widgets/location_picker.dart';
import '../services/worker_service.dart';
import '../../services/api_config.dart';
import 'worker_dashboard.dart';
import 'worker_jobs.dart';
import 'worker_chat_list_page.dart';

class WorkerProfilePage extends StatefulWidget {
  final String workerId;

  const WorkerProfilePage({super.key, required this.workerId});

  @override
  State<WorkerProfilePage> createState() => _WorkerProfilePageState();
}

class _WorkerProfilePageState extends State<WorkerProfilePage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _isLoading = true;
  Map<String, dynamic> _workerData = {};
  Uint8List? _profileImageBytes;

  // Stats
  int _totalJobs = 0;
  int _completedJobs = 0;
  double _rating = 0.0;
  double _totalEarnings = 0.0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      // Load worker document from Firestore
      final doc = await _db.collection('workers').doc(widget.workerId).get();
      if (doc.exists) {
        _workerData = doc.data()!;
        _workerData['id'] = doc.id;

        // Load profile image from Firestore
        final savedImage = _workerData['profileImageBase64'];
        if (savedImage != null && savedImage is String && savedImage.isNotEmpty) {
          _profileImageBytes = base64Decode(savedImage);
        }
      }

      // Load job stats from bookings
      final bookingsSnapshot = await _db
          .collection('bookings')
          .where('workerId', isEqualTo: widget.workerId)
          .get();

      _totalJobs = bookingsSnapshot.docs.length;
      _completedJobs = bookingsSnapshot.docs
          .where((doc) => doc.data()['status'] == 'completed')
          .length;

      // Get rating and earnings from worker service
      final workerService = WorkerService();
      workerService.setWorkerId(widget.workerId);
      final profile = await workerService.getWorkerProfile();
      final stats = profile['stats'] ?? {};
      _rating = (stats['rating'] ?? 0.0).toDouble();
      _totalEarnings = (stats['total_earnings'] ?? 0.0).toDouble();
    } catch (e) {
      print('Error loading worker profile: $e');
    }

    setState(() => _isLoading = false);
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
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1E3A5F)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      bottomNavigationBar: _buildBottomNav(),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildStatsSection(),
                  _buildMenuSection(),
                  const SizedBox(height: 20),
                  _buildLogoutButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final name = _workerData['name'] ?? 'Worker';
    final phone = _workerData['phone'] ?? '';
    final location = _workerData['location'] ?? '';
    final category = _formatCategory(_workerData['category']);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A5F), Color(0xFF2D5478)],
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
            children: [
              // Top row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(51),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    ),
                  ),
                  const Text(
                    'Profile',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  GestureDetector(
                    onTap: _editProfile,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(51),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(51),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _profileImageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(46),
                            child: Image.memory(
                              _profileImageBytes!,
                              width: 92,
                              height: 92,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.person, size: 60, color: Color(0xFF1E3A5F)),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _changePhoto,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A5F),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Name
              Text(
                name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              // Category badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  category,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              if (_workerData['verified'] == true) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _showVerificationDetails,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(51),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.greenAccent, width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, color: Colors.greenAccent, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Blockchain Verified',
                          style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              // Phone
              Text(
                phone,
                style: TextStyle(fontSize: 14, color: Colors.white.withAlpha(204)),
              ),
              if (location.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(location, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                icon: Icons.work_outline,
                value: '$_totalJobs',
                label: 'Total Jobs',
                color: const Color(0xFF1E3A5F),
              ),
            ),
            Container(width: 1, height: 50, color: Colors.grey.withAlpha(51)),
            Expanded(
              child: _buildStatItem(
                icon: Icons.check_circle,
                value: '$_completedJobs',
                label: 'Completed',
                color: Colors.green,
              ),
            ),
            Container(width: 1, height: 50, color: Colors.grey.withAlpha(51)),
            Expanded(
              child: _buildStatItem(
                icon: Icons.star,
                value: _rating > 0 ? _rating.toStringAsFixed(1) : '-',
                label: 'Rating',
                color: Colors.amber,
              ),
            ),
            Container(width: 1, height: 50, color: Colors.grey.withAlpha(51)),
            Expanded(
              child: _buildStatItem(
                icon: Icons.account_balance_wallet,
                value: '₹${_totalEarnings.toStringAsFixed(0)}',
                label: 'Earnings',
                color: const Color(0xFF9C27B0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMenuSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildVerificationMenuItem(),
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.person_outline,
              title: 'Personal Information',
              subtitle: 'Update your details',
              onTap: _editProfile,
            ),
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.work_outline,
              title: 'Work Details',
              subtitle: 'Category, experience, rate',
              onTap: () => _showComingSoon('Work Details'),
            ),
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.payment_outlined,
              title: 'Payment & Earnings',
              subtitle: 'View transaction history',
              onTap: () => _showComingSoon('Payment & Earnings'),
            ),
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Configure alerts',
              onTap: () => _showComingSoon('Notifications'),
            ),
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'FAQs, contact us',
              onTap: () => _showComingSoon('Help & Support'),
            ),
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.info_outline,
              title: 'About',
              subtitle: 'Version 1.0.0',
              onTap: _showAbout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF1E3A5F), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: Colors.grey.withAlpha(51)),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text(
            'Log Out',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Colors.red),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
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
              _buildNavItem(Icons.dashboard_rounded, 'Home', false, () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkerDashboard(workerId: widget.workerId),
                  ),
                );
              }),
              _buildNavItem(Icons.work_outline_rounded, 'Jobs', false, () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkerJobsScreen(workerId: widget.workerId),
                  ),
                );
              }),
              _buildNavItem(Icons.chat_bubble_outline_rounded, 'Messages', false, () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkerChatListPage(workerId: widget.workerId),
                  ),
                );
              }),
              _buildNavItem(Icons.person_outline_rounded, 'Profile', true, () {}),
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
          color: isActive ? const Color(0xFF1E3A5F).withAlpha(26) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF1E3A5F) : Colors.grey,
              size: 24,
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF1E3A5F),
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

  Widget _buildVerificationMenuItem() {
    final isVerified = _workerData['verified'] == true;

    return InkWell(
      onTap: isVerified ? _showVerificationDetails : _showVerificationSheet,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isVerified
                    ? Colors.green.withAlpha(26)
                    : Colors.orange.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isVerified ? Icons.verified : Icons.shield_outlined,
                color: isVerified ? Colors.green : Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isVerified ? 'ID Verified' : 'Verify Your Identity',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isVerified
                        ? 'Blockchain verified - Tap for details'
                        : 'Verify with Aadhaar for trust badge',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(
              isVerified ? Icons.check_circle : Icons.arrow_forward_ios,
              color: isVerified ? Colors.green : Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showVerificationSheet() {
    final aadhaarController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A5F).withAlpha(26),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.shield, color: Color(0xFF1E3A5F), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Blockchain ID Verification',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Powered by Polygon Blockchain',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withAlpha(50)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your Aadhaar number is never stored. Only a SHA-256 hash is recorded on the blockchain for tamper-proof verification.',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: aadhaarController,
                    keyboardType: TextInputType.number,
                    maxLength: 12,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Aadhaar Number',
                      hintText: 'Enter 12-digit Aadhaar number',
                      prefixIcon: const Icon(Icons.credit_card, color: Color(0xFF1E3A5F)),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final aadhaar = aadhaarController.text.trim();
                              if (aadhaar.length != 12) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter a valid 12-digit Aadhaar number'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              setSheetState(() => isSubmitting = true);
                              await _submitVerification(aadhaar);
                              if (context.mounted) Navigator.pop(context);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A5F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Verify on Blockchain',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitVerification(String aadhaar) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig().baseUrl}/worker/${widget.workerId}/verify-aadhaar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'aadhaar_number': aadhaar}),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (data['success'] == true) {
        // Reload profile to get updated data
        await _loadProfile();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Identity verified on blockchain!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Verification failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showVerificationDetails() {
    final txHash = _workerData['blockchainTxHash'] ?? '';
    final network = _workerData['blockchainNetwork'] ?? 'Polygon Amoy Testnet';
    final verifiedAt = _workerData['verifiedAt'] ?? '';
    final explorerUrl = 'https://amoy.polygonscan.com/tx/0x$txHash';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.verified, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Verification Details'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 40),
                  SizedBox(height: 8),
                  Text(
                    'Identity Verified',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Network', network),
            const SizedBox(height: 8),
            _buildDetailRow('Verified At', verifiedAt),
            const SizedBox(height: 8),
            const Text('Transaction Hash', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: txHash));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaction hash copied!')),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  txHash.isNotEmpty
                      ? '${txHash.substring(0, 10)}...${txHash.substring(txHash.length - 10)}'
                      : 'N/A',
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: explorerUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Explorer link copied!')),
                  );
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Copy Polygonscan Link'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E3A5F),
                  side: const BorderSide(color: Color(0xFF1E3A5F)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  void _editProfile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEditProfileSheet(),
    );
  }

  Widget _buildEditProfileSheet() {
    final nameController = TextEditingController(text: _workerData['name'] ?? '');
    final phoneController = TextEditingController(text: _workerData['phone'] ?? '');
    final locationController = TextEditingController(text: _workerData['location'] ?? '');
    double? selectedLat = _workerData['latitude']?.toDouble();
    double? selectedLng = _workerData['longitude']?.toDouble();
    bool isSaving = false;

    return StatefulBuilder(
      builder: (context, setSheetState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Profile',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: nameController,
                        label: 'Full Name',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: phoneController,
                        label: 'Phone',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      LocationPicker(
                        initialAddress: locationController.text.isNotEmpty
                            ? locationController.text
                            : null,
                        onLocationSelected: (address, lat, lng) {
                          setSheetState(() {
                            locationController.text = address;
                            selectedLat = lat;
                            selectedLng = lng;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setSheetState(() => isSaving = true);

                                  final newName = nameController.text.trim();
                                  final newPhone = phoneController.text.trim();
                                  final newLocation = locationController.text.trim();

                                  if (newName.isEmpty || newPhone.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Name and phone are required'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    setSheetState(() => isSaving = false);
                                    return;
                                  }

                                  try {
                                    final updateData = <String, dynamic>{
                                      'name': newName,
                                      'phone': newPhone,
                                    };
                                    if (newLocation.isNotEmpty) {
                                      updateData['location'] = newLocation;
                                      if (selectedLat != null && selectedLng != null) {
                                        updateData['latitude'] = selectedLat;
                                        updateData['longitude'] = selectedLng;
                                      }
                                    }
                                    await _db
                                        .collection('workers')
                                        .doc(widget.workerId)
                                        .update(updateData);

                                    setState(() {
                                      _workerData['name'] = newName;
                                      _workerData['phone'] = newPhone;
                                      _workerData['location'] = newLocation;
                                    });

                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Profile updated successfully'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    setSheetState(() => isSaving = false);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error updating profile: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A5F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F)),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
        ),
      ),
    );
  }

  Future<void> _changePhoto() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Change Photo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library, color: Color(0xFF1E3A5F)),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickProfileImage();
              },
            ),
            if (_profileImageBytes != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete, color: Colors.red),
                ),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final messenger = ScaffoldMessenger.of(context);
                  await _db.collection('workers').doc(widget.workerId).update({
                    'profileImageBase64': FieldValue.delete(),
                  });
                  setState(() {
                    _profileImageBytes = null;
                  });
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Photo removed'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
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

        if (file.bytes != null) {
          // Compress and save to Firestore
          final compressed = await _compressImage(file.bytes!, 200);
          final base64Image = base64Encode(compressed);
          await _db.collection('workers').doc(widget.workerId).update({
            'profileImageBase64': base64Image,
          });

          setState(() {
            _profileImageBytes = compressed;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile photo updated'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e'), duration: const Duration(seconds: 2)),
      );
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Coming soon!'),
        backgroundColor: const Color(0xFF1E3A5F),
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A5F), Color(0xFF2D5478)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.handyman, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Servus'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your AI-powered service marketplace', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            _buildAboutRow('Version', '1.0.0'),
            _buildAboutRow('Build', '2026.02'),
            const SizedBox(height: 16),
            Text(
              'Connect with customers and grow your business.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}
