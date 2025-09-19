// lib/pages/landing_page.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show File; // mobile/desktop only

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../services/upload_service.dart';
import 'map_page.dart';

enum AssetKind { signage, curbs, drainage }

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _picker = ImagePicker();
  final _upload = UploadService();

  // ----- image state (web vs mobile) -----
  // Web: we hold bytes + the picked name for extension detection.
  Uint8List? _photoBytesWeb;
  String? _webPickedName;

  // Mobile/desktop: the file reference.
  XFile? _photoFile;

  bool _busy = false;

  // dropdown
  AssetKind _selected = AssetKind.signage;

  // signage form controllers/fields
  final _formKeySignage = GlobalKey<FormState>();
  final _street = TextEditingController();
  final _milepost = TextEditingController(text: '1');
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  String _locationSide = 'Right';
  final _posts = TextEditingController(text: '1');
  final _type = TextEditingController(text: 'Stop');
  final _height = TextEditingController(text: '4.2');
  bool _illuminated = false;
  bool _walkway = false;

  @override
  void dispose() {
    _street.dispose();
    _milepost.dispose();
    _lat.dispose();
    _lon.dispose();
    _posts.dispose();
    _type.dispose();
    _height.dispose();
    super.dispose();
  }

  // -------- helpers to build blob name --------
  String _cleanExt(String? nameOrPath) {
    if (nameOrPath == null) return '.jpg';
    final n = nameOrPath.toLowerCase();
    if (n.endsWith('.png')) return '.png';
    return '.jpg';
  }

  String _buildBlobName(double lat, double lon, String ext) {
    final latStr = lat.toStringAsFixed(6);
    final lonStr = lon.toStringAsFixed(6);
    return '${latStr}_${lonStr}$ext';
  }

  // ----- image capture -----
  Future<void> _capture() async {
    final img = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (img == null) return;

    if (kIsWeb) {
      // On web we must render bytes; File I/O is not supported.
      final bytes = await img.readAsBytes();
      setState(() {
        _photoBytesWeb = bytes;
        _webPickedName = img.name; // keep original name to detect extension
        _photoFile = null;
      });
    } else {
      setState(() {
        _photoFile = img;
        _photoBytesWeb = null;
        _webPickedName = null;
      });
    }
  }

  // ----- GPS fill -----
  Future<void> _useGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Location services are disabled.');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception('Location permission not granted.');
      }
      final pos =
          await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      setState(() {
        _lat.text = pos.latitude.toStringAsFixed(6);
        _lon.text = pos.longitude.toStringAsFixed(6);
      });
    } catch (e) {
      _snack('GPS error: $e');
    }
  }

  // ----- submit signage -----
  Future<void> _submitSignage() async {
    // Validate we have an image first
    if (kIsWeb ? _photoBytesWeb == null : _photoFile == null) {
      _snack('Please capture an image first.');
      return;
    }

    if (!_formKeySignage.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      // Prepare base64 image and blob_name
      late final Uint8List rawBytes;
      late final String ext;

      if (kIsWeb) {
        rawBytes = _photoBytesWeb!;
        ext = _cleanExt(_webPickedName);
      } else {
        final bytes = await File(_photoFile!.path).readAsBytes();
        rawBytes = bytes;
        ext = _cleanExt(_photoFile!.path);
      }

      final imgBase64 = base64Encode(rawBytes);
      final nowStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final latVal = double.tryParse(_lat.text.trim()) ?? 0;
      final lonVal = double.tryParse(_lon.text.trim()) ?? 0;
      final blobName = _buildBlobName(latVal, lonVal, ext);

      final payload = {
        "image": imgBase64,
        "street": _street.text.trim(),
        "milepost": double.tryParse(_milepost.text.trim()) ?? 0,
        "lat": latVal,
        "long": lonVal,
        "location": _locationSide,
        "posts": int.tryParse(_posts.text.trim()) ?? 1,
        "type": _type.text.trim(),
        "height": double.tryParse(_height.text.trim()) ?? 0,
        "illuminated": _illuminated,
        "walkway": _walkway,
        "inventory_date": nowStr,
        // 👇 ask server to save the blob as lat_lon.ext
        "blob_name": blobName,
      };

      await _upload.uploadSignage(payload);
      _snack('Uploaded signage successfully ✅');
    } catch (e) {
      _snack('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final imageWidget = Builder(
      builder: (_) {
        if (kIsWeb) {
          if (_photoBytesWeb == null) {
            return _emptyImageBox();
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(_photoBytesWeb!, height: 180, fit: BoxFit.cover),
          );
        } else {
          if (_photoFile == null) {
            return _emptyImageBox();
          }
          // Only use Image.file on non-web
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(_photoFile!.path), height: 180, fit: BoxFit.cover),
          );
        }
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Asset Intake')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: imageWidget),
                const SizedBox(width: 12),
                Column(
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : _capture,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Capture'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : _useGps,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Use GPS'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<AssetKind>(
              value: _selected,
              decoration: const InputDecoration(
                labelText: 'Asset Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: AssetKind.signage, child: Text('Signage')),
                DropdownMenuItem(value: AssetKind.curbs, child: Text('Curbs')),
                DropdownMenuItem(value: AssetKind.drainage, child: Text('Drainage')),
              ],
              onChanged: _busy
                  ? null
                  : (v) {
                      if (v != null) setState(() => _selected = v);
                    },
            ),
            const SizedBox(height: 16),

            if (_selected == AssetKind.signage)
              _signageForm()
            else if (_selected == AssetKind.curbs)
              _placeholderCard('Curbs form – TBD')
            else
              _placeholderCard('Drainage form – TBD'),

            const SizedBox(height: 24),
            // Visualize button -> Map page
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MapPage()),
                  );
                },
                icon: const Icon(Icons.map),
                label: const Text('Visualize (Map)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyImageBox() => Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
        ),
        alignment: Alignment.center,
        child: const Text('No image captured'),
      );

  Widget _placeholderCard(String text) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(text),
        ),
      );

  Widget _signageForm() {
    return Form(
      key: _formKeySignage,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _street,
                  decoration: const InputDecoration(
                    labelText: 'Street',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _milepost,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Milepost',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _lat,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (double.tryParse((v ?? '').trim()) == null)
                          ? 'Enter a number'
                          : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _lon,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (double.tryParse((v ?? '').trim()) == null)
                          ? 'Enter a number'
                          : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _locationSide,
                  decoration: const InputDecoration(
                    labelText: 'Location Side',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Right', child: Text('Right')),
                    DropdownMenuItem(value: 'Left', child: Text('Left')),
                    DropdownMenuItem(value: 'Center', child: Text('Center')),
                  ],
                  onChanged: (v) => setState(() => _locationSide = v ?? 'Right'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _posts,
                  keyboardType:
                      const TextInputType.numberWithOptions(signed: false),
                  decoration: const InputDecoration(
                    labelText: 'Posts',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (int.tryParse((v ?? '').trim()) == null)
                          ? 'Enter an integer'
                          : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _type,
                  decoration: const InputDecoration(
                    labelText: 'Type (e.g., Stop)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _height,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Height (m)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (double.tryParse((v ?? '').trim()) == null)
                          ? 'Enter a number'
                          : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _illuminated,
            onChanged: (v) => setState(() => _illuminated = v),
            title: const Text('Illuminated'),
          ),
          SwitchListTile(
            value: _walkway,
            onChanged: (v) => setState(() => _walkway = v),
            title: const Text('Walkway present'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _submitSignage,
              icon: _busy
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(_busy ? 'Submitting...' : 'Submit Signage'),
            ),
          ),
        ],
      ),
    );
  }
}
