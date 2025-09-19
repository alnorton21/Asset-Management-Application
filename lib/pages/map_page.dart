// lib/pages/map_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../constants.dart';

// A simple viewer-only map that shows “dot” markers for each photo in the container.
// Expects files to be named like "<lat>_<lon>.jpg|png".
class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _map = MapController();
  static const LatLng _start = LatLng(39.7014, -75.1063);
  double _zoom = 13;

  final _photoPoints = <LatLng>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDots();
  }

  Uri _containerListUri() {
    final base = Uri.parse(azureContainerSasUrl);
    final qp = Map<String, String>.from(base.queryParameters);
    qp['restype'] = 'container';
    qp['comp'] = 'list';
    qp['maxresults'] = '5000';
    return base.replace(queryParameters: qp);
  }

  Future<void> _loadDots() async {
    setState(() => _loading = true);
    try {
      final resp = await http.get(_containerListUri());
      if (resp.statusCode != 200) {
        throw Exception('List failed (${resp.statusCode}).');
      }
      final body = resp.body;
      final regex = RegExp(r'<Name>([^<]+)</Name>');
      final names = regex.allMatches(body).map((m) => m.group(1)!).toList();

      final pts = <LatLng>[];
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
        pts.add(LatLng(lat, lon));
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not load dots: $e')));
      }
    }
  }

  Marker _dot(LatLng p) {
    const double size = 14;
    return Marker(
      point: p,
      width: size + 6,
      height: size + 6,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final dots = _photoPoints.map(_dot).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Map Viewer')),
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
              MarkerLayer(markers: dots),
              RichAttributionWidget(
                attributions: const [
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
