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

  // Cairo default
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
    });
  }

  // Approximate Egypt bounding box
  bool _isWithinEgypt(LatLng point) {
    const double minLat = 22.0;
    const double maxLat = 31.7;
    const double minLon = 24.7;
    const double maxLon = 36.9;
    return point.latitude >= minLat &&
        point.latitude <= maxLat &&
        point.longitude >= minLon &&
        point.longitude <= maxLon;
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        _showMessage('Location services are disabled. Please enable them.');
      }
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          _showMessage('Location permissions are denied');
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        _showMessage(
          'Location permissions are permanently denied. Please enable them in settings.',
        );
      }
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
        if (mounted) {
          setState(() => _isLoadingLocation = false);
        }
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Location request timed out');
        },
      );

      if (!mounted) return;

      final LatLng detected = LatLng(position.latitude, position.longitude);
      final LatLng effective = _isWithinEgypt(detected)
          ? detected
          : const LatLng(30.033333, 31.233334); // Fallback Cairo

      setState(() {
        _currentLocation = effective;
        _currentCenter = effective;
        _markers = [
          Marker(
            width: 80,
            height: 80,
            point: effective,
            builder: (ctx) => Container(
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.my_location,
                size: 40,
                color: Colors.blue,
              ),
            ),
          ),
        ];
        _isLoadingLocation = false;
      });

      if (!_isWithinEgypt(detected)) {
        _showMessage('Current location outside Egypt. Using Cairo.');
      }

      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted && _mapReady) {
        try {
          _mapController.move(_currentCenter, 15.0);
        } catch (e) {
          debugPrint('Map move error: $e');
        }
      }
    } catch (e) {
      debugPrint('Location error: $e');
      if (mounted) {
        _showMessage('Failed to get location. Please try again.');
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<LatLng?> _searchLocation(String query) async {
    if (query.trim().isEmpty) return null;

    // Restrict to Egypt via country code and a small limit
    final Uri url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(query)}'
      '&format=jsonv2&limit=1&countrycodes=eg',
    );

    try {
      final response = await http
          .get(
            url,
            headers: const {
              'User-Agent': 'HiddenTreasures/1.0 (contact: your_email@gmail.com)',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        if (data.isNotEmpty) {
          final double lat = double.parse('${data[0]['lat']}');
          final double lon = double.parse('${data[0]['lon']}');
          final LatLng point = LatLng(lat, lon);
          if (_isWithinEgypt(point)) return point;
        }
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        _showMessage('Search failed. Please try again.');
      }
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

    final Uri url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${_startPoint!.longitude},${_startPoint!.latitude};'
      '${_endPoint!.longitude},${_endPoint!.latitude}'
      '?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;

        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final Map<String, dynamic> route =
              (data['routes'] as List).first as Map<String, dynamic>;
          final List<dynamic> coordinates =
              (route['geometry'] as Map<String, dynamic>)['coordinates']
                  as List<dynamic>;

          if (!mounted) return;

          setState(() {
            _routePoints = coordinates
                .map(
                  (coord) => LatLng(
                    (coord as List)[1].toDouble(),
                    coord[0].toDouble(),
                  ),
                )
                .toList();

            _distance = '${(route['distance'] / 1000).toStringAsFixed(2)} km';
            _duration = '${(route['duration'] / 60).toStringAsFixed(0)} min';

            _markers = [
              Marker(
                width: 80,
                height: 80,
                point: _startPoint!,
                builder: (ctx) => const Icon(
                  Icons.location_on,
                  size: 40,
                  color: Colors.green,
                ),
              ),
              Marker(
                width: 80,
                height: 80,
                point: _endPoint!,
                builder: (ctx) =>
                    const Icon(Icons.location_on, size: 40, color: Colors.red),
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
            } catch (e) {
              debugPrint('Fit bounds error: $e');
            }
          }
        } else {
          if (mounted) {
            _showMessage('No route found');
            setState(() => _isLoadingRoute = false);
          }
        }
      } else {
        if (mounted) {
          _showMessage('Failed to get directions');
          setState(() => _isLoadingRoute = false);
        }
      }
    } catch (e) {
      debugPrint('Directions error: $e');
      if (mounted) {
        _showMessage('Failed to get directions. Please try again.');
        setState(() => _isLoadingRoute = false);
      }
    }
  }

  Future<void> _setStartPoint() async {
    final LatLng? location = await _searchLocation(_startController.text);
    if (location != null) {
      if (mounted) {
        setState(() {
          _startPoint = location;
        });
        _showMessage('Start point set');
      }
    } else {
      _showMessage('Location not found');
    }
  }

  Future<void> _setEndPoint() async {
    final LatLng? location = await _searchLocation(_endController.text);
    if (location != null) {
      if (mounted) {
        setState(() {
          _endPoint = location;
        });
        _showMessage('End point set');
      }
    } else {
      _showMessage('Location not found');
    }
  }

  void _useCurrentLocationAsStart() {
    if (_currentLocation != null) {
      setState(() {
        _startPoint = _currentLocation;
        _startController.text = 'Current Location';
      });
      _showMessage('Using current location as start point');
    } else {
      _showMessage('Current location not available. Please wait...');
      _getCurrentLocation();
    }
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
                  child: const Icon(
                    Icons.my_location,
                    size: 40,
                    color: Colors.blue,
                  ),
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
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              // Using initial* naming keeps compatibility with recent flutter_map
              initialCenter: _currentCenter,
              initialZoom: 13.0,
              minZoom: 3.0,
              maxZoom: 18.0,
              onMapReady: () {
                setState(() => _mapReady = true);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.hiddentreasures.app',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                  ],
                ),
              MarkerLayer(markers: _markers),
            ],
          ),

          // Direction/search panel
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
                  // Start location
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.trip_origin,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _startController,
                            decoration: InputDecoration(
                              hintText: 'Start location (Egypt only)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _setStartPoint(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.search,
                            color: Colors.deepOrange,
                          ),
                          tooltip: 'Search start',
                          onPressed: () async {
                            await _setStartPoint();
                            if (_startPoint != null && _endPoint != null) {
                              await _getDirections();
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.my_location,
                            color: Colors.blue,
                          ),
                          onPressed: _useCurrentLocationAsStart,
                          tooltip: 'Use current location',
                        ),
                      ],
                    ),
                  ),

                  // End location
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _endController,
                            decoration: InputDecoration(
                              hintText: 'End location (Egypt only)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              isDense: true,
                            ),
                            onSubmitted: (_) async {
                              await _setEndPoint();
                              if (_startPoint != null && _endPoint != null) {
                                await _getDirections();
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.search,
                            color: Colors.deepOrange,
                          ),
                          onPressed: () async {
                            await _setEndPoint();
                            if (_startPoint != null && _endPoint != null) {
                              await _getDirections();
                            }
                          },
                          tooltip: 'Search and get directions',
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
                              const Icon(
                                Icons.straighten,
                                size: 18,
                                color: Colors.deepOrange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _distance!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 18,
                                color: Colors.deepOrange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _duration!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange,
                                ),
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

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }
}
