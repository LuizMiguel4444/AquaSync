import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aquasync/aqua_sync_provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AquaSyncProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de Consumo')),
      body: FutureBuilder<Map<String, int>>(
        future: provider.getLast7DaysConsumption(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final userHistory = snapshot.data!;
            return ListView(
              children: [
                const ListTile(
                  title: Text(
                    'Seu Histórico (últimos 7 dias)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ...userHistory.entries.map((entry) {
                  return ListTile(
                    title: Text('Dia: ${entry.key}'),
                    subtitle: Text('Consumo: ${entry.value} ml'),
                  );
                }),
                if (provider.partnerUid != null)
                  FutureBuilder<Map<String, int>>(
                    future: provider.getLast7DaysPartnerConsumption(),
                    builder: (context, partnerSnapshot) {
                      if (partnerSnapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }

                      if (partnerSnapshot.hasData && partnerSnapshot.data!.isNotEmpty) {
                        final partnerHistory = partnerSnapshot.data!;
                        return Column(
                          children: [
                            const Divider(),
                            const ListTile(
                              title: Text(
                                'Histórico do Parceiro',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            ...partnerHistory.entries.map((entry) {
                              return ListTile(
                                title: Text('Dia: ${entry.key}'),
                                subtitle: Text('Consumo: ${entry.value} ml'),
                              );
                            }),
                          ],
                        );
                      } else {
                        return const ListTile(
                          title: Text('O parceiro não possui histórico.'),
                        );
                      }
                    },
                  ),
              ],
            );
          } else {
            return const Center(
              child: Text('Nenhum histórico disponível.'),
            );
          }
        },
      ),
    );
  }
}
