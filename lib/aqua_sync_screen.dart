import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aquasync/aqua_sync_provider.dart';

class AquaSyncScreen extends StatelessWidget {
  const AquaSyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AquaSyncProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Water Tracker')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Meu Consumo: ${provider.myWaterConsumption} ml',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 10),
            Text(
              'Consumo da Minha Namorada: ${provider.partnerWaterConsumption} ml',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _showAddWaterDialog(context, provider),
              child: Text('Registrar Consumo'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddWaterDialog(BuildContext context, AquaSyncProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        int amount = 0;
        return AlertDialog(
          title: Text('Adicionar Água'),
          content: TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Quantidade em ml'),
            onChanged: (value) {
              amount = int.tryParse(value) ?? 0;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                provider.addWater(amount);
                Navigator.pop(context);
              },
              child: Text('Adicionar'),
            ),
          ],
        );
      },
    );
  }
}
