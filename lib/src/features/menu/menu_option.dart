import 'package:flutter/material.dart';

enum MenuFeature { smartWatch, faceAsymmetry, speechAsymmetry }

class MenuOption {
  const MenuOption({
    required this.feature,
    required this.title,
    required this.description,
    required this.icon,
  });

  final MenuFeature feature;
  final String title;
  final String description;
  final IconData icon;
}

const List<MenuOption> kMenuOptions = <MenuOption>[
  MenuOption(
    feature: MenuFeature.smartWatch,
    title: 'Smart Watch (Huawei)',
    description:
        'Conexión Bluetooth y visualización de giroscopio + acelerómetro.',
    icon: Icons.watch,
  ),
  MenuOption(
    feature: MenuFeature.faceAsymmetry,
    title: 'Cara',
    description: 'Modelo de asimetrías faciales con puntaje en tiempo real.',
    icon: Icons.face,
  ),
  MenuOption(
    feature: MenuFeature.speechAsymmetry,
    title: 'Habla',
    description:
        'Detección de asimetrías del habla con “Tres tristes tigres”.',
    icon: Icons.record_voice_over,
  ),
];
