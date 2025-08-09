import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _starsController;
  late AnimationController _fadeController;
  late Animation<double> _starsAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _starsController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    _fadeController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _starsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _starsController,
      curve: Curves.easeInOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    
    _fadeController.forward();
    
    // Check first launch and navigate accordingly after 4 seconds
    _checkFirstLaunchAndNavigate();
  }

  Future<void> _checkFirstLaunchAndNavigate() async {
    await Future.delayed(const Duration(seconds: 4));
    
    if (!mounted) return;
    
    try {
      final box = await Hive.openBox('rhyme_star_prefs');
      final hasSeenAgeGate = box.get('has_seen_age_gate', defaultValue: false);
      final hasSeenIntroCarousel = box.get('has_seen_intro_carousel', defaultValue: false);
      final hasUploadedPhoto = box.get('has_uploaded_photo', defaultValue: false);
      final hasGeneratedAvatar = box.get('has_generated_avatar', defaultValue: false);
      
      if (!hasSeenAgeGate) {
        // First time user, show age gate
        context.go('/age-gate');
      } else if (!hasSeenIntroCarousel) {
        // User has seen age gate but not intro carousel
        context.go('/intro-carousel');
      } else if (!hasUploadedPhoto) {
        // User has seen intro carousel but not uploaded photo
        context.go('/upload-photo');
      } else if (!hasGeneratedAvatar) {
        // User has uploaded photo but not generated avatar, go to onboard
        context.go('/onboard');
      } else {
        // User has completed avatar generation, go to home
        context.go('/home');
      }
    } catch (e) {
      // If there's an error with Hive, assume first launch
      context.go('/age-gate');
    }
  }

  @override
  void dispose() {
    _starsController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF4FC3F7), // Light blue
              Color(0xFF26C6DA), // Cyan
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated Stars Background
            AnimatedBuilder(
              animation: _starsAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: screenSize,
                  painter: SplashStarsPainter(_starsAnimation.value, isSmallScreen),
                );
              },
            ),
            
            // Green Hills at Bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: CustomPaint(
                size: Size(screenSize.width, isSmallScreen ? 80 : 120),
                painter: SplashHillsPainter(),
              ),
            ),
            
            // Main Content
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 24 : 32,
                  vertical: isSmallScreen ? 16 : 24,
                ),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    
                    // Cartoon Character - exactly like the image
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SplashCharacter(
                        size: isSmallScreen ? 100 : 140,
                      ),
                    ),
                    
                    SizedBox(height: isSmallScreen ? 30 : 40),
                    
                    // "My Rhyme Star" Title - exactly like the image
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SplashTitle(isSmallScreen: isSmallScreen),
                    ),
                    
                    const Spacer(flex: 3),
                    
                    // Loading Button - exactly like the image
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SplashLoadingButton(isSmallScreen: isSmallScreen),
                    ),
                    
                    SizedBox(height: isSmallScreen ? 40 : 60),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SplashCharacter extends StatelessWidget {
  final double size;
  
  const SplashCharacter({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Head (larger and more prominent)
          Container(
            width: size * 0.85,
            height: size * 0.85,
            decoration: const BoxDecoration(
              color: Color(0xFFFFDBB5), // Skin tone
              shape: BoxShape.circle,
            ),
          ),
          
          // Hair (brown, covering more of the head like in image)
          Positioned(
            top: size * 0.02,
            child: Container(
              width: size * 0.82,
              height: size * 0.6,
              decoration: const BoxDecoration(
                color: Color(0xFF8B4513), // Brown hair
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(50),
                  topRight: Radius.circular(50),
                ),
              ),
            ),
          ),
          
          // Hair tuft on top
          Positioned(
            top: size * 0.08,
            left: size * 0.35,
            child: Container(
              width: size * 0.3,
              height: size * 0.25,
              decoration: const BoxDecoration(
                color: Color(0xFF8B4513),
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
            ),
          ),
          
          // Left Eye (bigger like in image)
          Positioned(
            top: size * 0.28,
            left: size * 0.22,
            child: Container(
              width: size * 0.18,
              height: size * 0.18,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: size * 0.12,
                  height: size * 0.12,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          
          // Right Eye
          Positioned(
            top: size * 0.28,
            right: size * 0.22,
            child: Container(
              width: size * 0.18,
              height: size * 0.18,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: size * 0.12,
                  height: size * 0.12,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          
          // Nose (small dot like in image)
          Positioned(
            top: size * 0.45,
            child: Container(
              width: size * 0.04,
              height: size * 0.04,
              decoration: const BoxDecoration(
                color: Color(0xFFFFB87A),
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          // Mouth (wider smile like in image)
          Positioned(
            top: size * 0.52,
            child: Container(
              width: size * 0.25,
              height: size * 0.08,
              decoration: const BoxDecoration(
                color: Color(0xFFFF6B6B),
                borderRadius: BorderRadius.all(Radius.circular(15)),
              ),
            ),
          ),
          
          // Yellow Shirt (like in the image)
          Positioned(
            bottom: 0,
            child: Container(
              width: size * 0.65,
              height: size * 0.35,
              decoration: const BoxDecoration(
                color: Color(0xFFFDD835), // Yellow shirt
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SplashTitle extends StatelessWidget {
  final bool isSmallScreen;
  
  const SplashTitle({
    super.key,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // "My" text - smaller like in image
        Text(
          'My',
          style: TextStyle(
            fontSize: isSmallScreen ? 32 : 40,
            fontWeight: FontWeight.bold,
            foreground: Paint()
              ..style = PaintingStyle.fill
              ..color = const Color(0xFFFDD835), // Yellow
            shadows: const [
              Shadow(
                offset: Offset(3, 3),
                blurRadius: 0,
                color: Color(0xFF1976D2), // Blue outline
              ),
              Shadow(
                offset: Offset(-3, -3),
                blurRadius: 0,
                color: Color(0xFF1976D2),
              ),
              Shadow(
                offset: Offset(3, -3),
                blurRadius: 0,
                color: Color(0xFF1976D2),
              ),
              Shadow(
                offset: Offset(-3, 3),
                blurRadius: 0,
                color: Color(0xFF1976D2),
              ),
            ],
          ),
        ),
        
        // "Rhyme" text - larger like in image
        Text(
          'Rhyme',
          style: TextStyle(
            fontSize: isSmallScreen ? 48 : 64,
            fontWeight: FontWeight.bold,
            foreground: Paint()
              ..style = PaintingStyle.fill
              ..color = const Color(0xFFFF8A65), // Orange
            shadows: const [
              Shadow(
                offset: Offset(4, 4),
                blurRadius: 0,
                color: Color(0xFF1976D2), // Blue outline
              ),
              Shadow(
                offset: Offset(-4, -4),
                blurRadius: 0,
                color: Color(0xFF1976D2),
              ),
              Shadow(
                offset: Offset(4, -4),
                blurRadius: 0,
                color: Color(0xFF1976D2),
              ),
              Shadow(
                offset: Offset(-4, 4),
                blurRadius: 0,
                color: Color(0xFF1976D2),
              ),
            ],
          ),
        ),
        
        // "Star" text - larger like in image
        Text(
          'Star',
          style: TextStyle(
            fontSize: isSmallScreen ? 48 : 64,
            fontWeight: FontWeight.bold,
            foreground: Paint()
              ..style = PaintingStyle.fill
              ..color = const Color(0xFF66BB6A), // Green
            shadows: const [
              Shadow(
                offset: Offset(4, 4),
                blurRadius: 0,
                color: Color(0xFF1976D2), // Blue outline
              ),
              Shadow(
                offset: Offset(-4, -4),
                blurRadius: 0,
                color: Color(0xFF1976D2),
              ),
              Shadow(
                offset: Offset(4, -4),
                blurRadius: 0,
                color: Color(0xFF1976D2),
              ),
              Shadow(
                offset: Offset(-4, 4),
                blurRadius: 0,
                color: Color(0xFF1976D2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SplashLoadingButton extends StatelessWidget {
  final bool isSmallScreen;
  
  const SplashLoadingButton({
    super.key,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 40 : 50, 
        vertical: isSmallScreen ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFDD835), // Yellow like in image
        borderRadius: BorderRadius.circular(isSmallScreen ? 25 : 30),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 6),
            blurRadius: 12,
            color: Colors.black.withOpacity(0.3),
          ),
        ],
      ),
      child: Text(
        'LOADING...',
        style: TextStyle(
          fontSize: isSmallScreen ? 16 : 20,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF5D4037), // Brown text like in image
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class SplashStarsPainter extends CustomPainter {
  final double animation;
  final bool isSmallScreen;
  
  SplashStarsPainter(this.animation, this.isSmallScreen);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final random = math.Random(42); // Fixed seed for consistent pattern
    
    // Generate stars at fixed positions like in the image
    for (int i = 0; i < (isSmallScreen ? 30 : 40); i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * (size.height * 0.8); // Keep stars away from hills
      final starSize = 4.0 + random.nextDouble() * (isSmallScreen ? 8.0 : 12.0);
      final shape = random.nextInt(3); // 0: star, 1: circle, 2: diamond
      final colorIndex = random.nextInt(5);
      
      // Gentle twinkling animation
      final opacity = 0.6 + (math.sin(animation * 2 * math.pi + i) + 1) * 0.2;
      
      Color starColor;
      switch (colorIndex) {
        case 0:
          starColor = const Color(0xFFFDD835); // Yellow
          break;
        case 1:
          starColor = const Color(0xFFFF8A65); // Orange
          break;
        case 2:
          starColor = const Color(0xFFE91E63); // Pink
          break;
        case 3:
          starColor = const Color(0xFF66BB6A); // Green
          break;
        default:
          starColor = const Color(0xFF42A5F5); // Blue
      }
      
      paint.color = starColor.withOpacity(opacity);
      
      canvas.save();
      canvas.translate(x, y);
      
      switch (shape) {
        case 0: // 4-pointed star
          _draw4PointStar(canvas, paint, starSize);
          break;
        case 1: // Circle
          canvas.drawCircle(Offset.zero, starSize / 2, paint);
          break;
        case 2: // Diamond
          _drawDiamond(canvas, paint, starSize);
          break;
      }
      
      canvas.restore();
    }
  }

  void _draw4PointStar(Canvas canvas, Paint paint, double size) {
    final path = Path();
    final radius = size / 2;
    
    path.moveTo(0, -radius); // Top
    path.lineTo(-radius * 0.3, -radius * 0.3);
    path.lineTo(-radius, 0); // Left
    path.lineTo(-radius * 0.3, radius * 0.3);
    path.lineTo(0, radius); // Bottom
    path.lineTo(radius * 0.3, radius * 0.3);
    path.lineTo(radius, 0); // Right
    path.lineTo(radius * 0.3, -radius * 0.3);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  void _drawDiamond(Canvas canvas, Paint paint, double size) {
    final path = Path();
    final radius = size / 2;
    
    path.moveTo(0, -radius);
    path.lineTo(-radius, 0);
    path.lineTo(0, radius);
    path.lineTo(radius, 0);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class SplashHillsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = const Color(0xFF81C784) // Light green
      ..style = PaintingStyle.fill;
    
    final paint2 = Paint()
      ..color = const Color(0xFF66BB6A) // Darker green
      ..style = PaintingStyle.fill;
    
    // Back hills
    final path1 = Path();
    path1.moveTo(0, size.height * 0.4);
    path1.quadraticBezierTo(
      size.width * 0.3, size.height * 0.1,
      size.width * 0.7, size.height * 0.3,
    );
    path1.quadraticBezierTo(
      size.width * 0.9, size.height * 0.1,
      size.width, size.height * 0.25,
    );
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    
    // Front hills
    final path2 = Path();
    path2.moveTo(0, size.height * 0.7);
    path2.quadraticBezierTo(
      size.width * 0.25, size.height * 0.3,
      size.width * 0.5, size.height * 0.6,
    );
    path2.quadraticBezierTo(
      size.width * 0.75, size.height * 0.4,
      size.width, size.height * 0.5,
    );
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    
    canvas.drawPath(path1, paint1);
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
