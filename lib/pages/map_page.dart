// lib/pages/map_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../constants.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _map = MapController();

  // Default center (Glassboro area)
  static const LatLng _start = LatLng(39.7014, -75.1063);
  double _zoom = 13;

  // Keep blob name + coordinate so we can open the image later.
  final List<_PhotoDot> _photoPoints = <_PhotoDot>[];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDots();
  }

  // Build container list URL (Azure Blob List API + SAS already in constants).
  Uri _containerListUri() {
    final base = Uri.parse(azureContainerSasUrl);
    final qp = Map<String, String>.from(base.queryParameters);
    qp['restype'] = 'container';
    qp['comp'] = 'list';
    qp['maxresults'] = '5000';
    return base.replace(queryParameters: qp);
  }

  // Compose a direct blob URL (same SAS) for an individual blob.
  Uri _blobUrl(String blobName) {
    final base = Uri.parse(azureContainerSasUrl);
    final segments = <String>[...base.pathSegments, blobName];
    return base.replace(pathSegments: segments);
  }

  Future<void> _loadDots() async {
    setState(() => _loading = true);
    try {
      final resp = await http.get(_containerListUri());
      if (resp.statusCode != 200) {
        throw Exception('List failed (${resp.statusCode}).');
      }
      final body = resp.body;

      // Extract <Name> entries from the XML response.
      final regex = RegExp(r'<Name>([^<]+)</Name>');
      final names = regex.allMatches(body).map((m) => m.group(1)!).toList();

      final pts = <_PhotoDot>[];
      for (final name in names) {
        // Expecting file names like "<lat>_<lon>.jpg" (optionally under a folder)
        final base = name.split('/').last;
        final dot = base.lastIndexOf('.');
        if (dot <= 0) continue;
        final stem = base.substring(0, dot);
        final parts = stem.split('_');
        if (parts.length != 2) continue;

        final lat = double.tryParse(parts[0]);
        final lon = double.tryParse(parts[1]);
        if (lat == null || lon == null) continue;

        pts.add(_PhotoDot(name: name, pos: LatLng(lat, lon)));
      }

      setState(() {
        _photoPoints
          ..clear()
          ..addAll(pts);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load dots: $e')),
        );
      }
    }
  }

  Marker _dot(_PhotoDot p) {
    const double size = 14;
    return Marker(
      point: p.pos,
      width: size + 10,
      height: size + 10,
      child: InkWell(
        customBorder: const CircleBorder(),
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

  Future<void> _showPhoto(_PhotoDot p) async {
    final url = _blobUrl(p.name).toString();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Photo @ ${p.pos.latitude.toStringAsFixed(6)}, '
                '${p.pos.longitude.toStringAsFixed(6)}',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, st) => Container(
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Preview not available'),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _FullImagePage(url: url),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open full image'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = _photoPoints.map(_dot).toList();

    return Scaffold(
     // appBar: AppBar(title: const Text('Map Viewer')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _start,
              initialZoom: _zoom,
              onMapEvent: (evt) {
                if (evt is MapEventMoveEnd) {
                  setState(() => _zoom = _map.camera.zoom);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                tileProvider: CancellableNetworkTileProvider(),
                userAgentPackageName: 'com.example.flutter_app',
              ),
              MarkerLayer(markers: markers),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          if (_loading)
            const Positioned(
              left: 12,
              bottom: 12,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Loading photo dots...'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Simple model for a photo marker
class _PhotoDot {
  _PhotoDot({required this.name, required this.pos});
  final String name; // full blob path (may include folder)
  final LatLng pos;
}

// Fullscreen image viewer (pinch-to-zoom)
class _FullImagePage extends StatelessWidget {
  const _FullImagePage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image')),
      body: InteractiveViewer(
        child: Center(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (c, e, st) => const Text('Could not load image'),
          ),
        ),
      ),
    );
  }
}
