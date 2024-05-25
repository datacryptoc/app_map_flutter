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
  bool _isLoading = true;
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
  bool _noPlacesFound = false; // Variable para manejar el estado cuando no se encuentran lugares

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    _initLocationTracking();
  }

  Future<void> _loadMapStyle() async {
    _mapStyle = await rootBundle.loadString('assets/map_style.json');
  }

  void _initLocationTracking() async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      currentLocation = LatLng(position.latitude, position.longitude);
      _updateMarkers();
      _fetchNearbyPlaces(); // Filtrar lugares cercanos desde el inicio
      _isLoading = false;
    });

    _positionStream = Geolocator.getPositionStream().listen((Position position) {
      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
        _updateMarkers();
        _updateCameraPosition(currentLocation!);
      });
    });
  }

  void _updateMarkers() {
    _markers.clear();
    // No añadir marcador para la ubicación actual, solo se mostrará el campo visual
    _addSavedMarkers();
  }

  void _addSavedMarkers() {
    for (int i = 0; i < _placeIds.length; i++) {
      _markers.add(Marker(
        markerId: MarkerId(_placeIds[i]),
        position: _placePositions[i], // Usar la posición guardada
        infoWindow: InfoWindow(
          title: _placeNames[i],
          snippet: 'Lugar de interés',
        ),
        icon: BitmapDescriptor.defaultMarker,
      ));
    }
  }

  void _fetchNearbyPlaces() async {
    if (currentLocation != null && _apiCallsRemaining > 0) {
      final String url =
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${currentLocation!.latitude},${currentLocation!.longitude}&radius=200&type=tourist_attraction&key=$apiKey'; // Radio de 300 metros
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        setState(() {
          _placeNames = [];
          _placeIds = [];
          _placePositions = [];
          _placePhotos = [];
          _noPlacesFound = results.isEmpty; // Establecer el estado cuando no se encuentran lugares

          for (var place in results.take(5)) {
            final placeId = place['place_id'];
            final name = place['name'];
            final lat = place['geometry']['location']['lat'];
            final lng = place['geometry']['location']['lng'];
            final photoReference = place['photos'] != null && place['photos'].isNotEmpty
                ? place['photos'][0]['photo_reference']
                : null;

            _placeNames.add(name);
            _placeIds.add(placeId);
            _placePositions.add(LatLng(lat, lng));

            if (photoReference != null) {
              final photoUrl = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=$photoReference&key=$apiKey';
              _placePhotos.add(photoUrl);
            } else {
              _placePhotos.add(''); // Añadir cadena vacía si no hay foto disponible
            }

            _markers.add(Marker(
              markerId: MarkerId(placeId),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: name,
                snippet: 'Lugar de interés',
              ),
              icon: BitmapDescriptor.defaultMarker,
            ));
          }
          if (_apiCallsRemaining > 0) {
            _apiCallsRemaining--; // Decrementar el contador de llamadas a la API
          }
        });
      } else {
        throw Exception('Failed to load nearby places');
      }
    }
  }

  double _distanceBetween(LatLng start, LatLng end) {
    return Geolocator.distanceBetween(start.latitude, start.longitude, end.latitude, end.longitude);
  }

  void _updateCameraPosition(LatLng location) async {
    googleMapController.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: location,
        zoom: 17, // Aumentar el nivel de zoom
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

  void _refreshPlaces() {
    Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).then((Position position) {
      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
        _fetchNearbyPlaces();
      });
    });
  }

  void _expandImage(String imageUrl) {
    setState(() {
      _expandedImageUrl = imageUrl;
    });
  }

  void _closeImage() {
    setState(() {
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
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: currentLocation ?? const LatLng(0, 0),
                      zoom: 17, // Aumentar el nivel de zoom
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
                    compassEnabled: true, // Habilitar brújula para mostrar el campo visual
                    scrollGesturesEnabled: false, // Desactivar la capacidad de mover el mapa
                    tiltGesturesEnabled: false, // Desactivar la capacidad de inclinar el mapa
                    rotateGesturesEnabled: false, // Desactivar la capacidad de rotar el mapa
                    zoomGesturesEnabled: false, // Desactivar la capacidad de hacer zoom manualmente
                  ),
          ),
          Container(
            color: Colors.white,
            height: MediaQuery.of(context).size.height * 0.3,
            child: _expandedImageUrl == null
                ? Column(
                    children: [
                      Expanded(
                        child: _noPlacesFound
                            ? Center(
                                child: Text(
                                  'No se han encontrado lugares de interés cerca de ti.',
                                  style: TextStyle(fontSize: 16, color: Colors.black),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _placeNames.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color.fromARGB(255, 109, 172, 255), // Fondo del botón
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
                                          Expanded(
                                            child: Text(
                                              _placeNames[index],
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          if (_placePhotos[index].isNotEmpty)
                                            Image.network(
                                              _placePhotos[index],
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  width: 50,
                                                  height: 50,
                                                  color: Colors.grey, // Color de fondo si no se puede cargar la imagen
                                                );
                                              },
                                            ),
                                          if (_placePhotos[index].isEmpty)
                                            Container(
                                              width: 50,
                                              height: 50,
                                              color: Colors.grey, // Color de fondo si no hay imagen disponible
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      ElevatedButton(
                        onPressed: _refreshPlaces,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue, // Color del botón de refrescar lugares
                          foregroundColor: Colors.white, // Color del texto del botón de refrescar lugares
                        ),
                        child: const Text('REFRESCAR LUGARES DE INTERÉS'),
                      ),
                    ],
                  )
                : Stack(
                    children: [
                      Center(
                        child: Image.network(
                          _expandedImageUrl!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: double.infinity,
                              height: double.infinity,
                              color: Colors.grey, // Color de fondo si no se puede cargar la imagen
                            );
                          },
                        ),
                      ),
                      Center(
                        child: IconButton(
                          icon: const Icon(Icons.play_arrow, color: Colors.white, size: 50),
                          onPressed: () {
                            // Aquí puedes agregar la lógica para reproducir audio
                          },
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.black, size: 30),
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
