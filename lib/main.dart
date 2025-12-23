import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MaterialLayeringApp());
}

class MaterialLayeringApp extends StatelessWidget {
  const MaterialLayeringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Material Layering System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D9FF),
          secondary: Color(0xFFFF006E),
          surface: Color(0xFF0A0E27),
          error: Color(0xFFFF0000),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0E27),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F1436),
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
