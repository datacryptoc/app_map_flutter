import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;

class LiveLocationPage extends StatefulWidget {
  const LiveLocationPage({super.key});

  @override
  _LiveLocationPageState createState() => _LiveLocationPageState();
}

class _LiveLocationPageState extends State<LiveLocationPage> {
  late GoogleMapController googleMapController;
  Position? position;
  LatLng? currentLocation;
  LatLng? lastFetchedLocation;
  bool _isLoading = true;
  bool _showPlaces = false; // Variable para controlar la visibilidad de lugares de interés
  bool _isImageExpanded = false; // Variable para controlar si la imagen está ampliada
  String? _expandedImageUrl; // URL de la imagen ampliada
  StreamSubscription<Position>? _positionStream;
  final Set<Marker> _markers = {};
  List<String> _placeNames = [];
  List<String> _placeIds = [];
  List<LatLng> _placePositions = []; // Lista para almacenar las posiciones de los lugares de interés
  List<String> _placePhotos = []; // Lista para almacenar las URLs de las fotos de los lugares de interés
  int _apiCallsRemaining = 5; // Contador de llamadas a la API
  String? _selectedPlaceId; // ID del lugar seleccionado
  final String apiKey = 'AIzaSyAg3io83juiYRwTzAukQiq0uXHRKfh8ARs'; // Usa la API key directamente
  String _mapStyle = '';
  static const double fetchThresholdDistance = 100; // Umbral de distancia en metros

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
    if (_showPlaces) {
      if (lastFetchedLocation == null || _distanceBetween(currentLocation!, lastFetchedLocation!) > fetchThresholdDistance) {
        _fetchNearbyPlaces();
      } else {
        _addSavedMarkers();
      }
    }
  }

  void _addSavedMarkers() {
    for (int i = 0; i < _placeIds.length; i++) {
      _markers.add(Marker(
        markerId: MarkerId(_placeIds[i]),
        position: _placePositions[i], // Usar la posición guardada
        infoWindow: InfoWindow(
          title: _placeNames[i],
          onTap: () {
            _onMarkerTapped(_placeIds[i]);
          },
        ),
        icon: BitmapDescriptor.defaultMarker,
      ));
    }
  }

  double _distanceBetween(LatLng start, LatLng end) {
    return Geolocator.distanceBetween(start.latitude, start.longitude, end.latitude, end.longitude);
  }

  Future<void> _fetchNearbyPlaces() async {
    if (currentLocation != null && _apiCallsRemaining > 0) {
      final String url =
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${currentLocation!.latitude},${currentLocation!.longitude}&radius=300&type=tourist_attraction&key=$apiKey'; // Radio de 300 metros
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        setState(() {
          _placeNames = [];  // Limpiar la lista de nombres de lugares
          _placeIds = [];    // Limpiar la lista de IDs de lugares
          _placePositions = []; // Limpiar la lista de posiciones de lugares
          _placePhotos = []; // Limpiar la lista de URLs de fotos
          for (var place in results.take(5)) {
            final placeId = place['place_id'];
            final name = place['name'];
            final lat = place['geometry']['location']['lat'];
            final lng = place['geometry']['location']['lng'];
            final photoReference = place['photos'] != null && place['photos'].isNotEmpty
                ? place['photos'][0]['photo_reference']
                : null;

            _placeNames.add(name);  // Añadir el nombre del lugar a la lista
            _placeIds.add(placeId);  // Añadir el ID del lugar a la lista
            _placePositions.add(LatLng(lat, lng)); // Añadir la posición del lugar a la lista

            if (photoReference != null) {
              final photoUrl = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=$photoReference&key=$apiKey';
              _placePhotos.add(photoUrl); // Añadir la URL de la foto a la lista
            } else {
              _placePhotos.add(''); // Añadir una cadena vacía si no hay foto disponible
            }

            _markers.add(Marker(
              markerId: MarkerId(placeId),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: name,
                onTap: () {
                  _onMarkerTapped(placeId);
                },
              ),
              icon: BitmapDescriptor.defaultMarker,
            ));
          }
          lastFetchedLocation = currentLocation;
          _apiCallsRemaining--; // Decrementar el contador de llamadas a la API
        });
      } else {
        throw Exception('Failed to load nearby places');
      }
    }
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

  void _showMarkerInfoWindow(String markerId) {
    googleMapController.showMarkerInfoWindow(MarkerId(markerId));
    setState(() {
      _selectedPlaceId = markerId;
    });
  }

  void _onMarkerTapped(String markerId) {
    setState(() {
      _selectedPlaceId = markerId;
    });
  }

  void _toggleShowPlaces() {
    setState(() {
      _showPlaces = !_showPlaces;
      _selectedPlaceId = null;
      _isImageExpanded = false;
      _expandedImageUrl = null;
      if (_showPlaces) {
        if (lastFetchedLocation == null || _distanceBetween(currentLocation!, lastFetchedLocation!) > fetchThresholdDistance) {
          _fetchNearbyPlaces();
        } else {
          _addSavedMarkers();
        }
      } else {
        _updateMarkers();
      }
    });
  }

  void _expandImage(String imageUrl) {
    setState(() {
      _isImageExpanded = true;
      _expandedImageUrl = imageUrl;
    });
  }

  void _closeImage() {
    setState(() {
      _isImageExpanded = false;
      _expandedImageUrl = null;
    });
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
        title: const Text("Live Map"),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                'Llamadas restantes: $_apiCallsRemaining',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
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
          if (_showPlaces)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.white,
                height: MediaQuery.of(context).size.height * 0.3,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: _placeNames.length,
                        itemBuilder: (context, index) {
                          final isSelected = _placeIds[index] == _selectedPlaceId;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSelected
                                    ? const Color.fromARGB(255, 34, 130, 255)
                                    : const Color.fromARGB(255, 109, 172, 255), // Fondo más oscuro si está seleccionado
                                foregroundColor: Colors.black, // Texto negro
                                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0), // Añadir padding horizontal
                              ),
                              onPressed: () {
                                _showMarkerInfoWindow(_placeIds[index]);
                                _expandImage(_placePhotos[index]);
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_placeNames[index]),
                                  if (_placePhotos[index].isNotEmpty)
                                    const SizedBox(
                                      width: 10, // Añadir espacio entre el texto y la imagen
                                    ),
                                  if (_placePhotos[index].isNotEmpty)
                                    Image.network(
                                      _placePhotos[index],
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _toggleShowPlaces,
                      child: const Text('OCULTAR LUGARES DE INTERÉS'),
                    ),
                  ],
                ),
              ),
            ),
          if (!_showPlaces)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: _toggleShowPlaces,
                child: const Text('MOSTRAR LUGARES DE INTERÉS'),
              ),
            ),
          if (_isImageExpanded)
            Center(
              child: Stack(
                children: [
                  Center(
                    child: Image.network(
                      _expandedImageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 30),
                      onPressed: _closeImage,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}