import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'src/routes.dart';
import 'src/theme.dart';
import 'src/env.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Env.load(path: '.env.local');

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize Supabase if configured
  if (Env.supabaseUrl.isNotEmpty && Env.supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }

  runApp(const ProviderScope(child: RhymeStarApp()));
}

class RhymeStarApp extends StatelessWidget {
  const RhymeStarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Rhyme Star',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: router,
    );
  }
}
