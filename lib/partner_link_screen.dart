// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aquasync/aqua_sync_provider.dart';

class PartnerLinkScreen extends StatelessWidget {
  const PartnerLinkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AquaSyncProvider>(context);
    final emailController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vincular Parceiro'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color.fromARGB(255, 75, 55, 140) : const Color.fromARGB(255, 235, 220, 255),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email do Parceiro',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: provider.partnerUid == null
                  ? () async {
                      final email = emailController.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Por favor, insira um email válido.')),
                        );
                        return;
                      }

                      final success = await provider.setPartner(email);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Parceiro vinculado com sucesso!')),
                        );
                        Navigator.pop(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Erro: Parceiro não encontrado.')),
                        );
                      }
                    }
                  : null,
              child: const Text('Vincular'),
            ),
            if (provider.partnerUid != null)
              ElevatedButton(
                onPressed: () async {
                  await provider.removePartner();
                  // ignore: duplicate_ignore
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Parceiro desvinculado com sucesso!')),
                  );
                  // ignore: duplicate_ignore
                  // ignore: use_build_context_synchronously
                  Navigator.pop(context);
                },
                child: const Text('Desvincular Parceiro'),
              ),
          ],
        ),
      ),
    );
  }
}
