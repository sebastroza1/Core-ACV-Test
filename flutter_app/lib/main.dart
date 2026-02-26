import 'package:flutter/material.dart';

import 'src/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FastFaceDesktopApp());
}

class FastFaceDesktopApp extends StatelessWidget {
  const FastFaceDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FAST Face Desktop',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
