// lib/pages/nearby_workers_map_page.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/location_service.dart';
import '../../services/api_config.dart';
import '../booking/booking_page.dart';

class NearbyWorkersMapPage extends StatefulWidget {
  final List<dynamic>? workers;
  final String? searchQuery;
  final String? detectedCategory;

  const NearbyWorkersMapPage({
    super.key,
    this.workers,
    this.searchQuery,
    this.detectedCategory,
  });

  @override
  State<NearbyWorkersMapPage> createState() => _NearbyWorkersMapPageState();
}

class _NearbyWorkersMapPageState extends State<NearbyWorkersMapPage> {
  final LocationService _locationService = LocationService();
  List<dynamic> _workers = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Google Maps controller
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  // User's current location - default to a central location
  double _userLat = 12.9716; // Bangalore default
  double _userLng = 77.5946;
  bool _hasUserLocation = false;

  // Custom marker icon for user location
  BitmapDescriptor? _userMarkerIcon;

  // Selected worker for bottom sheet
  Map<String, dynamic>? _selectedWorker;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<BitmapDescriptor> _createCustomMarker(Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 48.0;

    // Draw the pin head (circle)
    final paint = Paint()..color = color;
    canvas.drawCircle(const Offset(size / 2, size / 3), size / 3, paint);

    // Draw the pin point (triangle)
    final path = Path()
      ..moveTo(size / 2 - size / 5, size / 3)
      ..lineTo(size / 2, size - 4)
      ..lineTo(size / 2 + size / 5, size / 3)
      ..close();
    canvas.drawPath(path, paint);

    // Draw white inner circle
    final innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 3), size / 6, innerPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  Future<void> _initializeMap() async {
    await _locationService.initialize();
    _userMarkerIcon = await _createCustomMarker(const Color(0xFF2196F3));

    // Get user's location FIRST before showing the map
    await _getUserLocation();

    // If workers are passed, use them
    if (widget.workers != null && widget.workers!.isNotEmpty) {
      setState(() {
        _workers = widget.workers!;
        _isLoading = false;
      });
    } else {
      // Fetch nearby workers from backend
      await _fetchNearbyWorkers();
    }

    // Create markers for workers
    _createMarkers();
  }

  Future<void> _getUserLocation({bool animateCamera = false}) async {
    final position = await _locationService.getCurrentPosition();
    if (position != null) {
      print('✅ Got user location: ${position.latitude}, ${position.longitude}');
      setState(() {
        _userLat = position.latitude;
        _userLng = position.longitude;
        _hasUserLocation = true;
      });

      // Move camera to user location if requested (e.g., when tapping location button)
      if (animateCamera && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(_userLat, _userLng), 14),
        );
      }

