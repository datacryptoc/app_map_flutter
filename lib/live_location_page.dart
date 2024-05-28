import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class LiveLocationPage extends StatefulWidget {
  const LiveLocationPage({super.key});

  @override
  _LiveLocationPageState createState() => _LiveLocationPageState();
}

class _LiveLocationPageState extends State<LiveLocationPage> {
  late GoogleMapController googleMapController;
  Position? position;
  LatLng? currentLocation;
  LatLng? lastFetchedLocation; // Última ubicación desde la cual se hizo la llamada a la API
  bool _isLoading = true;
  String? _expandedImageUrl; // URL de la imagen ampliada
  String? _expandedPlaceName; // Nombre del lugar ampliado
  StreamSubscription<Position>? _positionStream;
  final Set<Marker> _markers = {};
  final List<LatLng> _polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();
  final Set<Polyline> _polylines = {};
  List<String> _placeNames = [];
  List<String> _placeIds = [];
  List<LatLng> _placePositions = []; // Lista para almacenar las posiciones de los lugares de interés
  List<String> _placePhotos = []; // Lista para almacenar las URLs de las fotos de los lugares de interés
  List<int> _placeDistances = []; // Lista para almacenar las distancias a los lugares de interés
  int _apiCallsRemaining = 5; // Contador de llamadas a la API
  String? _selectedPlaceId; // ID del lugar seleccionado
  final String apiKey = 'AIzaSyAg3io83juiYRwTzAukQiq0uXHRKfh8ARs'; // Usa la API key directamente
  String _mapStyle = '';
  static const double fetchThresholdDistance = 200; // Umbral de distancia en metros
  bool _noPlacesFound = false; // Variable para manejar el estado cuando no se encuentran lugares

