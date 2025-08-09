import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../theme.dart';
import '../env.dart';

// Providers for avatar generation state
final avatarGenerationProgressProvider = StateProvider<double>((ref) => 0.0);
final isGeneratingAvatarProvider = StateProvider<bool>((ref) => false);
final generatedAvatarProvider = StateProvider<Uint8List?>((ref) => null);
final avatarGenerationErrorProvider = StateProvider<String?>((ref) => null);

// Configuration providers - to be filled by user
final chatgptApiKeyProvider = StateProvider<String>((ref) => (Env.openAiKey ?? ''));
final avatarPromptProvider = StateProvider<String>((ref) => 
  'Convert this child photo to a cute 3D Cocomelon character like avatar in Cocomelon style. '
  'Make it family-friendly, colorful, and appealing to young children. '
  'The avatar should have big expressive eyes, soft rounded features, '
  'and maintain the child\'s basic appearance while making it cartoon-like.');

class AvatarGenerationScreen extends ConsumerStatefulWidget {
  final Uint8List? uploadedImage;
  final String childName;

  const AvatarGenerationScreen({
    super.key,
    required this.uploadedImage,
    required this.childName,
  });

  @override
  ConsumerState<AvatarGenerationScreen> createState() => _AvatarGenerationScreenState();
}

