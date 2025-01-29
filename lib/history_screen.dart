import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aquasync/aqua_sync_provider.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AquaSyncProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Consumo'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color.fromARGB(255, 75, 55, 140) : const Color.fromARGB(255, 235, 220, 255),
      ),
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
                  String formattedDate = _formatDate(entry.key);
                  return ListTile(
                    title: Text('Dia: $formattedDate', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: Text('Consumo: ${entry.value} ml', style: TextStyle(fontSize: 12)),
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
                              String formattedDate = _formatDate(entry.key);
                              return ListTile(
                                title: Text('Dia: $formattedDate', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                subtitle: Text('Consumo: ${entry.value} ml', style: TextStyle(fontSize: 12)),
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

  String _formatDate(String date) {
    DateTime parsedDate = DateTime.parse(date);
    return DateFormat('dd/MM/yyyy').format(parsedDate);
  }
}
