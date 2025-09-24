import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String _signupUrl =
      'https://access-asset-management-h9fmcwbhcwf5h5f7.westus3-01.azurewebsites.net/api/signup?code=Pe7gWTppL32N6o-730erfZ4zeIzcgKHhmRW9in61pQ-9AzFukq-nfw==';


  static const String _loginUrl =
      'xyz';

  static Future<({bool ok, String msg})> signup({
    required String username,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final r = await http.post(
        Uri.parse(_signupUrl),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username.trim(),
          'email': email.trim(),
          'phonenumber': phone.trim(),
          'password': password,
        }),
      );
      if (r.statusCode == 200 || r.statusCode == 201) return (ok: true, msg: 'Account created');
      if (r.statusCode == 409) return (ok: false, msg: 'Username or email already exists');
      if (r.statusCode == 400) return (ok: false, msg: r.body.isNotEmpty ? r.body : 'Invalid input');
      return (ok: false, msg: 'Server error (${r.statusCode})');
    } catch (e) {
      return (ok: false, msg: 'Network error: $e');
    }
  }

  static Future<({bool ok, String msg})> login({
    String? username,
    String? email,
    required String password,
  }) async {
    try {
      final r = await http.post(
        Uri.parse(_loginUrl),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          if (username != null) 'username': username.trim(),
          if (email != null) 'email': email?.trim(),
          'password': password,
        }),
      );
      if (r.statusCode == 200) return (ok: true, msg: 'Login success');
      if (r.statusCode == 401) return (ok: false, msg: 'Invalid credentials');
      if (r.statusCode == 400) return (ok: false, msg: r.body.isNotEmpty ? r.body : 'Invalid input');
      return (ok: false, msg: 'Server error (${r.statusCode})');
    } catch (e) {
      return (ok: false, msg: 'Network error: $e');
    }
  }
}
