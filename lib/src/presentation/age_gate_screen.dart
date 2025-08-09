import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme.dart';
import 'dart:math' as math;

// Provider for checkbox state
final ageGateCheckboxProvider = StateProvider<bool>((ref) => false);

class AgeGateScreen extends ConsumerStatefulWidget {
  const AgeGateScreen({super.key});

  @override
  ConsumerState<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends ConsumerState<AgeGateScreen>
    with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late AnimationController _fadeController;
  late Animation<double> _confettiAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _confettiController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
    
    _fadeController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    _confettiAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _confettiController,
      curve: Curves.linear,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    
    _fadeController.forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    // Mark that user has seen age gate
    final box = await Hive.openBox('rhyme_star_prefs');
    await box.put('has_seen_age_gate', true);
    await box.put('coppa_consent_given', true);
    
    if (mounted) {
      context.go('/intro-carousel');
    }
  }

  void _handleDecline() {
    // Exit the app
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isCheckboxChecked = ref.watch(ageGateCheckboxProvider);
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1024;
    
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_confettiAnimation, _fadeAnimation]),
        builder: (context, child) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFA726), // Orange
                  Color(0xFFFFCC02), // Yellow
                ],
              ),
            ),
            child: Stack(
              children: [
                // Animated Confetti Background
                CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: ConfettiPainter(_confettiAnimation.value, isSmallScreen),
                ),
                
                // Main Content
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 20 : (isTablet ? 40 : 60),
                      vertical: isSmallScreen ? 16 : 24,
                    ),
                    child: Column(
                      children: [
                        Spacer(flex: isSmallScreen ? 1 : 2),
                        
                        // Title
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Text(
                            'Grown-up\nCheck',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 32 : (isTablet ? 40 : 48),
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
                        ),
                        
                        SizedBox(height: isSmallScreen ? 20 : 40),
                        
                        // Character with Shield
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: PumpkinCharacter(
                            size: isSmallScreen ? 100 : (isTablet ? 130 : 160),
                          ),
                        ),
                        
                        Spacer(flex: isSmallScreen ? 2 : 3),
                        
                        // Terms Checkbox
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                              boxShadow: [
                                BoxShadow(
                                  offset: const Offset(0, 4),
                                  blurRadius: 12,
                                  color: Colors.black.withOpacity(0.1),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    ref.read(ageGateCheckboxProvider.notifier).state = !isCheckboxChecked;
                                  },
                                  child: Container(
                                    width: isSmallScreen ? 20 : 24,
                                    height: isSmallScreen ? 20 : 24,
                                    margin: EdgeInsets.only(top: isSmallScreen ? 2 : 4),
                                    decoration: BoxDecoration(
                                      color: isCheckboxChecked ? const Color(0xFF4FC3F7) : Colors.white,
                                      border: Border.all(
                                        color: const Color(0xFF4FC3F7),
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: isCheckboxChecked
                                        ? Icon(
                                            Icons.check,
                                            size: isSmallScreen ? 12 : 16,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                ),
                                SizedBox(width: isSmallScreen ? 12 : 16),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 14 : 16,
                                        color: Colors.black87,
                                        height: 1.4,
                                      ),
                                      children: const [
                                        TextSpan(text: 'I have read and agree to\n'),
                                        TextSpan(
                                          text: 'Terms of Service',
                                          style: TextStyle(
                                            color: Color(0xFF1976D2),
                                            decoration: TextDecoration.underline,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        TextSpan(text: ' and\n'),
                                        TextSpan(
                                          text: 'Privacy Policy',
                                          style: TextStyle(
                                            color: Color(0xFF1976D2),
                                            decoration: TextDecoration.underline,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        SizedBox(height: isSmallScreen ? 24 : 32),
                        
                        // Buttons
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Column(
                            children: [
                              // Continue Button
                              SizedBox(
                                width: double.infinity,
                                height: isSmallScreen ? 48 : 56,
                                child: ElevatedButton(
                                  onPressed: isCheckboxChecked ? _handleContinue : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isCheckboxChecked 
                                        ? const Color(0xFF66BB6A) 
                                        : Colors.grey[400],
                                    foregroundColor: Colors.white,
                                    elevation: isCheckboxChecked ? 8 : 2,
                                    shadowColor: Colors.black.withOpacity(0.3),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(isSmallScreen ? 24 : 28),
                                    ),
                                  ),
                                  child: Text(
                                    'CONTINUE',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 16 : 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                              
                              SizedBox(height: isSmallScreen ? 12 : 16),
                              
                              // Decline Button (subtle)
                              TextButton(
                                onPressed: _handleDecline,
                                child: Text(
                                  'Decline',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 12 : 14,
                                    color: Colors.white.withOpacity(0.8),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        Spacer(flex: isSmallScreen ? 1 : 1),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class PumpkinCharacter extends StatelessWidget {
  final double size;
  
  const PumpkinCharacter({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final double pumpkinSize = size * 0.75;
    final double faceSize = pumpkinSize * 0.67;
    final double shieldSize = size * 0.31;
    
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pumpkin Body
          Container(
            width: pumpkinSize,
            height: pumpkinSize,
            decoration: const BoxDecoration(
              color: Color(0xFF66BB6A), // Green pumpkin
              shape: BoxShape.circle,
            ),
          ),
          
          // Pumpkin ridges
          for (int i = 0; i < 6; i++)
            Positioned(
              left: (size - pumpkinSize) / 2 + (i * (pumpkinSize / 6.5)),
              top: (size - pumpkinSize) / 2,
              child: Container(
                width: 2,
                height: pumpkinSize * 0.67,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          
          // Stem
          Positioned(
            top: (size - pumpkinSize) / 2 - size * 0.05,
            child: Container(
              width: size * 0.05,
              height: size * 0.125,
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ),
          ),
          
          // Face background (white area)
          Positioned(
            child: Container(
              width: faceSize,
              height: faceSize,
              decoration: const BoxDecoration(
                color: Color(0xFFFFDBB5), // Skin tone
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          // Eyes
          Positioned(
            top: size * 0.28,
            left: size * 0.22,
            child: Container(
              width: size * 0.075,
              height: size * 0.075,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: size * 0.28,
            right: size * 0.22,
            child: Container(
              width: size * 0.075,
              height: size * 0.075,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          // Smile
          Positioned(
            top: size * 0.44,
            child: Container(
              width: size * 0.19,
              height: size * 0.09,
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
              ),
            ),
          ),
          
          // Security Shield
          Positioned(
            right: size * 0.03,
            bottom: size * 0.06,
            child: Container(
              width: shieldSize,
              height: shieldSize * 1.2,
              decoration: const BoxDecoration(
                color: Color(0xFF2196F3),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                  bottomLeft: Radius.circular(5),
                  bottomRight: Radius.circular(5),
                ),
              ),
              child: Icon(
                Icons.check,
                color: Colors.white,
                size: shieldSize * 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConfettiPainter extends CustomPainter {
  final double animation;
  final bool isSmallScreen;
  
  ConfettiPainter(this.animation, this.isSmallScreen);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final random = math.Random(123); // Fixed seed for consistent pattern
    final confettiCount = isSmallScreen ? 50 : 80;
    
    // Generate confetti at fixed positions
    for (int i = 0; i < confettiCount; i++) {
      final x = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height - 100;
      final fallSpeed = 0.5 + random.nextDouble() * 2;
      final y = (startY + (animation * size.height * fallSpeed)) % (size.height + 100);
      
      final confettiSize = (isSmallScreen ? 3.0 : 4.0) + random.nextDouble() * (isSmallScreen ? 6.0 : 8.0);
      final shape = random.nextInt(3); // 0: circle, 1: square, 2: triangle
      final colorIndex = random.nextInt(6);
      
      // Rotate confetti
      final rotation = animation * 2 * math.pi + i;
      
      Color confettiColor;
      switch (colorIndex) {
        case 0:
          confettiColor = const Color(0xFF4FC3F7); // Blue
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
        case 4:
          confettiColor = const Color(0xFF9C27B0); // Purple
          break;
        default:
          confettiColor = const Color(0xFFFFC107); // Yellow
      }
      
      paint.color = confettiColor.withOpacity(0.8);
      
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
      }
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
} 