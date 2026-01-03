import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

class LocationDetailScreen extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final Function(double lat, double lng, String? name)? onLocationUpdated;

  const LocationDetailScreen({
    super.key,
    this.latitude,
    this.longitude,
    this.locationName,
    this.onLocationUpdated,
  });

  @override
  State<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<LocationDetailScreen> {
  final LocationService _locationService = LocationService();
  final TextEditingController _nameController = TextEditingController();

  GoogleMapController? _mapController;
  double? _currentLat;
  double? _currentLng;
  String? _currentName;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentLat = widget.latitude;
    _currentLng = widget.longitude;
    _currentName = widget.locationName;
    _nameController.text = _currentName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _updateLocation() async {
    setState(() => _isLoading = true);

    try {
      final Position? position = await _locationService.getCurrentLocation();

      if (position != null) {
        setState(() {
          _currentLat = position.latitude;
          _currentLng = position.longitude;
          _isLoading = false;
        });

        // Move camera to new position
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(position.latitude, position.longitude),
          ),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location updated!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not get location'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _saveLocation() {
    if (_currentLat != null && _currentLng != null) {
      final name = _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim();

      widget.onLocationUpdated?.call(_currentLat!, _currentLng!, name);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = _currentLat != null && _currentLng != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Details'),
        actions: [
          if (hasLocation)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveLocation,
            ),
        ],
      ),
      body: hasLocation
          ? Column(
        children: [
          // Google Map
          Expanded(
            flex: 2,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(_currentLat!, _currentLng!),
                zoom: 15,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('current_location'),
                  position: LatLng(_currentLat!, _currentLng!),
                  infoWindow: InfoWindow(
                    title: _currentName ?? 'Expense Location',
                    snippet: '${_currentLat!.toStringAsFixed(6)}, ${_currentLng!.toStringAsFixed(6)}',
                  ),
                ),
              },
              onMapCreated: (controller) {
                _mapController = controller;
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
            ),
          ),

          // Location Info Card
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Coordinates
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.location_on, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Coordinates',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Lat: ${_currentLat!.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            'Lng: ${_currentLng!.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Location Name
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Location Name (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.edit_location),
                      hintText: 'e.g., Office, Home, Restaurant',
                    ),
                    maxLength: 50,
                  ),
                  const SizedBox(height: 12),

                  // Update Location Button
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _updateLocation,
                    icon: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.my_location),
                    label: const Text('Update Location'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Save Button
                  FilledButton.icon(
                    onPressed: _saveLocation,
                    icon: const Icon(Icons.check),
                    label: const Text('Save'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      )
          : Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_off,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'No location set',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Get your current location to continue',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _updateLocation,
                icon: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.my_location),
                label: const Text('Get Location'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}