import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:permission_handler/permission_handler.dart';

class Geofence {
  final String id;
  final double latitude;
  final double longitude;
  final double radius;
  final String name;
  final DateTime createdAt;

  Geofence({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.name,
    required this.createdAt,
  });

  factory Geofence.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Geofence(
      id: doc.id,
      latitude: data['latitude'],
      longitude: data['longitude'],
      radius: data['radius'].toDouble(),
      name: data['name'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
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
  final List<Geofence> _geofences = [];
  GoogleMapController? _mapController;
  bool _isLoading = true;
  Position? _currentPosition;
  final Set<Circle> _circles = {};
  final Set<Marker> _markers = {};
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _loadGeofences();
  }

  @override
  void dispose() {
    _mounted = false;
    _mapController?.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (_mounted) {
      setState(fn);
    }
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      await _getCurrentLocation();
    } else if (_mounted) {
      _showErrorDialog(
        'Location Permission Required',
        'Location permission is required for this app to function properly.'
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Updated to use LocationSettings instead of deprecated desiredAccuracy
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );
      
      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      
      _safeSetState(() {
        _currentPosition = position;
      });

      if (_mapController != null && _mounted) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            15,
          ),
        );
      }
    } catch (e) {
      if (_mounted) {
        _showErrorDialog('Location Error', 'Failed to get current location');
      }
    }
  }

  Future<void> _loadGeofences() async {
    try {
      final snapshot = await _firestore
          .collection('geofences')
          .orderBy('createdAt', descending: true)
          .get();

      if (!_mounted) return;

      _safeSetState(() {
        _geofences.clear();
        _geofences.addAll(
          snapshot.docs.map((doc) => Geofence.fromFirestore(doc))
        );
        _isLoading = false;
        _updateMapOverlays();
      });
    } catch (e) {
      if (_mounted) {
        _showErrorDialog('Data Error', 'Failed to load geofences');
        _safeSetState(() => _isLoading = false);
      }
    }
  }

  void _updateMapOverlays() {
    _safeSetState(() {
      _circles.clear();
      _markers.clear();

      for (final geofence in _geofences) {
        _circles.add(Circle(
          circleId: CircleId(geofence.id),
          center: LatLng(geofence.latitude, geofence.longitude),
          radius: geofence.radius,
          fillColor: Colors.blue.withOpacity(0.3),
          strokeColor: Colors.blue,
          strokeWidth: 2,
        ));

        _markers.add(Marker(
          markerId: MarkerId(geofence.id),
          position: LatLng(geofence.latitude, geofence.longitude),
          infoWindow: InfoWindow(title: geofence.name),
        ));
      }
    });
  }

  Future<void> _addGeofence(BuildContext context) async {
    if (_currentPosition == null) {
      _showErrorDialog('Location Error', 'Unable to get current location');
      return;
    }

    final nameController = TextEditingController();
    final radiusController = TextEditingController(text: '100');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Add Geofence'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Geofence Name',
                hintText: 'Enter a name for this geofence',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: radiusController,
              decoration: const InputDecoration(
                labelText: 'Radius (meters)',
                hintText: 'Enter radius in meters',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Please enter a name')),
                );
                return;
              }
              Navigator.pop(dialogContext, {
                'name': nameController.text,
                'radius': double.tryParse(radiusController.text) ?? 100,
              });
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (!_mounted) return;

    if (result != null) {
      try {
        final geofence = Geofence(
          id: 'geofence_${DateTime.now().millisecondsSinceEpoch}',
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          radius: result['radius'],
          name: result['name'],
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection('geofences')
            .doc(geofence.id)
            .set(geofence.toMap());

        if (!_mounted) return;

        _safeSetState(() {
          _geofences.insert(0, geofence);
          _updateMapOverlays();
        });
      } catch (e) {
        if (_mounted) {
          _showErrorDialog('Error', 'Failed to add geofence');
        }
      }
    }
  }

  Future<void> _removeGeofence(Geofence geofence) async {
    try {
      await _firestore.collection('geofences').doc(geofence.id).delete();
      
      if (!_mounted) return;

      _safeSetState(() {
        _geofences.remove(geofence);
        _updateMapOverlays();
      });
    } catch (e) {
      if (_mounted) {
        _showErrorDialog('Error', 'Failed to remove geofence');
      }
    }
  }

  Future<void> _showErrorDialog(String title, String message) async {
    if (!_mounted) return;
    
    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geofencing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SizedBox(
                  height: 300,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _currentPosition != null
                          ? LatLng(_currentPosition!.latitude,
                              _currentPosition!.longitude)
                          : const LatLng(0, 0),
                      zoom: 15,
                    ),
                    circles: _circles,
                    markers: _markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      if (_currentPosition != null) {
                        controller.animateCamera(
                          CameraUpdate.newLatLngZoom(
                            LatLng(_currentPosition!.latitude,
                                _currentPosition!.longitude),
                            15,
                          ),
                        );
                      }
                    },
                  ),
                ),
                Expanded(
                  child: _geofences.isEmpty
                      ? Center(
                          child: Text(
                            'No geofences added yet',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _geofences.length,
                          itemBuilder: (context, index) {
                            final geofence = _geofences[index];
                            return Slidable(
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
                                  child: Icon(Icons.location_on),
                                ),
                                title: Text(geofence.name),
                                subtitle: Text(
                                  'Radius: ${geofence.radius.toStringAsFixed(0)}m',
                                ),
                                onTap: () {
                                  _mapController?.animateCamera(
                                    CameraUpdate.newLatLngZoom(
                                      LatLng(geofence.latitude,
                                          geofence.longitude),
                                      15,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addGeofence(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}