class _AvatarGenerationScreenState extends ConsumerState<AvatarGenerationScreen>
    with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late AnimationController _pulseController;
  late Animation<double> _confettiAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _confettiController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _confettiAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _confettiController, curve: Curves.linear),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start avatar generation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAvatarGeneration();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startAvatarGeneration() async {
    if (widget.uploadedImage == null) return;

    ref.read(isGeneratingAvatarProvider.notifier).state = true;
    ref.read(avatarGenerationProgressProvider.notifier).state = 0.0;
    ref.read(avatarGenerationErrorProvider.notifier).state = null;

    try {
      // Progress: 0-30% - Initial setup and photo analysis
      for (int i = 0; i <= 30; i += 5) {
        if (!mounted) return;
        ref.read(avatarGenerationProgressProvider.notifier).state = i / 100;
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Call ChatGPT API to generate the avatar
      await _callChatGPTAPI();

      // Progress: 30-100% - Avatar generation complete
      for (int i = 30; i <= 100; i += 10) {
        if (!mounted) return;
        ref.read(avatarGenerationProgressProvider.notifier).state = i / 100;
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
    } catch (e) {
      ref.read(avatarGenerationErrorProvider.notifier).state = 
        'Failed to generate avatar: ${e.toString()}';
    } finally {
      ref.read(isGeneratingAvatarProvider.notifier).state = false;
    }
  }

  Future<void> _callChatGPTAPI() async {
    final apiKey = ref.read(chatgptApiKeyProvider);
    final prompt = ref.read(avatarPromptProvider);
    
    if (widget.uploadedImage == null) {
      throw Exception('No image uploaded');
    }
    
    try {
      // Step 1: Use GPT-4o Vision to analyze the uploaded photo
      ref.read(avatarGenerationProgressProvider.notifier).state = 0.4; // 40%
      final base64Image = base64Encode(widget.uploadedImage!);
      
      final visionResponse = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': '''Analyze this child's photo and create a detailed description for generating a Cocomelon-style 3D cartoon avatar. Focus on:
- Hair color, style, and length
- Eye color and shape
- Skin tone
- Facial features and expressions
- Any distinctive characteristics
- Gender presentation

Create a DALL-E prompt that will generate a cute, family-friendly 3D cartoon avatar in Cocomelon animation style based on this child's features.'''
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image'
                  }
                }
              ]
            }
          ],
          'max_tokens': 300
        }),
      );

      if (visionResponse.statusCode != 200) {
        final errorData = jsonDecode(visionResponse.body);
        throw Exception('Vision API Error: ${errorData['error']['message']}');
      }

      final visionData = jsonDecode(visionResponse.body);
      final childDescription = visionData['choices'][0]['message']['content'];

      // Step 2: Use DALL-E 3 with detailed description from vision analysis
      ref.read(avatarGenerationProgressProvider.notifier).state = 0.7; // 70%
      final enhancedPrompt = '''Create a cute 3D Cocomelon-style cartoon avatar based on this description:

$childDescription

Style requirements:
- 3D cartoon animation style like Cocomelon characters
- Big, round, expressive cartoon eyes 
- Soft, rounded facial features
- Bright, vibrant, child-friendly colors
- Warm, happy, friendly smile
- Clean, professional quality suitable for children's videos
- Smooth, soft textures and lighting
- Simple, appealing design that children would love

Important: Maintain all the key physical characteristics described above while transforming into cartoon style.''';

      final imageResponse = await http.post(
        Uri.parse('https://api.openai.com/v1/images/generations'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'dall-e-3',
          'prompt': enhancedPrompt,
          'n': 1,
          'size': '1024x1024',
          'response_format': 'b64_json',
          'quality': 'hd',
          'style': 'vivid',
        }),
      );

      if (imageResponse.statusCode == 200) {
        final imageData = jsonDecode(imageResponse.body);
        final generatedImageB64 = imageData['data'][0]['b64_json'];
        final generatedImageBytes = base64Decode(generatedImageB64);
        
        // Set the generated avatar
        ref.read(generatedAvatarProvider.notifier).state = generatedImageBytes;
      } else {
        final errorData = jsonDecode(imageResponse.body);
        throw Exception('DALL-E API Error: ${errorData['error']['message']}');
      }
    } catch (e) {
      print('ChatGPT API Error: $e');
      // Fallback to original image in case of error, but show error message
      ref.read(generatedAvatarProvider.notifier).state = widget.uploadedImage;
      throw Exception('Failed to generate avatar: ${e.toString()}');
    }
  }

  Future<void> _regenerateAvatar() async {
    ref.read(generatedAvatarProvider.notifier).state = null;
    await _startAvatarGeneration();
  }

  Future<void> _confirmAvatar() async {
    // Save avatar to preferences and navigate to home screen
    final box = await Hive.openBox('rhyme_star_prefs');
    await box.put('child_name', widget.childName);
    await box.put('has_uploaded_photo', true);
    await box.put('has_generated_avatar', true);
    
    final generatedAvatar = ref.read(generatedAvatarProvider);
    
    if (mounted) {
      context.go('/home', extra: {
        'userAvatar': generatedAvatar,
        'childName': widget.childName,
      }); // Navigate to home screen
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGenerating = ref.watch(isGeneratingAvatarProvider);
    final progress = ref.watch(avatarGenerationProgressProvider);
    final generatedAvatar = ref.watch(generatedAvatarProvider);
    final error = ref.watch(avatarGenerationErrorProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isGenerating || generatedAvatar == null
                ? [
                    const Color(0xFF8E24AA), // Purple
                    const Color(0xFF5E35B1), // Deeper purple
                  ]
                : [
                    const Color(0xFF26C6DA), // Turquoise
                    const Color(0xFF00BCD4), // Cyan
                  ],
          ),
        ),
        child: SafeArea(
          child: isGenerating || generatedAvatar == null
              ? _buildGenerationView(progress, error)
              : _buildResultView(generatedAvatar),
        ),
      ),
    );
  }

  Widget _buildGenerationView(double progress, String? error) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return CustomPaint(
      painter: GenerationConfettiPainter(_confettiAnimation.value),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 24 : 48,
          vertical: isSmallScreen ? 32 : 48,
        ),
        child: Column(
          children: [
            // Step indicator
            Text(
              'STEP 2 OF 2',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            
            SizedBox(height: isSmallScreen ? 24 : 32),

            // Title
            Text(
              'Creating\nAvatar...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFFDD835), // Yellow
                fontSize: isSmallScreen ? 32 : 48,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),

            const Spacer(),

            // Animated Character
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: isSmallScreen ? 180 : 240,
                    height: isSmallScreen ? 180 : 240,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0xFF81C784), // Light green
                          Color(0xFF4CAF50), // Green
                        ],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: isSmallScreen ? 120 : 160,
                        height: isSmallScreen ? 120 : 160,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFE0B2), // Peach face
                          shape: BoxShape.circle,
                        ),
                        child: Stack(
                          children: [
                            // Eyes
                            Positioned(
                              left: isSmallScreen ? 25 : 35,
                              top: isSmallScreen ? 35 : 45,
                              child: Container(
                                width: isSmallScreen ? 20 : 25,
                                height: isSmallScreen ? 20 : 25,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Container(
                                    width: isSmallScreen ? 8 : 10,
                                    height: isSmallScreen ? 8 : 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: isSmallScreen ? 25 : 35,
                              top: isSmallScreen ? 35 : 45,
                              child: Container(
                                width: isSmallScreen ? 20 : 25,
                                height: isSmallScreen ? 20 : 25,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Container(
                                    width: isSmallScreen ? 8 : 10,
                                    height: isSmallScreen ? 8 : 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Smile
                            Positioned(
                              left: isSmallScreen ? 40 : 55,
                              bottom: isSmallScreen ? 40 : 50,
                              child: Container(
                                width: isSmallScreen ? 40 : 50,
                                height: isSmallScreen ? 20 : 25,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE91E63), // Pink smile
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(50),
                                    bottomRight: Radius.circular(50),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const Spacer(),

            // Progress Bar
            Container(
              width: double.infinity,
              height: isSmallScreen ? 12 : 16,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: MediaQuery.of(context).size.width * 0.8 * progress,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF4CAF50), // Green
                          Color(0xFF81C784), // Light green
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: isSmallScreen ? 16 : 24),

            // Progress text
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 16 : 20,
                fontWeight: FontWeight.w900,
              ),
            ),

            if (error != null) ...[
              SizedBox(height: isSmallScreen ? 16 : 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  error,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            SizedBox(height: isSmallScreen ? 32 : 48),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView(Uint8List avatarData) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return CustomPaint(
      painter: ResultConfettiPainter(_confettiAnimation.value),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 24 : 48,
          vertical: isSmallScreen ? 32 : 48,
        ),
        child: Column(
          children: [
            // Title
            Text(
              'Your Avatar',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 28 : 36,
                fontWeight: FontWeight.w900,
              ),
            ),

            SizedBox(height: isSmallScreen ? 32 : 48),

            // Avatar with rainbow background
            Container(
              width: isSmallScreen ? 280 : 360,
              height: isSmallScreen ? 280 : 360,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF5722), // Red-orange
                    Color(0xFFFF9800), // Orange
                    Color(0xFFFFC107), // Yellow
                    Color(0xFF4CAF50), // Green
                    Color(0xFF2196F3), // Blue
                    Color(0xFF9C27B0), // Purple
                  ],
                ),
              ),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: MemoryImage(avatarData),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Buttons
            Column(
              children: [
                // Confirm button
                SizedBox(
                  width: double.infinity,
                  height: isSmallScreen ? 56 : 64,
                  child: ElevatedButton(
                    onPressed: _confirmAvatar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50), // Green
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 8,
                    ),
                    child: Text(
                      'Confirm',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 18 : 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: isSmallScreen ? 16 : 20),

                // Regenerate button
                SizedBox(
                  width: double.infinity,
                  height: isSmallScreen ? 56 : 64,
                  child: ElevatedButton(
                    onPressed: _regenerateAvatar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50), // Green
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Regenerate',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 18 : 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.diamond,
                          color: const Color(0xFF26C6DA), // Cyan
                          size: isSmallScreen ? 20 : 24,
                        ),
                        Text(
                          '10',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 18 : 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: isSmallScreen ? 32 : 48),
          ],
        ),
      ),
    );
  }
}

class GenerationConfettiPainter extends CustomPainter {
  final double animationValue;

  GenerationConfettiPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final random = math.Random(42); // Fixed seed for consistent pattern

    for (int i = 0; i < 25; i++) {
      final x = random.nextDouble() * size.width;
      final y = (random.nextDouble() * size.height + animationValue * size.height) % size.height;
      final color = [
        const Color(0xFFFFC107), // Yellow
        const Color(0xFFFF9800), // Orange
        const Color(0xFFE91E63), // Pink
        const Color(0xFF4CAF50), // Green
        const Color(0xFF2196F3), // Blue
      ][i % 5];

      paint.color = color.withOpacity(0.8);

      if (i % 3 == 0) {
        // Star
        _drawStar(canvas, paint, Offset(x, y), 8);
      } else if (i % 3 == 1) {
        // Circle
        canvas.drawCircle(Offset(x, y), 6, paint);
      } else {
        // Diamond
        _drawDiamond(canvas, paint, Offset(x, y), 8);
      }
    }
  }

  void _drawStar(Canvas canvas, Paint paint, Offset center, double size) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 2 * math.pi / 5) - math.pi / 2;
      final x = center.dx + math.cos(angle) * size;
      final y = center.dy + math.sin(angle) * size;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawDiamond(Canvas canvas, Paint paint, Offset center, double size) {
    final path = Path();
    path.moveTo(center.dx, center.dy - size);
    path.lineTo(center.dx + size, center.dy);
    path.lineTo(center.dx, center.dy + size);
    path.lineTo(center.dx - size, center.dy);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(GenerationConfettiPainter oldDelegate) {
    return animationValue != oldDelegate.animationValue;
  }
}

