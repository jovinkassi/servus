// pages/search_results_page.dart
import 'package:flutter/material.dart';
import '../booking/booking_page.dart';
import '../profile/profile_page.dart';
import 'nearby_workers_map_page.dart';
import '../../services/location_service.dart';

class SearchResultsPage extends StatefulWidget {
  final String searchQuery;
  final String detectedCategory;
  final String quickFix;
  final List<dynamic> workers;

  const SearchResultsPage({
    Key? key,
    required this.searchQuery,
    required this.detectedCategory,
    required this.quickFix,
    required this.workers,
  }) : super(key: key);

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  String _selectedSort = 'Recommended';
  final List<String> _sortOptions = [
    'Recommended',
    'Top Rated',
    'Nearest',
    'Price: Low',
    'Price: High',
  ];

  // Filter state
  RangeValues _priceRange = const RangeValues(0, 5000);
  double _minRating = 0;
  bool _verifiedOnly = false;
  bool _availableOnly = false;

  // Location for distance calc
  final LocationService _locationService = LocationService();
  double? _userLat;
  double? _userLng;

  // Processed workers list
  List<Map<String, dynamic>> _processedWorkers = [];
  int _activeFilterCount = 0;

  @override
  void initState() {
    super.initState();
    _loadLocationAndProcess();
  }

  Future<void> _loadLocationAndProcess() async {
    final pos = await _locationService.getCurrentPosition();
    if (pos != null) {
      _userLat = pos.latitude;
      _userLng = pos.longitude;
    }
    _applyFiltersAndSort();
  }

  void _applyFiltersAndSort() {
    List<Map<String, dynamic>> workers = widget.workers.map((w) {
      final map = Map<String, dynamic>.from(w as Map);

      // Calculate distance if we have user location and worker has coords
      if (_userLat != null && _userLng != null) {
        final wLat = map['latitude'];
        final wLng = map['longitude'];
        if (wLat != null && wLng != null) {
          final km = _locationService.calculateDistance(
            _userLat!,
            _userLng!,
            wLat.toDouble(),
            wLng.toDouble(),
          );
          map['_distance_km'] = km;
          map['distance'] = km < 1
              ? '${(km * 1000).round()} m'
              : '${km.toStringAsFixed(1)} km';
        }
      }

      return map;
    }).toList();

    // Count active filters
    int filterCount = 0;

    // Apply price filter
    if (_priceRange.start > 0 || _priceRange.end < 5000) {
      filterCount++;
      workers = workers.where((w) {
        final rate = _getRate(w);
        return rate >= _priceRange.start && rate <= _priceRange.end;
      }).toList();
    }

    // Apply rating filter
    if (_minRating > 0) {
      filterCount++;
      workers = workers.where((w) {
        return _getRating(w) >= _minRating;
      }).toList();
    }

    // Apply verified filter
    if (_verifiedOnly) {
      filterCount++;
      workers = workers.where((w) => w['verified'] == true).toList();
    }

    // Apply available filter
    if (_availableOnly) {
      filterCount++;
      workers = workers.where((w) {
        final avail = w['availability'];
        return avail != null && avail is Map && avail.isNotEmpty;
      }).toList();
    }

    // Sort
    switch (_selectedSort) {
      case 'Top Rated':
        workers.sort((a, b) => _getRating(b).compareTo(_getRating(a)));
        break;
      case 'Nearest':
        workers.sort((a, b) {
          final aDist = a['_distance_km'] as double? ?? 99999;
          final bDist = b['_distance_km'] as double? ?? 99999;
          return aDist.compareTo(bDist);
        });
        break;
      case 'Price: Low':
        workers.sort((a, b) => _getRate(a).compareTo(_getRate(b)));
        break;
      case 'Price: High':
        workers.sort((a, b) => _getRate(b).compareTo(_getRate(a)));
        break;
      default:
        break;
    }

    setState(() {
      _processedWorkers = workers;
      _activeFilterCount = filterCount;
    });
  }

  double _getRating(Map<String, dynamic> w) {
    final r = w['rating'];
    if (r is num) return r.toDouble();
    if (r is String) return double.tryParse(r) ?? 0;
    return 0;
  }

