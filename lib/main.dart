// lib/main.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'pages/auth_pages.dart';

const bool kSmokeTest = false; // set true briefly to test shell

void main() {
  runZonedGuarded(() async {
    // IMPORTANT: init inside the SAME zone that calls runApp
    WidgetsFlutterBinding.ensureInitialized();

    BindingBase.debugZoneErrorsAreFatal = true; // surfaces issues during debug

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('Flutter error: ${details.exceptionAsString()}');
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('Uncaught platform error: $error\n$stack');
      return true;
    };

    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _mode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _mode = (_mode == ThemeMode.light) ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asset Management',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.blue,
          brightness: Brightness.light),
      darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.blue,
          brightness: Brightness.dark),
      home: kSmokeTest
          ? const _SmokeTest()
          : LoginPage(
              isDark: _mode == ThemeMode.dark, onToggleTheme: _toggleTheme),
      builder: (context, child) {
        ErrorWidget.builder = (d) {
          debugPrint('ErrorWidget: ${d.exceptionAsString()}');
          return Scaffold(
            body: Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  border: Border.all(color: Colors.redAccent),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Oops: ${d.exception}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center),
              ),
            ),
          );
        };
        return child!;
      },
    );
  }
}

class _SmokeTest extends StatelessWidget {
  const _SmokeTest({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Smoke test OK')));
}
