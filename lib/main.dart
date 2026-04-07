import 'package:flutter/material.dart';
import 'screens/auth_gate.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Toggle this depending on where you run
  const bool useRealPhone = true;

  final api = Api(
    baseUrl: useRealPhone
        ? 'http://10.39.14.21:8000'
        : 'http://10.0.2.2:8000',
  );

  runApp(MyApp(api: api));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.api});

  final Api api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TFA Social',
      home: AuthGate(api: api),
    );
  }
}