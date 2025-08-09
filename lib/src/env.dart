import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static Future<void> load({String? path}) async {
    try {
      await dotenv.load(fileName: path ?? '.env.local');
    } catch (_) {
      try {
        await dotenv.load(fileName: 'config/env.local.example');
      } catch (_) {}
    }
  }

  static String? _fromDartDefine(String key) {
    const value = String.fromEnvironment('DUMMY');
    // Workaround: String.fromEnvironment requires const key; we can't pass at runtime.
    // So we rely on dotenv primarily; dart-define values should be wired directly in code where needed.
    return null;
  }

  static String? _fromDotenv(String key) {
    final v = dotenv.env[key];
    if (v == null) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  static String? get(String key) => _fromDotenv(key);

  static String get supabaseUrl => get('SUPABASE_URL') ?? '';
  static String get supabaseAnonKey => get('SUPABASE_ANON_KEY') ?? '';

  static String? get openAiKey => get('OPENAI_API_KEY');
  static String? get runwareKey => get('RUNWARE_API_KEY');

  static int get avatarCostGems => int.tryParse(get('AVATAR_COST_GEMS') ?? '') ?? 20;
  static int get videoCostGems => int.tryParse(get('VIDEO_COST_GEMS') ?? '') ?? 50;
  static int get premiumRhymeCostGems => int.tryParse(get('PREMIUM_RHYME_COST_GEMS') ?? '') ?? 100;
  static int get freeGemsStartingBalance => int.tryParse(get('FREE_GEMS_STARTING_BALANCE') ?? '') ?? 200;
}
