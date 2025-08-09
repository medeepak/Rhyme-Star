import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme.dart';
import 'dart:math' as math;

// Provider for current page index
final carouselPageProvider = StateProvider<int>((ref) => 0);

class IntroCarouselScreen extends ConsumerStatefulWidget {
  const IntroCarouselScreen({super.key});

  @override
  ConsumerState<IntroCarouselScreen> createState() => _IntroCarouselScreenState();
}

class _IntroCarouselScreenState extends ConsumerState<IntroCarouselScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _confettiController;
  late Animation<double> _confettiAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    _confettiController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
    
    _confettiAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _confettiController,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _handleGetStarted() async {
    // Mark that user has seen intro carousel
    final box = await Hive.openBox('rhyme_star_prefs');
    await box.put('has_seen_intro_carousel', true);
    
    if (mounted) {
      context.go('/upload-photo');
    }
  }

  void _handleSkip() async {
    await _handleGetStarted();
  }

  void _nextPage() {
    final currentPage = ref.read(carouselPageProvider);
    if (currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _handleGetStarted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = ref.watch(carouselPageProvider);
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF42A5F5), // Light blue
              Color(0xFF26C6DA), // Cyan
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated Confetti Background
            AnimatedBuilder(
              animation: _confettiAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: screenSize,
                  painter: IntroConfettiPainter(_confettiAnimation.value, isSmallScreen),
                );
              },
            ),
            
            // Skip Button
            SafeArea(
              child: Positioned(
                top: 16,
                right: 20,
                child: TextButton(
                  onPressed: _handleSkip,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            
            // Main Content
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  
                  // Title
                  Text(
                    'Create\navatar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 36 : 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.1,
                      shadows: const [
                        Shadow(
                          offset: Offset(2, 2),
                          blurRadius: 4,
                          color: Color(0x40000000),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Steps
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 32 : 48),
                      child: Column(
                        children: [
                          // Step 1
                          StepItem(
                            number: 1,
                            text: 'Create avatar',
                            icon: const StepIcon(
                              backgroundColor: Color(0xFF66BB6A),
                              child: FaceIcon(),
                            ),
                            isSmallScreen: isSmallScreen,
                          ),
                          
                          SizedBox(height: isSmallScreen ? 24 : 32),
                          
                          // Step 2
                          StepItem(
                            number: 2,
                            text: 'Pick a rhyme',
                            icon: const StepIcon(
                              backgroundColor: Color(0xFFFFA726),
                              child: CameraIcon(),
                            ),
                            isSmallScreen: isSmallScreen,
                          ),
                          
                          SizedBox(height: isSmallScreen ? 24 : 32),
                          
                          // Step 3
                          StepItem(
                            number: 3,
                            text: 'Share with friends',
                            icon: const StepIcon(
                              backgroundColor: Color(0xFFEF5350),
                              child: ShareIcon(),
                            ),
                            isSmallScreen: isSmallScreen,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Main Character
                  Expanded(
                    flex: 2,
                    child: MainCharacter(size: isSmallScreen ? 120 : 160),
                  ),
                  
                  // Get Started Button
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 32 : 48,
                      vertical: isSmallScreen ? 24 : 32,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: isSmallScreen ? 52 : 60,
                      child: ElevatedButton(
                        onPressed: _handleGetStarted,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF66BB6A),
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shadowColor: Colors.black.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(isSmallScreen ? 26 : 30),
                          ),
                        ),
                        child: Text(
                          'GET STARTED',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 18 : 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StepItem extends StatelessWidget {
  final int number;
  final String text;
  final Widget icon;
  final bool isSmallScreen;

  const StepItem({
    super.key,
    required this.number,
    required this.text,
    required this.icon,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        icon,
        SizedBox(width: isSmallScreen ? 16 : 20),
        Text(
          '$number. $text',
          style: TextStyle(
            fontSize: isSmallScreen ? 18 : 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            shadows: const [
              Shadow(
                offset: Offset(1, 1),
                blurRadius: 2,
                color: Color(0x40000000),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StepIcon extends StatelessWidget {
  final Color backgroundColor;
  final Widget child;

  const StepIcon({
    super.key,
    required this.backgroundColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 8,
            color: Colors.black.withOpacity(0.2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class FaceIcon extends StatelessWidget {
  const FaceIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.face,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}

class CameraIcon extends StatelessWidget {
  const CameraIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.videocam,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}

class ShareIcon extends StatelessWidget {
  const ShareIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.share,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}

class MainCharacter extends StatelessWidget {
  final double size;

  const MainCharacter({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Head
          Container(
            width: size * 0.8,
            height: size * 0.8,
            decoration: const BoxDecoration(
              color: Color(0xFFFFDBB5), // Skin tone
              shape: BoxShape.circle,
            ),
          ),
          
          // Hair
          Positioned(
            top: size * 0.05,
            child: Container(
              width: size * 0.75,
              height: size * 0.5,
              decoration: const BoxDecoration(
                color: Color(0xFFD84315), // Red/orange hair
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
            ),
          ),
          
          // Eyes
          Positioned(
            top: size * 0.25,
            left: size * 0.2,
            child: Container(
              width: size * 0.08,
              height: size * 0.08,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: size * 0.25,
            right: size * 0.2,
            child: Container(
              width: size * 0.08,
              height: size * 0.08,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          // Smile
          Positioned(
            top: size * 0.45,
            child: Container(
              width: size * 0.2,
              height: size * 0.1,
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
            ),
          ),
          
          // Shirt
          Positioned(
            bottom: size * 0.1,
            child: Container(
              width: size * 0.6,
              height: size * 0.3,
              decoration: const BoxDecoration(
                color: Color(0xFF42A5F5), // Blue shirt
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
            ),
          ),
          
          // Waving Hand
          Positioned(
            right: size * 0.05,
            top: size * 0.4,
            child: Transform.rotate(
              angle: 0.3,
              child: Container(
                width: size * 0.15,
                height: size * 0.15,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFDBB5),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IntroConfettiPainter extends CustomPainter {
  final double animation;
  final bool isSmallScreen;
  
  IntroConfettiPainter(this.animation, this.isSmallScreen);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final random = math.Random(456); // Different seed for intro
    final confettiCount = isSmallScreen ? 40 : 60;
    
    for (int i = 0; i < confettiCount; i++) {
      final x = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height - 100;
      final fallSpeed = 0.3 + random.nextDouble() * 1.5;
      final y = (startY + (animation * size.height * fallSpeed)) % (size.height + 100);
      
      final confettiSize = (isSmallScreen ? 4.0 : 6.0) + random.nextDouble() * (isSmallScreen ? 8.0 : 12.0);
      final shape = random.nextInt(4); // 0: circle, 1: square, 2: triangle, 3: star
      final colorIndex = random.nextInt(5);
      
      final rotation = animation * 2 * math.pi + i;
      
      Color confettiColor;
      switch (colorIndex) {
        case 0:
          confettiColor = const Color(0xFFFFC107); // Yellow
          break;
        case 1:
          confettiColor = const Color(0xFFE91E63); // Pink
          break;
        case 2:
          confettiColor = const Color(0xFF66BB6A); // Green
          break;
        case 3:
          confettiColor = const Color(0xFFFF9800); // Orange
          break;
        default:
          confettiColor = const Color(0xFF9C27B0); // Purple
      }
      
      paint.color = confettiColor.withOpacity(0.7);
      
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      
      switch (shape) {
        case 0: // Circle
          canvas.drawCircle(Offset.zero, confettiSize / 2, paint);
          break;
        case 1: // Square
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: confettiSize, height: confettiSize),
            paint,
          );
          break;
        case 2: // Triangle
          final path = Path();
          path.moveTo(0, -confettiSize / 2);
          path.lineTo(-confettiSize / 2, confettiSize / 2);
          path.lineTo(confettiSize / 2, confettiSize / 2);
          path.close();
          canvas.drawPath(path, paint);
          break;
        case 3: // Star
          _drawStar(canvas, paint, confettiSize);
          break;
      }
      
      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, Paint paint, double size) {
    final path = Path();
    final double radius = size / 2;
    final double innerRadius = radius * 0.4;
    
    for (int i = 0; i < 5; i++) {
      final double angle1 = (i * 72 - 90) * math.pi / 180;
      final double angle2 = ((i + 0.5) * 72 - 90) * math.pi / 180;
      
      if (i == 0) {
        path.moveTo(
          math.cos(angle1) * radius,
          math.sin(angle1) * radius,
        );
      } else {
        path.lineTo(
          math.cos(angle1) * radius,
          math.sin(angle1) * radius,
        );
      }
      
      path.lineTo(
        math.cos(angle2) * innerRadius,
        math.sin(angle2) * innerRadius,
      );
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
} 