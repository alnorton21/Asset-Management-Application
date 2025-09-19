// lib/services/upload_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class UploadService {
  // Your API endpoint
  static const _endpoint =
      'https://access-asset-management-h9fmcwbhcwf5h5f7.westus3-01.azurewebsites.net/api/UploadSignage?code=_vBpTyw7BbnNyqKrmBpd3WoC_aUgj6jDAv8iviOptcNaAzFu6H9kyA==';

  Future<void> uploadSignage(Map<String, dynamic> payload) async {
    final resp = await http.post(
      Uri.parse(_endpoint),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
  }
}
