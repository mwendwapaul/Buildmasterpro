import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Geofence {
  final String id;
  final double latitude;
  final double longitude;
  final double radius;
  final String name;
  final DateTime createdAt;
  final String userId;

  Geofence({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.name,
    required this.createdAt,
    required this.userId,
  });

  factory Geofence.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Geofence(
      id: doc.id,
      latitude: data['latitude'] as double,
      longitude: data['longitude'] as double,
      radius: (data['radius'] is int) ? (data['radius'] as int).toDouble() : data['radius'] as double,
      name: data['name'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      userId: data['userId'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
    };
  }
}

class GeofencingScreen extends StatefulWidget {
  const GeofencingScreen({super.key});

  @override
  GeofencingScreenState createState() => GeofencingScreenState();
}

class GeofencingScreenState extends State<GeofencingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final List<Geofence> _geofences = [];
  GoogleMapController? _mapController;
  bool _isLoading = true;
  bool _isAddingGeofence = false; 
  Position? _currentPosition;
  final Set<Circle> _circles = {};
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _initializeApp());
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  Future<void> _initializeApp() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) {
          _showErrorDialog('Authentication Error', 'Please sign in to use this feature.');
          _safeSetState(() => _isLoading = false);
        }
        return;
      }

      await _checkAndRequestLocationPermission();
      if (_currentPosition != null && mounted) {
        await _loadGeofences();
      } else {
        _safeSetState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Initialization Error', 'Failed to initialize app: $e');
        _safeSetState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkAndRequestLocationPermission() async {
    if (!mounted) return;

    _safeSetState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showErrorDialog('Location Services Disabled',
              'Please enable location services to proceed.');
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            _showPermissionDialog();
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showPermissionDialog(openSettings: true);
        }
        return;
      }

      await _getCurrentLocation();
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Permission Error', 'Failed to request location permission: $e');
      }
    } finally {
      if (mounted) {
        _safeSetState(() => _isLoading = false);
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;

    try {
      _safeSetState(() => _isLoading = true);

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      ).catchError((error) async {
        final lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          return lastPosition;
        }
        throw error;
      }).timeout(
        const Duration(seconds: 15),
        onTimeout: () async {
          return await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
          );
        },
      );

      if (mounted) {
        _safeSetState(() {
          _currentPosition = position;
          _isLoading = false;
        });
        _updateMapCamera();
      }
    } catch (e) {
      if (mounted) {
        _safeSetState(() => _isLoading = false);
        _showErrorDialog('Location Error', 'Failed to get current location: $e');
      }
    }
  }

  void _updateMapCamera() {
    if (_mapController != null && _currentPosition != null && mounted) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          15,
        ),
      );
    }
  }

  Future<void> _loadGeofences() async {
    if (!mounted) return;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      _safeSetState(() => _isLoading = true);

      final snapshot = await _firestore
          .collection('geofences')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Connection timeout, please try again'),
          );

      if (!mounted) return;

      _safeSetState(() {
        _geofences.clear();
        for (final doc in snapshot.docs) {
          try {
            final geofence = Geofence.fromFirestore(doc);
            _geofences.add(geofence);
          } catch (e) {
            debugPrint('Error parsing geofence: $e');
          }
        }
        _updateMapOverlays();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        _safeSetState(() => _isLoading = false);
        _showErrorDialog('Data Error', 'Failed to load geofences: $e');
      }
    }
  }

  void _updateMapOverlays() {
    if (!mounted) return;

    try {
      _safeSetState(() {
        _circles.clear();
        _markers.clear();

        for (final geofence in _geofences) {
          if (geofence.latitude.isFinite && geofence.longitude.isFinite &&
              geofence.radius.isFinite && geofence.radius > 0) {
            _circles.add(
              Circle(
                circleId: CircleId(geofence.id),
                center: LatLng(geofence.latitude, geofence.longitude),
                radius: geofence.radius,
                fillColor: Colors.blue.withAlpha(76),
                strokeColor: Colors.blue,
                strokeWidth: 2,
              ),
            );

            _markers.add(
              Marker(
                markerId: MarkerId(geofence.id),
                position: LatLng(geofence.latitude, geofence.longitude),
                infoWindow: InfoWindow(title: geofence.name),
              ),
            );
          }
        }
      });
    } catch (e) {
      debugPrint('Error updating map overlays: $e');
    }
  }

  Future<void> _addGeofence(BuildContext context) async {
    if (!mounted) return;

    final user = _auth.currentUser;
    if (user == null) {
      _showErrorDialog('Authentication Error', 'Please sign in to add a geofence.');
      return;
    }

    if (_currentPosition == null) {
      _showErrorDialog('Location Error', 'Current location not available. Please try again.');
      return;
    }

    final nameController = TextEditingController();
    final radiusController = TextEditingController(text: '100');

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Geofence'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Geofence Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[700],
                ),
                maxLength: 50,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: radiusController,
                decoration: InputDecoration(
                  labelText: 'Radius (meters)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[700],
                ),
                keyboardType: TextInputType.number,
                maxLength: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Please enter a name')),
                );
                return;
              }

              final radius = double.tryParse(radiusController.text.trim());
              if (radius == null || radius <= 0 || radius > 10000) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Radius must be between 1 and 10,000 meters')),
                );
                return;
              }

              Navigator.pop(dialogContext, {
                'name': nameController.text.trim(),
                'radius': radius,
              });
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (!mounted || result == null) return;

    _safeSetState(() => _isAddingGeofence = true);
    try {
      final geofence = Geofence(
        id: 'geofence_${DateTime.now().millisecondsSinceEpoch}',
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        radius: result['radius'],
        name: result['name'],
        createdAt: DateTime.now(),
        userId: user.uid,
      );

      await _firestore.collection('geofences').doc(geofence.id).set(geofence.toMap())
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('Connection timeout, please try again'),
        );

      if (mounted) {
        _safeSetState(() {
          _geofences.insert(0, geofence);
          _updateMapOverlays();
          _isAddingGeofence = false;
        });

        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Geofence added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        _safeSetState(() => _isAddingGeofence = false);
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to add geofence: $e')),
        );
      }
    }
  }

  Future<void> _removeGeofence(Geofence geofence) async {
    if (!mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete "${geofence.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    _safeSetState(() => _isAddingGeofence = true);

    try {
      await _firestore.collection('geofences').doc(geofence.id).delete()
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('Connection timeout, please try again'),
        );

      if (mounted) {
        _safeSetState(() {
          _geofences.remove(geofence);
          _updateMapOverlays();
          _isAddingGeofence = false;
        });

        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Geofence removed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        _safeSetState(() => _isAddingGeofence = false);
        _showErrorDialog('Error', 'Failed to remove geofence: $e');
      }
    }
  }

  Future<void> _showErrorDialog(String title, String message) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog({bool openSettings = false}) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'Location permission is required to use geofencing. Please enable it to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (openSettings) {
                openAppSettings();
              } else {
                _checkAndRequestLocationPermission();
              }
            },
            child: Text(openSettings ? 'Open Settings' : 'Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geofencing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'Get Current Location',
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: _currentPosition != null
                                ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                                : const LatLng(37.7749, -122.4194),
                            zoom: 15,
                          ),
                          circles: _circles,
                          markers: _markers,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: false,
                          onMapCreated: (controller) {
                            _mapController = controller;
                            _updateMapCamera();
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        child: _geofences.isEmpty
                            ? Center(
                                child: Card(
                                  color: Colors.grey[800],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'No geofences added yet. Tap + to add one!',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _geofences.length,
                                itemBuilder: (context, index) {
                                  final geofence = _geofences[index];
                                  return Card(
                                    color: Colors.grey[800],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    child: Slidable(
                                      key: ValueKey(geofence.id),
                                      endActionPane: ActionPane(
                                        motion: const ScrollMotion(),
                                        children: [
                                          SlidableAction(
                                            onPressed: (_) => _removeGeofence(geofence),
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            icon: Icons.delete,
                                            label: 'Delete',
                                          ),
                                        ],
                                      ),
                                      child: ListTile(
                                        leading: const CircleAvatar(
                                          backgroundColor: Colors.blue,
                                          child: Icon(Icons.location_on, color: Colors.white),
                                        ),
                                        title: Text(
                                          geofence.name,
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                        subtitle: Text(
                                          'Radius: ${geofence.radius.toStringAsFixed(0)}m',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                        onTap: () {
                                          _mapController?.animateCamera(
                                            CameraUpdate.newLatLngZoom(
                                              LatLng(geofence.latitude, geofence.longitude),
                                              15,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
          if (_isAddingGeofence)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addGeofence(context),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}