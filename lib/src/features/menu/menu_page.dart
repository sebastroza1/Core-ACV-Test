import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../face/face_page.dart';
import '../speech/speech_page.dart';
import '../watch/watch_page.dart';
import 'menu_option.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key, this.config = AppConfig.desktopDefault});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Core ACV - Menú de pruebas')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Selecciona un módulo',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: kMenuOptions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (BuildContext context, int index) {
                  final MenuOption option = kMenuOptions[index];
                  return Card(
                    child: ListTile(
                      leading: Icon(option.icon),
                      title: Text(option.title),
                      subtitle: Text(option.description),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => _openFeature(context, option.feature),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFeature(BuildContext context, MenuFeature feature) {
    switch (feature) {
      case MenuFeature.smartWatch:
        Navigator.of(context).push(
          MaterialPageRoute<WatchPage>(
            builder: (_) => WatchPage(config: config),
          ),
        );
      case MenuFeature.faceAsymmetry:
        Navigator.of(context).push(
          MaterialPageRoute<FacePage>(
            builder: (_) => FacePage(config: config),
          ),
        );
      case MenuFeature.speechAsymmetry:
        Navigator.of(context).push(
          MaterialPageRoute<SpeechPage>(
            builder: (_) => SpeechPage(config: config),
          ),
        );
    }
  }
}
