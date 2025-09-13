// lib/main.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

// Must include r, c, w, l (read/create/write/list)
const String azureContainerSasUrl =
    'https://pavementimg.blob.core.windows.net/images?sp=rcwl&st=2025-09-13T19:35:41Z&se=2026-01-02T04:50:41Z&spr=https&sv=2024-11-04&sr=c&sig=lfDLEPjcAMkeyqiT187TcY8GBJGxTxE8ZDe0k39RdoE%3D';

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

class PhotoPoint {
  final LatLng ll;
  final String name; // blob name
  final String url;  // blob url with SAS
  PhotoPoint({required this.ll, required this.name, required this.url});
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final TextEditingController _search = TextEditingController();

  static const LatLng _start = LatLng(37.7749, -122.4194);
  double _zoom = 13;
  bool _satellite = false;

  // Existing markers (search pins, etc.)
  final List<Marker> _markers = [
    const Marker(
      point: _start,
      width: 80,
      height: 80,
      child: Icon(Icons.location_pin, size: 40, color: Colors.red),
    ),
  ];

  // Photo dots loaded from container
  final List<PhotoPoint> _photoPoints = [];
  bool _loadingDots = false;

  // Capture/upload state
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;
  String? _lastStatus;

  @override
  void initState() {
    super.initState();
    _loadExistingPhotoDots();
  }

  // ---------- Search ----------
  Future<void> _goToQuery() async {
    final query = _search.text.trim();
    if (query.isEmpty) return;

    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {'q': query, 'format': 'json', 'limit': '1'},
      );

      final resp = await http.get(uri, headers: {'User-Agent': 'Asset Management'});
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

  // ---------- Azure helpers ----------
  String _buildBlobUrl(String containerSasUrl, String blobName) {
    final uri = Uri.parse(containerSasUrl); // .../images?sv=...
    return '${uri.scheme}://${uri.host}${uri.path}/$blobName?${uri.query}';
  }

  Uri _containerListUri() {
    final base = Uri.parse(azureContainerSasUrl);
    final qp = Map<String, String>.from(base.queryParameters);
    qp['restype'] = 'container';
    qp['comp'] = 'list';
    qp['maxresults'] = '5000';
    return base.replace(queryParameters: qp);
  }

