import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Picture360App());
}

class Picture360App extends StatelessWidget {
  const Picture360App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '360 Picture',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1A73E8),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const HomeScreen(),
    );
  }
}