  // Parámetros de colores
  final Color buttonBackgroundColor = Color.fromARGB(255, 132, 184, 252);
  final Color buttonTextColor = Colors.black;
  final Color refreshButtonColor = Color.fromARGB(255, 25, 89, 173);
  final Color refreshButtonTextColor = Colors.white;
  final Color mapPolylineColor = Color.fromARGB(255, 132, 184, 252);

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
      lastFetchedLocation = currentLocation; // Inicializar la última ubicación de fetch
      _updateMarkers();
      _fetchNearbyPlaces(); // Filtrar lugares cercanos desde el inicio
      _isLoading = false;
    });

    _positionStream = Geolocator.getPositionStream().listen((Position position) {
      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
        _updateMarkers();
        _updateCameraPosition(currentLocation!);
        if (_selectedPlaceId != null) {
          // Si hay un lugar seleccionado, actualizar la ruta en tiempo real
          final selectedPlaceIndex = _placeIds.indexOf(_selectedPlaceId!);
          if (selectedPlaceIndex != -1) {
            _drawRoute(_placePositions[selectedPlaceIndex]);
          }
        }
        _reorderPlacesByCurrentLocation();
      });
    });
  }

  void _updateMarkers() {
    _markers.clear();
    _addSavedMarkers();
  }

  void _addSavedMarkers() {
    for (int i = 0; i < _placeIds.length; i++) {
      _markers.add(Marker(
        markerId: MarkerId(_placeIds[i]),
        position: _placePositions[i], // Usar la posición guardada
        icon: BitmapDescriptor.defaultMarkerWithHue(
            _selectedPlaceId == _placeIds[i] ? BitmapDescriptor.hueBlue : BitmapDescriptor.hueRed),
      ));
    }
  }

  void _fetchNearbyPlaces() async {
    if (currentLocation != null && _apiCallsRemaining > 0) {
      final String url =
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${currentLocation!.latitude},${currentLocation!.longitude}&radius=$fetchThresholdDistance&type=tourist_attraction&key=$apiKey'; // Radio de 200 metros
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        setState(() {
          _placeNames = [];
          _placeIds = [];
          _placePositions = [];
          _placePhotos = [];
          _placeDistances = [];
          _noPlacesFound = results.isEmpty; // Establecer el estado cuando no se encuentran lugares

          for (var place in results.take(5)) {
            final placeId = place['place_id'];
            final name = place['name'];
            final lat = place['geometry']['location']['lat'];
            final lng = place['geometry']['location']['lng'];
            final photoReference = place['photos'] != null && place['photos'].isNotEmpty
                ? place['photos'][0]['photo_reference']
                : null;

            int distance = _distanceBetween(currentLocation!, LatLng(lat, lng)).round();

            _placeNames.add(name);
            _placeIds.add(placeId);
            _placePositions.add(LatLng(lat, lng));
            _placeDistances.add(distance);

            if (photoReference != null) {
              final photoUrl = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=$photoReference&key=$apiKey';
              _placePhotos.add(photoUrl);
            } else {
              _placePhotos.add(''); // Añadir cadena vacía si no hay foto disponible
            }
          }

          // Ordenar los lugares por distancia
          _sortPlacesByDistance();

          if (_apiCallsRemaining > 0) {
            _apiCallsRemaining--; // Decrementar el contador de llamadas a la API
          }
        });
      } else {
        throw Exception('Failed to load nearby places');
      }
    }
  }

  void _sortPlacesByDistance() {
    List<int> indices = List.generate(_placeDistances.length, (i) => i);
    indices.sort((a, b) => _placeDistances[a].compareTo(_placeDistances[b]));

    _placeNames = [for (var i in indices) _placeNames[i]];
    _placeIds = [for (var i in indices) _placeIds[i]];
    _placePositions = [for (var i in indices) _placePositions[i]];
    _placePhotos = [for (var i in indices) _placePhotos[i]];
    _placeDistances = [for (var i in indices) _placeDistances[i]];
  }

  void _reorderPlacesByCurrentLocation() {
    setState(() {
      for (int i = 0; i < _placePositions.length; i++) {
        _placeDistances[i] = _distanceBetween(currentLocation!, _placePositions[i]).round();
      }
      _sortPlacesByDistance();
    });
  }

  void _selectPlace(String placeId, LatLng destination) {
    setState(() {
      _selectedPlaceId = placeId;
      _updateMarkers();
    });
    _drawRoute(destination);
  }

  Future<void> _drawRoute(LatLng destination) async {
    _polylineCoordinates.clear();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      apiKey,
      PointLatLng(currentLocation!.latitude, currentLocation!.longitude),
      PointLatLng(destination.latitude, destination.longitude),
      travelMode: TravelMode.walking,
    );

    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        _polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });

      setState(() {
        _polylines.add(Polyline(
          polylineId: PolylineId('route'),
          color: mapPolylineColor,
          width: 5,
          points: _polylineCoordinates,
        ));
        // Actualizar la distancia al destino
        _updateDistances();
      });
    }
  }

  void _clearRoute() {
    setState(() {
      _polylines.clear();
      _selectedPlaceId = null;
      _updateMarkers();
    });
  }

  double _distanceBetween(LatLng start, LatLng end) {
    return Geolocator.distanceBetween(start.latitude, start.longitude, end.latitude, end.longitude);
  }

  void _updateDistances() {
    if (_selectedPlaceId != null) {
      final selectedPlaceIndex = _placeIds.indexOf(_selectedPlaceId!);
      if (selectedPlaceIndex != -1) {
        int distance = _distanceBetween(currentLocation!, _placePositions[selectedPlaceIndex]).round();
        setState(() {
          _placeDistances[selectedPlaceIndex] = distance;
          if (_expandedPlaceName != null) {
            _expandedPlaceName =
                '${_placeNames[selectedPlaceIndex]} (${distance} m)';
          }
        });
      }
    }
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

  void _refreshPlaces() {
    Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).then((Position position) {
      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
        if (lastFetchedLocation == null || _distanceBetween(currentLocation!, lastFetchedLocation!) > fetchThresholdDistance) {
          lastFetchedLocation = currentLocation;
          _fetchNearbyPlaces();
        } else {
          _reorderPlacesByCurrentLocation();
        }
      });
    });
  }

  void _expandImage(String imageUrl, String placeName) {
    setState(() {
      final index = _placeNames.indexOf(placeName);
      final distance = _placeDistances[index];
      _expandedImageUrl = imageUrl;
      _expandedPlaceName = '$placeName (${distance} m)';
    });
  }

  void _closeImage() {
    setState(() {
      _expandedImageUrl = null;
      _expandedPlaceName = null;
      _clearRoute();
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
        title: const Text("Near Places"),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                'Refresh: $_apiCallsRemaining',
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
                    zoomControlsEnabled: true,
                    onMapCreated: _onMapCreated,
                    mapType: MapType.normal,
                    buildingsEnabled: false,
                    trafficEnabled: false,
                    compassEnabled: true, // Habilitar brújula para mostrar el campo visual
                    scrollGesturesEnabled: false, // Desactivar la capacidad de mover el mapa
                    tiltGesturesEnabled: false, // Desactivar la capacidad de inclinar el mapa
                    rotateGesturesEnabled: false, // Desactivar la capacidad de rotar el mapa
                    zoomGesturesEnabled: false, // Desactivar la capacidad de hacer zoom manualmente
                    polylines: _polylines, // Añadir las polilíneas al mapa
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
                                  final placeNameWithDistance = '${_placeNames[index]} (${_placeDistances[index]} m)';
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: buttonBackgroundColor, // Fondo del botón
                                        foregroundColor: buttonTextColor, // Texto negro
                                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0), // Añadir padding horizontal
                                      ),
                                      onPressed: () {
                                        _expandImage(_placePhotos[index], _placeNames[index]);
                                        _selectPlace(_placeIds[index], _placePositions[index]);
                                      },
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              placeNameWithDistance,
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
                          backgroundColor: refreshButtonColor, // Color del botón de refrescar lugares
                          foregroundColor: refreshButtonTextColor, // Color del texto del botón de refrescar lugares
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('REFRESCAR LUGARES DE INTERÉS'),
                            SizedBox(width: 10),
                            Text(
                              '(${_apiCallsRemaining.toString()})',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
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
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: Colors.black54,
                          padding: const EdgeInsets.all(1.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _expandedPlaceName ?? '',
                                  style: TextStyle(fontSize: 15, color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                onPressed: _closeImage,
                              ),
                            ],
                          ),
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
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
