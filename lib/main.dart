import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asset Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const MapPage(),
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final TextEditingController _search = TextEditingController();

  // Start in San Francisco
  static const LatLng _start = LatLng(37.7749, -122.4194);
  double _zoom = 13;
  bool _satellite = false;

  final List<Marker> _markers = [
    const Marker(
      point: _start,
      width: 80,
      height: 80,
      child: Icon(Icons.location_pin, size: 40, color: Colors.red),
    ),
  ];

  Future<void> _goToQuery() async {
    final query = _search.text.trim();
    if (query.isEmpty) return;

    try {
      // Nominatim (OpenStreetMap) free geocoding
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {'q': query, 'format': 'json', 'limit': '1'},
      );

      final resp = await http.get(
        uri,
        headers: {
          // etiquette: identify your app
          'User-Agent': 'Asset Management'
        },
      );

      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body) as List;
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final dest = LatLng(lat, lon);

          setState(() {
            _zoom = 14;
            _markers.add(
              Marker(
                point: dest,
                width: 70,
                height: 70,
                child: const Icon(Icons.place, size: 36, color: Colors.purple),
              ),
            );
          });

          _mapController.move(dest, _zoom);
        } else {
          _snack('No results for "$query"');
        }
      } else {
        _snack('Search failed (${resp.statusCode})');
      }
    } catch (e) {
      _snack('Search error: $e');
    }
  }

  void _zoomIn() {
    setState(() => _zoom = (_zoom + 1).clamp(1, 19));
    _mapController.move(_mapController.camera.center, _zoom);
  }

  void _zoomOut() {
    setState(() => _zoom = (_zoom - 1).clamp(1, 19));
    _mapController.move(_mapController.camera.center, _zoom);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset Management'),
        actions: [
          // Satellite toggle
          Row(
            children: [
              const Text('Satellite', style: TextStyle(fontSize: 14)),
              Switch(
                value: _satellite,
                onChanged: (v) => setState(() => _satellite = v),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search bar row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: 'Search a place (e.g., Times Square)',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _goToQuery(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _goToQuery,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Go'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Map in a container
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(blurRadius: 12, offset: Offset(0, 4), color: Colors.black12),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _start,
                        initialZoom: _zoom,
                        onMapEvent: (evt) {
                          // keep local zoom in sync if the user scroll-zooms
                          if (evt is MapEventMoveEnd) {
                            setState(() => _zoom = _mapController.camera.zoom);
                          }
                        },
                      ),
                      children: [
                        // Base or satellite layer
                        _satellite
                            ? TileLayer(
                                // Esri World Imagery satellite
                                urlTemplate:
                                    'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                                tileProvider: CancellableNetworkTileProvider(),
                                userAgentPackageName: 'com.example.flutter_app',
                              )
                            : TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                tileProvider: CancellableNetworkTileProvider(),
                                userAgentPackageName: 'com.example.flutter_app',
                              ),
                        MarkerLayer(markers: _markers),
                        RichAttributionWidget(
                          attributions: [
                            TextSourceAttribution(
                              _satellite
                                  ? '© Esri World Imagery'
                                  : '© OpenStreetMap contributors',
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Zoom controls (top-right)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Column(
                        children: [
                          FloatingActionButton.small(
                            heroTag: 'zin',
                            onPressed: _zoomIn,
                            child: const Icon(Icons.add),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton.small(
                            heroTag: 'zout',
                            onPressed: _zoomOut,
                            child: const Icon(Icons.remove),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