class ResultConfettiPainter extends CustomPainter {
  final double animationValue;

  ResultConfettiPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final random = math.Random(84); // Different seed for result view

    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = (random.nextDouble() * size.height + animationValue * size.height * 0.5) % size.height;
      final color = [
        const Color(0xFFFF5722), // Red-orange
        const Color(0xFFFF9800), // Orange
        const Color(0xFFFFC107), // Yellow
        const Color(0xFF4CAF50), // Green
        const Color(0xFF2196F3), // Blue
        const Color(0xFF9C27B0), // Purple
      ][i % 6];

      paint.color = color.withOpacity(0.7);

      if (i % 4 == 0) {
        // Star
        _drawStar(canvas, paint, Offset(x, y), 6);
      } else if (i % 4 == 1) {
        // Circle
        canvas.drawCircle(Offset(x, y), 4, paint);
      } else if (i % 4 == 2) {
        // Diamond
        _drawDiamond(canvas, paint, Offset(x, y), 6);
      } else {
        // Triangle
        _drawTriangle(canvas, paint, Offset(x, y), 6);
      }
    }
  }

  void _drawStar(Canvas canvas, Paint paint, Offset center, double size) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 2 * math.pi / 5) - math.pi / 2;
      final x = center.dx + math.cos(angle) * size;
      final y = center.dy + math.sin(angle) * size;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawDiamond(Canvas canvas, Paint paint, Offset center, double size) {
    final path = Path();
    path.moveTo(center.dx, center.dy - size);
    path.lineTo(center.dx + size, center.dy);
    path.lineTo(center.dx, center.dy + size);
    path.lineTo(center.dx - size, center.dy);
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawTriangle(Canvas canvas, Paint paint, Offset center, double size) {
    final path = Path();
    path.moveTo(center.dx, center.dy - size);
    path.lineTo(center.dx + size, center.dy + size);
    path.lineTo(center.dx - size, center.dy + size);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ResultConfettiPainter oldDelegate) {
    return animationValue != oldDelegate.animationValue;
  }
} 