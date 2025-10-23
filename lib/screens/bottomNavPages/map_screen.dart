import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  // Cairo default center
  LatLng _currentCenter = const LatLng(30.033333, 31.233334);
  LatLng? _currentLocation;
  LatLng? _startPoint;
  LatLng? _endPoint;

  List<Marker> _markers = [];
  List<LatLng> _routePoints = [];
  bool _isLoadingLocation = false;
  bool _isLoadingRoute = false;
  String? _distance;
  String? _duration;
  bool _mapReady = false;

  static const LatLng _egyptSouthWest = LatLng(21.725, 24.700); // Rough bounds
  static const LatLng _egyptNorthEast = LatLng(31.833, 36.900);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
    });
  }

  bool _isInEgypt(LatLng p) {
    return p.latitude >= _egyptSouthWest.latitude &&
        p.latitude <= _egyptNorthEast.latitude &&
        p.longitude >= _egyptSouthWest.longitude &&
        p.longitude <= _egyptNorthEast.longitude;
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage('Location services are disabled. Please enable them.');
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showMessage('Location permissions are denied');
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showMessage('Location permissions are permanently denied in settings.');
      return false;
    }
    return true;
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() => _isLoadingLocation = true);
    try {
      final hasPermission = await _handleLocationPermission();
      if (!hasPermission) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Location request timed out'),
      );

      LatLng detected = LatLng(position.latitude, position.longitude);
      if (!_isInEgypt(detected)) {
        // If detected outside Egypt (emulator mock), fall back to Cairo
        detected = const LatLng(30.033333, 31.233334);
      }

      if (!mounted) return;
      setState(() {
        _currentLocation = detected;
        _currentCenter = detected;
        _markers = [
          Marker(
            width: 80,
            height: 80,
            point: detected,
            builder: (ctx) => Container(
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.my_location, size: 40, color: Colors.blue),
            ),
          ),
        ];
        _isLoadingLocation = false;
      });

      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted && _mapReady) {
        try {
          _mapController.move(_currentCenter, 15.0);
        } catch (_) {}
      }
    } catch (e) {
      _showMessage('Failed to get location. Please try again.');
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<LatLng?> _searchLocation(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    // Restrict search to Egypt by adding country filter
    final encodedQuery = Uri.encodeQueryComponent('$trimmed, Egypt');
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?country=Egypt&q=$encodedQuery&format=json&limit=1',
    );
    try {
      final response = await http.get(
        url,
        headers: const {
          'User-Agent': 'HiddenTreasures/1.0 (contact: example@example.com)',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final candidate = LatLng(lat, lon);
          if (_isInEgypt(candidate)) return candidate;
        }
      }
    } catch (_) {
      _showMessage('Search failed. Please try again.');
    }
    return null;
  }

  Future<void> _getDirections() async {
    if (_startPoint == null || _endPoint == null) {
      _showMessage('Please set both start and end points');
      return;
    }
    if (!mounted) return;
    setState(() => _isLoadingRoute = true);

    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${_startPoint!.longitude},${_startPoint!.latitude};'
      '${_endPoint!.longitude},${_endPoint!.latitude}'
      '?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes.first as Map<String, dynamic>;
          final coordinates = (route['geometry']['coordinates'] as List)
              .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
              .toList();

          if (!mounted) return;
          setState(() {
            _routePoints = coordinates;
            _distance = '${(route['distance'] / 1000).toStringAsFixed(2)} km';
            _duration = '${(route['duration'] / 60).toStringAsFixed(0)} min';
            _markers = [
              Marker(
                width: 80,
                height: 80,
                point: _startPoint!,
                builder: (ctx) => const Icon(Icons.location_on, size: 40, color: Colors.green),
              ),
              Marker(
                width: 80,
                height: 80,
                point: _endPoint!,
                builder: (ctx) => const Icon(Icons.location_on, size: 40, color: Colors.red),
              ),
            ];
            _isLoadingRoute = false;
          });

          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted && _mapReady && _routePoints.isNotEmpty) {
            try {
              final bounds = LatLngBounds.fromPoints(_routePoints);
              _mapController.fitBounds(
                bounds,
                options: const FitBoundsOptions(padding: EdgeInsets.all(50)),
              );
            } catch (_) {}
          }
        } else {
          _showMessage('No route found');
          if (mounted) setState(() => _isLoadingRoute = false);
        }
      } else {
        _showMessage('Failed to get directions');
        if (mounted) setState(() => _isLoadingRoute = false);
      }
    } catch (_) {
      _showMessage('Failed to get directions. Please try again.');
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  Future<void> _setStartPoint() async {
    final location = await _searchLocation(_startController.text);
    if (location != null) {
      if (!mounted) return;
      setState(() => _startPoint = location);
      _showMessage('Start point set');
      if (_endPoint != null) _getDirections();
    } else {
      _showMessage('Start location not found in Egypt');
    }
  }

  Future<void> _setEndPoint() async {
    final location = await _searchLocation(_endController.text);
    if (location != null) {
      if (!mounted) return;
      setState(() => _endPoint = location);
      _showMessage('End point set');
      if (_startPoint != null) _getDirections();
    } else {
      _showMessage('End location not found in Egypt');
    }
  }

  void _useCurrentLocationAsStart() {
    if (_currentLocation != null) {
      setState(() {
        _startPoint = _currentLocation;
        _startController.text = 'Current Location';
      });
      _showMessage('Using current location as start');
      if (_endPoint != null) _getDirections();
    } else {
      _showMessage('Current location not available. Please wait...');
      _getCurrentLocation();
    }
  }

  void _clearRoute() {
    setState(() {
      _routePoints = [];
      _startPoint = null;
      _endPoint = null;
      _distance = null;
      _duration = null;
      _startController.clear();
      _endController.clear();
      _markers = _currentLocation != null
          ? [
              Marker(
                width: 80,
                height: 80,
                point: _currentLocation!,
                builder: (ctx) => Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.my_location, size: 40, color: Colors.blue),
                ),
              ),
            ]
          : [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map & Directions'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _currentCenter,
              zoom: 13.0,
              minZoom: 3.0,
              maxZoom: 18.0,
              onMapReady: () {
                setState(() => _mapReady = true);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.hiddentreasures.app',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(points: _routePoints, strokeWidth: 4.0, color: Colors.blue),
                  ],
                ),
              MarkerLayer(markers: _markers),
            ],
          ),

          // Direction panel
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.trip_origin, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _startController,
                            decoration: InputDecoration(
                              hintText: 'Start location',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _setStartPoint(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search, color: Colors.green),
                          onPressed: _setStartPoint,
                          tooltip: 'Search start',
                        ),
                        IconButton(
                          icon: const Icon(Icons.my_location, color: Colors.blue),
                          onPressed: _useCurrentLocationAsStart,
                          tooltip: 'Use current location',
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _endController,
                            decoration: InputDecoration(
                              hintText: 'End location',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _setEndPoint(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search, color: Colors.deepOrange),
                          onPressed: _setEndPoint,
                          tooltip: 'Search destination',
                        ),
                        IconButton(
                          icon: const Icon(Icons.directions, color: Colors.deepOrange),
                          onPressed: _getDirections,
                          tooltip: 'Get directions',
                        ),
                      ],
                    ),
                  ),

                  if (_distance != null && _duration != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.straighten, size: 18, color: Colors.deepOrange),
                              const SizedBox(width: 4),
                              Text(
                                _distance!,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 18, color: Colors.deepOrange),
                              const SizedBox(width: 4),
                              Text(
                                _duration!,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (_isLoadingLocation || _isLoadingRoute)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange),
                ),
              ),
            ),

          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton(
              heroTag: 'location',
              backgroundColor: Colors.white,
              onPressed: _getCurrentLocation,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),

          if (_routePoints.isNotEmpty)
            Positioned(
              right: 16,
              bottom: 32,
              child: FloatingActionButton(
                heroTag: 'clear',
                backgroundColor: Colors.white,
                onPressed: _clearRoute,
                child: const Icon(Icons.clear, color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }
}
