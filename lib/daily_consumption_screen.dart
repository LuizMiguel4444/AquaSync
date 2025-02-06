import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aquasync/aqua_sync_provider.dart';
import 'package:intl/intl.dart';

class DailyConsumptionScreen extends StatelessWidget {
  final String date;
  final bool isPartner;

  const DailyConsumptionScreen({super.key, required this.date, this.isPartner = false});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AquaSyncProvider>(context);
    String formattedDate = _formatDate(date);

    return Scaffold(
      appBar: AppBar(
        title: Text('Registros de $formattedDate', style: TextStyle(fontSize: 20)),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color.fromARGB(255, 75, 55, 140)
            : const Color.fromARGB(255, 235, 220, 255),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: isPartner
            ? provider.getDailyConsumptionRecordsForPartner(date)
            : provider.getDailyConsumptionRecords(date),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final records = snapshot.data!;
            return ListView(
              children: records.map((record) {
                String formattedTime = _formatTime(record['timestamp']);
                return ListTile(
                  leading: const Icon(Icons.local_drink),
                  title: Text('Quantidade: ${record['amount']} ml', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Horário: $formattedTime'),
                );
              }).toList(),
            );
          } else {
            return const Center(
              child: Text('Nenhum registro encontrado para este dia.'),
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

  String _formatTime(dynamic timestamp) {
    if (timestamp is String && timestamp.isNotEmpty) {
      DateTime dateTime = DateTime.parse(timestamp);
      return DateFormat('HH:mm').format(dateTime);
    }
    return '--:--';
  }
}