  Future<void> _putBlockBlob(
    String sasBlobUrl,
    List<int> data, {
    String contentType = 'application/octet-stream',
  }) async {
    final uri = Uri.parse(sasBlobUrl);
    final resp = await http.put(
      uri,
      headers: {
        'x-ms-blob-type': 'BlockBlob',
        'Content-Type': contentType,
      },
      body: data,
    );
    if (resp.statusCode != 201 && resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
  }

  // ---------- Location ----------
  Future<Position> _getPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception('Location services are disabled.');
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw Exception('Location permission not granted.');
    }
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
  }

  String _extFor(String path) => path.toLowerCase().endsWith('.png') ? '.png' : '.jpg';
  String _contentTypeFor(String name) =>
      name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

  // ---------- Load all existing images as dot markers ----------
  Future<void> _loadExistingPhotoDots() async {
    if (_loadingDots) return;
    setState(() => _loadingDots = true);

    try {
      final listUri = _containerListUri();
      final resp = await http.get(listUri);
      if (resp.statusCode != 200) {
        throw Exception('List failed (${resp.statusCode}). Ensure SAS has "l".');
      }

      final body = resp.body;
      final regex = RegExp(r'<Name>([^<]+)</Name>');
      final names = regex.allMatches(body).map((m) => m.group(1)!).toList();

      final pts = <PhotoPoint>[];
      for (final name in names) {
        final base = name.split('/').last;
        final dot = base.lastIndexOf('.');
        if (dot <= 0) continue;
        final stem = base.substring(0, dot);
        final parts = stem.split('_');
        if (parts.length != 2) continue;

        final lat = double.tryParse(parts[0]);
        final lon = double.tryParse(parts[1]);
        if (lat == null || lon == null) continue;

        final url = _buildBlobUrl(azureContainerSasUrl, name);
        pts.add(PhotoPoint(ll: LatLng(lat, lon), name: name, url: url));
      }

      setState(() {
        _photoPoints
          ..clear()
          ..addAll(pts);
        _loadingDots = false;
      });
    } catch (e) {
      setState(() => _loadingDots = false);
      _snack('Could not load photo dots: $e');
    }
  }

  // ---------- Capture → GPS → Upload ----------
  Future<void> _captureAndUpload() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _lastStatus = null;
    });

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (photo == null) {
        setState(() {
          _busy = false;
          _lastStatus = 'Cancelled';
        });
        return;
      }

      final pos = await _getPosition();
      final lat = pos.latitude.toStringAsFixed(6);
      final lon = pos.longitude.toStringAsFixed(6);
      final blobName = '${lat}_${lon}${_extFor(photo.path)}';

      final bytes = await photo.readAsBytes();
      final uploadUrl = _buildBlobUrl(azureContainerSasUrl, blobName);
      await _putBlockBlob(uploadUrl, bytes, contentType: _contentTypeFor(blobName));

      final p = PhotoPoint(
        ll: LatLng(pos.latitude, pos.longitude),
        name: blobName,
        url: _buildBlobUrl(azureContainerSasUrl, blobName),
      );

      setState(() {
        _photoPoints.add(p);
        _busy = false;
        _lastStatus = 'Uploaded: $blobName';
      });
      _mapController.move(p.ll, 16);
      _snack('Uploaded: $blobName');
    } catch (e) {
      setState(() {
        _busy = false;
        _lastStatus = 'Error: $e';
      });
      _snack('Upload failed: $e');
    }
  }

  // ---------- Dot marker + photo viewer ----------
  Marker _dotMarker(PhotoPoint p) {
    const double size = 14;
    return Marker(
      point: p.ll,
      width: size + 6,
      height: size + 6,
      child: GestureDetector(
        onTap: () => _showPhoto(p),
        child: Container(
          alignment: Alignment.center,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPhoto(PhotoPoint p) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Photo @ ${p.ll.latitude.toStringAsFixed(6)}, ${p.ll.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Image.network(
                      p.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Center(child: Text('Could not load image')),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(p.name, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final photoDotMarkers = _photoPoints.map(_dotMarker).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset Management'),
        actions: [
          Row(
            children: [
              const Text('Satellite', style: TextStyle(fontSize: 14)),
              Switch(value: _satellite, onChanged: (v) => setState(() => _satellite = v)),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: 'Search a place (e.g., Times Square)',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(blurRadius: 12, offset: Offset(0, 4), color: Colors.black12)],
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
                          if (evt is MapEventMoveEnd) {
                            setState(() => _zoom = _mapController.camera.zoom);
                          }
                        },
                      ),
                      children: [
                        _satellite
                            ? TileLayer(
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
                        // Photo dots layer
                        MarkerLayer(markers: photoDotMarkers),
                        // Other markers (search pins, etc.)
                        MarkerLayer(markers: _markers),
                        RichAttributionWidget(
                          attributions: [
                            TextSourceAttribution(
                              _satellite ? '© Esri World Imagery' : '© OpenStreetMap contributors',
                            ),
                          ],
                        ),
                      ],
                    ),
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
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: FloatingActionButton.extended(
                        heroTag: 'capture_upload',
                        onPressed: _busy ? null : _captureAndUpload,
                        icon: _busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.cloud_upload),
                        label: Text(_busy ? 'Uploading...' : 'Capture & Upload'),
                      ),
                    ),
                    if (_loadingDots)
                      const Positioned(
                        left: 12,
                        bottom: 12,
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(width: 8),
                                Text('Loading photo dots...'),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_lastStatus != null) ...[
              const SizedBox(height: 8),
              Text(_lastStatus!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }
}