  double _getRate(Map<String, dynamic> w) {
    final r = w['hourly_rate'] ?? w['rate'];
    if (r is num) return r.toDouble();
    if (r is String) {
      return double.tryParse(r.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    }
    return 0;
  }

  void _showFilterSheet() {
    RangeValues tempPrice = _priceRange;
    double tempRating = _minRating;
    bool tempVerified = _verifiedOnly;
    bool tempAvailable = _availableOnly;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
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

                  // Title row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            tempPrice = const RangeValues(0, 5000);
                            tempRating = 0;
                            tempVerified = false;
                            tempAvailable = false;
                          });
                        },
                        child: const Text('Reset',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Price range
                  Text(
                    'Hourly Rate',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('₹${tempPrice.start.round()}',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13)),
                      Text('₹${tempPrice.end.round()}',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                  RangeSlider(
                    values: tempPrice,
                    min: 0,
                    max: 5000,
                    divisions: 50,
                    activeColor: const Color(0xFF2196F3),
                    labels: RangeLabels(
                      '₹${tempPrice.start.round()}',
                      '₹${tempPrice.end.round()}',
                    ),
                    onChanged: (values) {
                      setSheetState(() => tempPrice = values);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Minimum rating
                  Text(
                    'Minimum Rating',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (i) {
                      final starValue = (i + 1).toDouble();
                      final isActive = starValue <= tempRating;
                      return GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            tempRating =
                                tempRating == starValue ? 0 : starValue;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            isActive ? Icons.star : Icons.star_border,
                            color:
                                isActive ? Colors.orange : Colors.grey[400],
                            size: 32,
                          ),
                        ),
                      );
                    }),
                  ),
                  if (tempRating > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${tempRating.toInt()}+ stars',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Toggle filters
                  _buildFilterToggle(
                    'Verified Only',
                    'Show only verified workers',
                    Icons.verified,
                    Colors.green,
                    tempVerified,
                    (val) => setSheetState(() => tempVerified = val),
                  ),
                  const SizedBox(height: 12),
                  _buildFilterToggle(
                    'Available Now',
                    'Workers with set availability',
                    Icons.event_available,
                    const Color(0xFF2196F3),
                    tempAvailable,
                    (val) => setSheetState(() => tempAvailable = val),
                  ),
                  const SizedBox(height: 24),

                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _priceRange = tempPrice;
                        _minRating = tempRating;
                        _verifiedOnly = tempVerified;
                        _availableOnly = tempAvailable;
                        Navigator.pop(context);
                        _applyFiltersAndSort();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A5F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterToggle(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: value ? color.withAlpha(15) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? color.withAlpha(80) : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800])),
                Text(subtitle,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 45,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            decoration: InputDecoration(
              hintText: widget.searchQuery,
              hintStyle: const TextStyle(color: Colors.black87),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.black),
                onPressed: _showFilterSheet,
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2196F3),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$_activeFilterCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
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
      body: Column(
        children: [
          // Sort chips
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _sortOptions.map((option) {
                  final isSelected = option == _selectedSort;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(option),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedSort = option);
                        _applyFiltersAndSort();
                      },
                      backgroundColor: Colors.white,
                      selectedColor: const Color(0xFF2196F3),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF2196F3)
                              : Colors.grey[300]!,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Results count and map view
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_processedWorkers.length} pros found${_activeFilterCount > 0 ? ' (filtered)' : ''}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NearbyWorkersMapPage(
                          workers: _processedWorkers,
                          searchQuery: widget.searchQuery,
                          detectedCategory: widget.detectedCategory,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map, size: 18),
                  label: const Text('Map View'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2196F3),
                  ),
                ),
              ],
            ),
          ),

          // Workers list
          Expanded(
            child: _processedWorkers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _activeFilterCount > 0
                              ? Icons.filter_alt_off
                              : Icons.search_off,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _activeFilterCount > 0
                              ? 'No workers match your filters'
                              : 'No workers found',
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey[400]),
                        ),
                        if (_activeFilterCount > 0) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              _priceRange = const RangeValues(0, 5000);
                              _minRating = 0;
                              _verifiedOnly = false;
                              _availableOnly = false;
                              _applyFiltersAndSort();
                            },
                            child: const Text('Clear Filters'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _processedWorkers.length,
                    itemBuilder: (context, index) {
                      final worker = _processedWorkers[index];
                      return _buildWorkerCard(worker);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildWorkerCard(dynamic worker) {
    final name = worker['name'] ?? worker.toString();
    final title =
        worker['title'] ?? '${widget.detectedCategory} Professional';
    final experience = worker['experience'] ?? '';

    double rating = 0;
    if (worker['rating'] != null) {
      if (worker['rating'] is num) {
        rating = worker['rating'].toDouble();
      } else if (worker['rating'] is String) {
        rating = double.tryParse(worker['rating']) ?? 0;
      }
    }

    int reviewCount = 0;
    if (worker['reviews'] != null) {
      if (worker['reviews'] is int) {
        reviewCount = worker['reviews'];
      } else if (worker['reviews'] is String) {
        reviewCount = int.tryParse(worker['reviews']) ?? 0;
      }
    }

    String distanceStr = '';
    if (worker['distance'] != null) {
      if (worker['distance'] is num) {
        distanceStr = '${worker['distance'].toStringAsFixed(1)} km';
      } else if (worker['distance'] is String) {
        distanceStr = worker['distance'];
      }
    }

    int hourlyRate = 0;
    final rateValue = worker['hourly_rate'] ?? worker['rate'];
    if (rateValue != null) {
      if (rateValue is num) {
        hourlyRate = rateValue.toInt();
      } else if (rateValue is String) {
        hourlyRate =
            int.tryParse(rateValue.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
      }
    }

    final isVerified = worker['verified'] ?? false;
    final avatar = worker['avatar'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Worker header
            Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: avatar.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                avatar,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) {
                                  return Center(
                                    child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : 'P',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          : Center(
                              child: Text(
                                name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : 'P',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                    if (isVerified)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: Colors.white, width: 2),
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
                        experience.isNotEmpty
                            ? '$title • $experience'
                            : title,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹$hourlyRate/hr',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Rating and distance
            Row(
              children: [
                const Icon(Icons.star, color: Colors.orange, size: 18),
                const SizedBox(width: 4),
                Text(
                  rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (reviewCount > 0)
                  Text(
                    ' ($reviewCount)',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                if (distanceStr.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.location_on,
                      color: Colors.grey, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    distanceStr,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // AI Suggested Fix
            if (widget.quickFix.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.auto_awesome,
                            color: Color(0xFF2196F3), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'AI SUGGESTED FIX',
                          style: TextStyle(
                            color: Color(0xFF2196F3),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.quickFix,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

            // AI Review Summary from Gemini
            if (worker['ai_review_summary'] != null &&
                worker['ai_review_summary'].toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFFE082),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.rate_review,
                            color: Color(0xFFF57C00), size: 16),
                        const SizedBox(width: 6),
                        const Text(
                          'AI REVIEW SUMMARY',
                          style: TextStyle(
                            color: Color(0xFFF57C00),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        if (worker['review_count'] != null &&
                            worker['review_count'] > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFFF57C00).withAlpha(25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${worker['review_count']} reviews',
                              style: const TextStyle(
                                color: Color(0xFFF57C00),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      worker['ai_review_summary'].toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _showWorkerProfile(worker);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey[300]!),
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'View Profile',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _bookWorker(worker);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Book Now',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showWorkerProfile(dynamic worker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(worker['name'] ?? 'Worker Profile'),
        content: const Text('Worker profile page coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _bookWorker(dynamic worker) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingPage(
          worker: Map<String, dynamic>.from(worker),
          searchQuery: widget.searchQuery,
          detectedCategory: widget.detectedCategory,
        ),
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
              _buildNavItem(Icons.home_outlined, 'Home', false, () {
                Navigator.pop(context);
              }),
              _buildNavItem(Icons.search, 'Search', true, () {}),
              _buildNavItem(
                  Icons.chat_bubble_outline, 'Messages', false, () {}),
              _buildNavItem(Icons.person_outline, 'Profile', false, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfilePage(),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
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
              fontWeight:
                  isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
