import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aquasync/aqua_sync_provider.dart';
import 'package:aquasync/login_screen.dart';
import 'package:aquasync/history_screen.dart';
import 'package:aquasync/partner_link_screen.dart';
import 'package:get/get.dart';
import 'package:aquasync/theme_controller.dart';

class AquaSyncScreen extends StatefulWidget {
  const AquaSyncScreen({super.key});

  @override
  State<AquaSyncScreen> createState() => _AquaSyncScreenState();
}

class _AquaSyncScreenState extends State<AquaSyncScreen> {
  int dailyGoal = 3000;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AquaSyncProvider>(context);
    final ThemeController themeController = Get.put(ThemeController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aqua Sync'),
        actions: [
          IconButton(
            icon: Obx(() => Icon(themeController.isDarkMode.value ? Icons.light_mode : Icons.dark_mode)),
            onPressed: () {
              themeController.toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await provider.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildWaterBottle(provider),
            const SizedBox(height: 20),
            Text(
              'Meu Consumo: ${provider.myWaterConsumption} ml',
              style: const TextStyle(fontSize: 18),
            ),
            if (provider.partnerDisplayName != null) ...[
              const SizedBox(height: 10),
              Text(
                'Parceiro: ${provider.partnerDisplayName}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'Consumo do Parceiro: ${provider.partnerWaterConsumption} ml',
                style: const TextStyle(fontSize: 18),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _showAddWaterDialog(context, provider),
              child: const Text('Adicionar Consumo'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: provider.partnerUid == null
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PartnerLinkScreen(),
                        ),
                      );
                    }
                  : null,
              child: const Text('Vincular Parceiro'),
            ),
            if (provider.partnerUid != null) ...[
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  await provider.removePartner();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Parceiro removido com sucesso!'),
                  ));
                },
                child: const Text('Remover Parceiro'),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HistoryScreen()),
          );
        },
        child: const Icon(Icons.history),
      ),
    );
  }

  Widget _buildWaterBottle(AquaSyncProvider provider) {
    double progress = provider.myWaterConsumption / dailyGoal;
    progress = progress.clamp(0.0, 1.0); // Garantir que o progresso fique entre 0 e 1

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          height: 300,
          width: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        Container(
          height: 300 * progress,
          width: 150,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddWaterDialog(BuildContext context, AquaSyncProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        int amount = 0;
        return AlertDialog(
          title: const Text('Adicionar Água'),
          content: TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantidade em ml'),
            onChanged: (value) {
              amount = int.tryParse(value) ?? 0;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                provider.addWater(amount);
                Navigator.pop(context);
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
  }
}
