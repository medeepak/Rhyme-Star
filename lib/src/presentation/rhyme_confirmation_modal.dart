import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as Math;
import '../theme.dart';

// Rhyme data model for the modal
class RhymeConfirmationData {
  final String id;
  final String title;
  final String thumbnail;
  final int gems;
  final String duration;
  final String quality;
  final bool isPremium;

  RhymeConfirmationData({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.gems,
    required this.duration,
    required this.quality,
    this.isPremium = false,
  });
}

class RhymeConfirmationModal extends ConsumerStatefulWidget {
  final RhymeConfirmationData rhyme;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const RhymeConfirmationModal({
    super.key,
    required this.rhyme,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  ConsumerState<RhymeConfirmationModal> createState() => _RhymeConfirmationModalState();
}

class _RhymeConfirmationModalState extends ConsumerState<RhymeConfirmationModal>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _sparkleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _sparkleAnimation;

  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    _sparkleAnimation = CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.linear,
    );

    _scaleController.forward();
    _sparkleController.repeat();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5DC), // Beige background
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gem icon with sparkles
                SizedBox(
                  height: 120,
                  width: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Animated sparkles
                      AnimatedBuilder(
                        animation: _sparkleAnimation,
                        builder: (context, child) {
                          return CustomPaint(
                            size: const Size(120, 120),
                            painter: SparklesPainter(_sparkleAnimation.value),
                          );
                        },
                      ),
                      // Main gem icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFDD835), // Bright yellow
                              Color(0xFFFFB300), // Orange-yellow
                              Color(0xFFF57C00), // Orange
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: RhymeStarColors.starYellow.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.diamond,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Title
                Text(
                  'Spend ${widget.rhyme.gems} Gems?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.black87,
                    fontSize: 24,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Details section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      // Runtime and Quality row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Runtime',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            widget.rhyme.duration,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Quality',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            widget.rhyme.quality,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Divider
                      Container(
                        height: 1,
                        color: Colors.black26,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Total row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.black87,
                              fontSize: 18,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '${widget.rhyme.gems}',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.black87,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                '💎',
                                style: TextStyle(fontSize: 18),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Buttons
                Column(
                  children: [
                    // Confirm button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onConfirm();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RhymeStarColors.hillGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 4,
                        ),
                        child: Text(
                          'Yes, Make My Rhyme!',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Cancel button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onCancel();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE57373), // Light red
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 4,
                        ),
                        child: Text(
                          'Cancel',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom painter for animated sparkles around the gem
class SparklesPainter extends CustomPainter {
  final double animationValue;

  SparklesPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = 50.0;

    // Define sparkle positions and colors
    final sparkles = [
      {'angle': 0.0, 'distance': 45.0, 'color': RhymeStarColors.starYellow, 'size': 4.0},
      {'angle': 0.5, 'distance': 50.0, 'color': RhymeStarColors.starOrange, 'size': 3.0},
      {'angle': 1.0, 'distance': 40.0, 'color': RhymeStarColors.starPink, 'size': 5.0},
      {'angle': 1.5, 'distance': 55.0, 'color': RhymeStarColors.starGreen, 'size': 3.5},
      {'angle': 2.0, 'distance': 42.0, 'color': RhymeStarColors.starYellow, 'size': 4.5},
      {'angle': 2.5, 'distance': 48.0, 'color': RhymeStarColors.starOrange, 'size': 3.0},
      {'angle': 3.0, 'distance': 52.0, 'color': RhymeStarColors.starPink, 'size': 4.0},
      {'angle': 3.5, 'distance': 38.0, 'color': RhymeStarColors.starGreen, 'size': 3.5},
    ];

    for (var sparkle in sparkles) {
      final angle = (sparkle['angle'] as double) + (animationValue * 6.28); // Full rotation
      final distance = sparkle['distance'] as double;
      final color = sparkle['color'] as Color;
      final sparkleSize = sparkle['size'] as double;

      final x = center.dx + (distance * Math.cos(angle));
      final y = center.dy + (distance * Math.sin(angle));

      paint.color = color.withOpacity(0.7 + 0.3 * Math.sin(animationValue * 6.28));
      
      // Draw sparkle as a diamond shape
      _drawSparkle(canvas, Offset(x, y), sparkleSize, paint);
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    path.moveTo(center.dx, center.dy - size); // Top
    path.lineTo(center.dx + size, center.dy); // Right
    path.lineTo(center.dx, center.dy + size); // Bottom
    path.lineTo(center.dx - size, center.dy); // Left
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
  }

// Helper function to show the modal
void showRhymeConfirmationModal({
  required BuildContext context,
  required RhymeConfirmationData rhyme,
  required VoidCallback onConfirm,
  VoidCallback? onCancel,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => RhymeConfirmationModal(
      rhyme: rhyme,
      onConfirm: onConfirm,
      onCancel: onCancel ?? () {},
    ),
  );
} 