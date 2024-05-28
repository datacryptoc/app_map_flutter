import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'live_location_page.dart'; // Importa el nuevo archivo

class InitMapMenu extends StatefulWidget {
  const InitMapMenu({super.key});

  @override
  _InitMapMenuState createState() => _InitMapMenuState();
}

class _InitMapMenuState extends State<InitMapMenu> {
  late GoogleMapController googleMapController;
  Position? position;
  LatLng? currentLocation;
  bool _isLoading = true;
  StreamSubscription<Position>? _positionStream;
  final Set<Marker> _markers = {};
  String _mapStyle = '';

  // Parametros de colores
  final Color iconColor = Color.fromARGB(255, 132, 184, 252);
  final Color textColor = Colors.black;
  final Color backgroundColor = Color.fromARGB(255, 132, 184, 252);

  @override
  void initState() {
    super.initState();
    _initLocationTracking();
    _loadMapStyle();
  }

  Future<void> _loadMapStyle() async {
    _mapStyle = await rootBundle.loadString('assets/map_style.json');
  }

  void _initLocationTracking() {
    _positionStream = Geolocator.getPositionStream().listen((Position position) {
      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
        _updateMarkers();
        if (!_isLoading) {
          _updateCameraPosition(currentLocation!);
        }
        _isLoading = false;
      });
    });
  }

  void _updateMarkers() {
    _markers.clear();
    _markers.add(Marker(
      markerId: const MarkerId("current_location"),
      position: currentLocation!,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    ));
  }

  void _updateCameraPosition(LatLng location) async {
    googleMapController.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: location,
        zoom: 16,
      ),
    ));
  }

  void _onMapCreated(GoogleMapController controller) {
    googleMapController = controller;
    googleMapController.setMapStyle(_mapStyle); // Aplica el estilo del mapa
    if (currentLocation != null) {
      _updateCameraPosition(currentLocation!);
    }
  }

  @override
  void dispose() {
    if (_positionStream != null) {
      _positionStream!.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Main GPS"),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: currentLocation ?? const LatLng(0, 0),
                    zoom: 16,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                  onMapCreated: _onMapCreated,
                  mapType: MapType.normal,
                  buildingsEnabled: false,
                  trafficEnabled: false,
                ),
          Positioned(
            left: 20,
            top: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFloatingActionButton(
                  icon: Icons.shuffle,
                  label: "Near Places",
                  onPressed: () {
                    // Navegar a LiveLocationPage
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LiveLocationPage()),
                    );
                  },
                ),
                SizedBox(height: 20),
                _buildFloatingActionButton(
                  icon: Icons.smart_toy,
                  label: "IA Tours",
                  onPressed: () {
                    // Acción del segundo botón
                  },
                ),
                SizedBox(height: 20),
                _buildFloatingActionButton(
                  icon: Icons.person,
                  label: "Human Tours",
                  onPressed: () {
                    // Acción del tercer botón
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          FloatingActionButton(
            onPressed: onPressed,
            backgroundColor: iconColor,
            child: Icon(icon),
          ),
          SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
