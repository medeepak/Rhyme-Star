import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'presentation/splash_screen.dart';
import 'presentation/age_gate_screen.dart';
import 'presentation/intro_carousel_screen.dart';
import 'presentation/onboard_screen.dart';
import 'presentation/home_screen.dart';
import 'presentation/gem_store_screen.dart';
import 'presentation/upload_photo_screen.dart';
import 'presentation/avatar_generation_screen.dart';
import 'presentation/avatar_preview_screen.dart';
import 'presentation/rhyme_catalog_screen.dart';
import 'presentation/rhyme_generation_screen.dart';
import 'presentation/video_player_screen.dart';
import 'presentation/profile_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const SplashScreen(),
    ),
    GoRoute(
      path: '/age-gate',
      builder: (_, __) => const AgeGateScreen(),
    ),
    GoRoute(
      path: '/intro-carousel',
      builder: (_, __) => const IntroCarouselScreen(),
    ),
    GoRoute(
      path: '/upload-photo',
      builder: (_, __) => const UploadPhotoScreen(),
    ),
    GoRoute(
      path: '/avatar-generation',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return AvatarGenerationScreen(
          uploadedImage: extra?['uploadedImage'],
          childName: extra?['childName'] ?? '',
        );
      },
    ),
    GoRoute(
      path: '/onboard',
      builder: (_, __) => const OnboardScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return HomeScreen(
          userAvatar: extra?['userAvatar'],
        );
      },
    ),
    GoRoute(
      path: '/gem-store',
      builder: (_, __) => const GemStoreScreen(),
    ),
    GoRoute(
      path: '/avatar-preview',
      builder: (_, __) => const AvatarPreviewScreen(),
    ),
    GoRoute(
      path: '/rhyme-catalog',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return RhymeCatalogScreen(
          userAvatar: extra?['userAvatar'],
        );
      },
    ),
    GoRoute(
      path: '/rhyme-generation',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return RhymeGenerationScreen(
          rhyme: extra?['rhyme'],
          userAvatar: extra?['userAvatar'],
        );
      },
    ),
    GoRoute(
      path: '/video-player',
      builder: (_, __) => const VideoPlayerScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (_, __) => const ProfileScreen(),
    ),
  ],
);
