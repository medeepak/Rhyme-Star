import 'package:flutter/material.dart';

class GemStoreScreen extends StatelessWidget {
  const GemStoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gem Store')),
      body: const Center(child: Text('Gem Store screen')),
    );
  }
}