      // Update markers
      _createMarkers();
    } else {
      print('❌ Could not get user location');
    }
  }

  Future<void> _fetchNearbyWorkers() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig().baseUrl}/workers/nearby'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _workers = data['workers'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load workers';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error connecting to server';
        _isLoading = false;
      });
    }
  }

  void _createMarkers() async {
    _markers.clear();

    // Add user location marker
    // Note: On Flutter Web, marker hues don't work - all show as red
    // But we still add it so user can see their location
    if (_hasUserLocation) {
      _markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(_userLat, _userLng),
          icon: _userMarkerIcon ?? BitmapDescriptor.defaultMarker,
          infoWindow: const InfoWindow(
            title: '📍 You are here',
            snippet: 'Your current location',
          ),
        ),
      );
      print('📍 User location: $_userLat, $_userLng');
    }

    // Add worker markers
    for (int i = 0; i < _workers.length; i++) {
      final worker = Map<String, dynamic>.from(_workers[i]);
      final workerLat = worker['latitude'];
      final workerLng = worker['longitude'];

      if (workerLat != null && workerLng != null) {
        final name = worker['name'] ?? 'Worker';
        final rating = (worker['rating'] ?? 0).toString();

        _markers.add(
          Marker(
            markerId: MarkerId('worker_$i'),
            position: LatLng(workerLat.toDouble(), workerLng.toDouble()),
            icon: BitmapDescriptor.defaultMarkerWithHue(_getMarkerHue(i)),
            infoWindow: InfoWindow(
              title: name,
              snippet: '⭐ $rating',
            ),
            onTap: () => _selectWorker(worker),
          ),
        );
        print('👷 Added worker marker: $name at $workerLat, $workerLng');
      }
    }

    print('📌 Total markers: ${_markers.length}');
    setState(() {});
  }

  double _getMarkerHue(int index) {
    final hues = [
      BitmapDescriptor.hueGreen,
      BitmapDescriptor.hueOrange,
      BitmapDescriptor.hueViolet,
      BitmapDescriptor.hueCyan,
      BitmapDescriptor.hueRose,
      BitmapDescriptor.hueYellow,
      BitmapDescriptor.hueMagenta,
    ];
    return hues[index % hues.length];
  }

  void _selectWorker(Map<String, dynamic> worker) {
    setState(() {
      _selectedWorker = worker;
    });

    // Animate to worker location
    final workerLat = worker['latitude'];
    final workerLng = worker['longitude'];
    if (workerLat != null && workerLng != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(workerLat.toDouble(), workerLng.toDouble()),
        ),
      );
    }
  }

  void _centerOnUser() {
    if (_hasUserLocation) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(_userLat, _userLng), 14),
      );
    } else {
      _getUserLocation(animateCamera: true);
    }
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
        title: const Text(
          'Nearby Workers',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: Color(0xFF2196F3)),
            onPressed: _centerOnUser,
          ),
          IconButton(
            icon: const Icon(Icons.list, color: Colors.black),
            onPressed: () => Navigator.pop(context),
            tooltip: 'List View',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          _fetchNearbyWorkers();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Google Map (takes remaining space)
                    Expanded(
                      child: Stack(
                        children: [
                          GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(_userLat, _userLng),
                              zoom: 12,
                            ),
                            markers: _markers,
                            myLocationEnabled: true,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: true,
                            mapToolbarEnabled: false,
                            scrollGesturesEnabled: true,
                            zoomGesturesEnabled: true,
                            onMapCreated: (controller) {
                              _mapController = controller;
                              _createMarkers();
                            },
                            onTap: (_) {
                              setState(() {
                                _selectedWorker = null;
                              });
                            },
                          ),

                          // Worker count chip at top
                          Positioned(
                            top: 16,
                            left: 16,
                            right: 16,
                            child: _buildWorkerCountChip(),
                          ),

                          // Selected worker card overlay
                          if (_selectedWorker != null)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: _buildSelectedWorkerCard(),
                            ),
                        ],
                      ),
                    ),

                    // Worker list - outside the map, no gesture conflict
                    _buildWorkerListSheet(),
                  ],
                ),
    );
  }

  Widget _buildWorkerCountChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.people,
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
                  '${_workers.length} professionals nearby',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (widget.detectedCategory != null)
                  Text(
                    widget.detectedCategory!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (_hasUserLocation)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.gps_fixed, size: 14, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    'GPS',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedWorkerCard() {
    final worker = _selectedWorker!;
    final name = worker['name'] ?? 'Worker';
    final title = worker['title'] ?? '${widget.detectedCategory ?? "Service"} Professional';
    final rating = (worker['rating'] ?? 0).toDouble();
    final reviewCount = worker['reviews'] ?? 0;
    final hourlyRate = worker['hourly_rate'] ?? worker['rate'] ?? 0;

    // Calculate distance from user to worker
    String distance = 'N/A';
    final workerLat = worker['latitude'];
    final workerLng = worker['longitude'];
    if (_hasUserLocation && workerLat != null && workerLng != null) {
      final km = _locationService.calculateDistance(
        _userLat, _userLng,
        workerLat.toDouble(), workerLng.toDouble(),
      );
      distance = km < 1
          ? '${(km * 1000).round()} m'
          : '${km.toStringAsFixed(1)} km';
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(38),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${rating.toStringAsFixed(1)} ($reviewCount)',
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.location_on, color: Colors.grey, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          distance.toString(),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹$hourlyRate',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                  const Text(
                    '/hour',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _selectedWorker = null;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingPage(
                          worker: worker,
                          searchQuery: widget.searchQuery ?? '',
                          detectedCategory: widget.detectedCategory ?? '',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Book Now',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerListSheet() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Workers',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Tap to select worker',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Horizontal worker list
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              physics: const BouncingScrollPhysics(),
              itemCount: _workers.length,
              itemBuilder: (context, index) {
                final worker = Map<String, dynamic>.from(_workers[index]);
                return _buildWorkerListItem(worker, index);
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildWorkerListItem(Map<String, dynamic> worker, int index) {
    final name = worker['name'] ?? 'Worker';
    final rating = (worker['rating'] ?? 0).toDouble();
    final hourlyRate = worker['hourly_rate'] ?? worker['rate'] ?? 0;

    return GestureDetector(
      onTap: () => _selectWorker(worker),
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _getMarkerColor(index),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name.split(' ')[0],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.orange, size: 12),
                Text(
                  ' ${rating.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
            Text(
              '₹$hourlyRate/hr',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getMarkerColor(int index) {
    final colors = [
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFF9800), // Orange
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFFE91E63), // Pink
      const Color(0xFF3F51B5), // Indigo
      const Color(0xFFFF5722), // Deep Orange
      const Color(0xFF009688), // Teal
    ];
    return colors[index % colors.length];
  }
}
