import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aquasync/aqua_sync_provider.dart';
import 'package:aquasync/login_screen.dart';
import 'package:aquasync/history_screen.dart';
import 'package:aquasync/partner_link_screen.dart';
import 'package:get/get.dart';
import 'package:aquasync/theme_controller.dart';
import 'package:wave/config.dart';
import 'package:wave/wave.dart';

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
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color.fromARGB(255, 75, 55, 140) : const Color.fromARGB(255, 235, 220, 255),
        actions: [
          IconButton(
            icon: Obx(() =>
                Icon(themeController.isDarkMode.value ? Icons.light_mode : Icons.dark_mode)),
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildWaterBottle(provider),
              const SizedBox(height: 20),
              if (provider.partnerDisplayName != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Parceiro: ${provider.partnerDisplayName}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Consumo do Parceiro: ${provider.partnerWaterConsumption} ml',
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
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
    progress = progress.clamp(0.0, 1.0);

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 300,
          width: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue, width: 2),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: SizedBox(
              height: 300 * progress,
              width: 200,
              child: progress < 1 ? WaveWidget(
                config: CustomConfig(
                  gradients: [
                    [Colors.blue, Colors.blueAccent],
                    [Colors.lightBlue, Colors.lightBlueAccent],
                  ],
                  durations: [3000, 2200],
                  heightPercentages: [0.0, 0.02],
                ),
                waveAmplitude: 0,
                size: const Size(double.infinity, double.infinity),
              ) : Container(
                color: Colors.lightBlueAccent,
              )
            ),
          ),
        ),
        Text(
          '${provider.myWaterConsumption} ml',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
          content: SingleChildScrollView(
            child: TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantidade em ml'),
              onChanged: (value) {
                amount = int.tryParse(value) ?? 0;
              },
            ),
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
