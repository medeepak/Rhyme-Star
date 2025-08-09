import 'package:flutter/material.dart';

class AvatarPreviewScreen extends StatelessWidget {
  const AvatarPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avatar Preview')),
      body: const Center(child: Text('Avatar Preview screen')),
    );
  }
}
