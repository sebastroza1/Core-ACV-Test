import 'dart:io';

import 'package:flutter/material.dart';

import '../services/validation_store.dart';

class ValidationModeScreen extends StatefulWidget {
  const ValidationModeScreen({super.key});

  @override
  State<ValidationModeScreen> createState() => _ValidationModeScreenState();
}

class _ValidationModeScreenState extends State<ValidationModeScreen> {
  String? exportPath;

  Future<void> exportCsv() async {
    final dir = Directory.systemTemp;
    final file = File('${dir.path}/fast_face_validation.csv');
    final header = 'id,timestamp,geom_abs_neutral,palsy_prob_neutral,final_score,status';
    final rows = ValidationStore.records.map((r) => r.toCsv()).join('\n');
    await file.writeAsString('$header\n$rows\n');
    setState(() => exportPath = file.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Validation Mode')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Validation dataset from real sessions (anonymized feature outputs).'),
            Text('Records: ${ValidationStore.records.length}'),
            const SizedBox(height: 8),
            FilledButton(onPressed: ValidationStore.records.isEmpty ? null : exportCsv, child: const Text('Export CSV')),
            if (exportPath != null) Text('CSV exported: $exportPath'),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: ValidationStore.records.length,
                itemBuilder: (_, i) {
                  final r = ValidationStore.records[i];
                  return ListTile(
                    title: Text('${r.id} - ${r.status}'),
                    subtitle: Text('geom=${r.geom.toStringAsFixed(2)} prob=${r.prob.toStringAsFixed(3)} final=${r.finalScore.toStringAsFixed(2)}'),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
