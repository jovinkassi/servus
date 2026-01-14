// pages/home_page.dart
import 'package:flutter/material.dart';
import '../../models/service_category.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _issueController = TextEditingController();
  bool _showResults = false;
  String _suggestedCategory = '';
  bool _loading = false;

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

  Future<void> _classifyIssue(String description) async {
    setState(() {
      _loading = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    final keywords = {
      'Plumber': ['leak', 'pipe', 'tap', 'faucet', 'drain', 'water', 'sink', 'toilet', 'bathroom'],
      'Electric': ['light', 'socket', 'power', 'electrical', 'wire', 'switch', 'circuit', 'breaker'],
      'Wood': ['door', 'cabinet', 'furniture', 'wood', 'carpenter', 'shelf'],
      'Clean': ['clean', 'dirt', 'mess', 'stain', 'polish'],
      'HVAC': ['ac', 'heating', 'cooling', 'temperature', 'hvac', 'air conditioning'],
      'Paint': ['paint', 'wall', 'color', 'repaint'],
      'Water': ['water heater', 'geyser', 'hot water', 'boiler']
    };

    String category = 'General';
    final lowerDesc = description.toLowerCase();

    for (var entry in keywords.entries) {
      if (entry.value.any((word) => lowerDesc.contains(word))) {
        category = entry.key;
        break;
      }
    }

    setState(() {
      _suggestedCategory = category;
      _showResults = true;
      _loading = false;
    });
  }

  void _handleFindHelp() {
    if (_issueController.text.trim().isNotEmpty) {
      _classifyIssue(_issueController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
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
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
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
                          gradient: const LinearGradient(
                            colors: [Color(0xFF64B5F6), Color(0xFF2196F3)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 28),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.green,
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
                      const Text(
                        'LOCATION',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          letterSpacing: 1,
                        ),
                      ),
                      Row(
                        children: const [
                          Text(
                            'San Francisco, CA',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.location_on, color: Color(0xFF2196F3), size: 18),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              Stack(
                children: [
                  const Icon(Icons.notifications, size: 28),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: const Text(
                        '3',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
              children: [
                TextSpan(text: 'Good evening, '),
                TextSpan(text: 'Alex', style: TextStyle(color: Color(0xFF2196F3))),
                TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Describe your issue, and our AI will find the best pro nearby.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
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
            child: TextField(
              controller: _issueController,
              decoration: InputDecoration(
                hintText: 'e.g., The kitchen light won\'t turn on...',
                hintStyle: const TextStyle(color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                suffixIcon: const Icon(Icons.mic, color: Colors.grey),
              ),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    _loading ? 'Analyzing...' : 'Find Help',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showResults) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF81C784)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✓ AI Detected: $_suggestedCategory service needed',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Showing verified ${_suggestedCategory.toLowerCase()} professionals nearby',
                    style: const TextStyle(
                      color: Color(0xFF388E3C),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check, color: Color(0xFF4CAF50), size: 14),
              ),
              const SizedBox(width: 8),
              const Text(
                'Verified Pros Only • AI Matched • Insured',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
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
                onPressed: () {},
                child: const Text('View Map'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.location_on, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'San Francisco',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Center(
                                child: Text('P', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ),
                            Positioned(
                              left: 20,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Center(
                                  child: Text('E', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 40,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Center(
                                  child: Text('+12', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 52),
                        const Text(
                          'Pros online nearby',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Live',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
                onTap: () {},
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: category.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          category.icon,
                          color: category.color,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Home', true),
              _buildNavItem(Icons.work_outline, 'My Jobs', false),
              _buildNavItem(Icons.chat_bubble_outline, 'Messages', false),
              _buildNavItem(Icons.person_outline, 'Profile', false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: isActive ? const Color(0xFF2196F3) : Colors.grey,
          size: 28,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? const Color(0xFF2196F3) : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}