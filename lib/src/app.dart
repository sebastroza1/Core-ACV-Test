import 'package:flutter/material.dart';

import 'features/menu/menu_page.dart';

class CoreAcvDesktopApp extends StatelessWidget {
  const CoreAcvDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Core ACV Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const MenuPage(),
    );
  }
}
