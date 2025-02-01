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
import 'package:confetti/confetti.dart';

class AquaSyncScreen extends StatefulWidget {
  const AquaSyncScreen({super.key});

  @override
  State<AquaSyncScreen> createState() => _AquaSyncScreenState();
}

class _AquaSyncScreenState extends State<AquaSyncScreen> {
  int dailyGoal = 3000;
  final ConfettiController _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  bool _hasReachedGoal = false;

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
            onPressed: () => _showLogoutDialog(context, provider),
          ),
        ],
      ),
      body: Stack(
          children: [ 
            Center(
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
                      onPressed: () => _showRemovePartnerDialog(context, provider),
                      child: const Text('Remover Parceiro'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          _buildConfetti(),
        ],
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

  void _checkDailyGoal(AquaSyncProvider provider) {
    if (provider.myWaterConsumption >= dailyGoal && !_hasReachedGoal) {
      _hasReachedGoal = true;
      _confettiController.play();

      Future.delayed(Duration.zero, () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🎉 Parabéns! Você atingiu sua meta diária!", textAlign: TextAlign.center),
            duration: Duration(seconds: 5),
          ),
        );
      });

      _confettiController.play();
    }
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
              height: 335 * progress,
              width: 200,
              child: progress < 1 ? WaveWidget(
                config: CustomConfig(
                  gradients: [
                    [Colors.blue, Colors.blueAccent],
                    [Colors.lightBlue, Colors.lightBlue],
                  ],
                  durations: [3000, 2200],
                  heightPercentages: [0.0, 0.02],
                ),
                waveAmplitude: 0,
                size: const Size(double.infinity, double.infinity),
              ) : Container(
                color: Colors.lightBlue,
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

  Widget _buildConfetti() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConfettiWidget(
        confettiController: _confettiController,
        blastDirection: 3.14 / 2,
        numberOfParticles: 50,
        gravity: 0.5,
      ),
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
                _checkDailyGoal(provider);
                Navigator.pop(context);
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context, AquaSyncProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sair da Conta'),
          content: const Text('Tem certeza de que deseja sair da sua conta?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Fecha o diálogo sem sair
              child: const Text('Não'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Fecha o diálogo
                await provider.signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text('Sim'),
            ),
          ],
        );
      },
    );
  }

  void _showRemovePartnerDialog(BuildContext context, AquaSyncProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remover Parceiro'),
          content: const Text('Tem certeza de que deseja remover seu parceiro?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Fecha o diálogo sem remover
              child: const Text('Não'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Fecha o diálogo
                await provider.removePartner();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Parceiro removido com sucesso!'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              child: const Text('Sim'),
            ),
          ],
        );
      },
    );
  }
}
