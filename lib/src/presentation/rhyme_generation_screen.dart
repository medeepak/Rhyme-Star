import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data';
import '../theme.dart';

// Providers for managing rhyme generation state
final rhymeGenerationProgressProvider = StateProvider<double>((ref) => 0.0);
final rhymeGenerationStateProvider = StateProvider<String>((ref) => 'initializing');

class RhymeGenerationScreen extends ConsumerStatefulWidget {
  final dynamic rhyme; // Can be RhymeItem or CatalogRhymeItem
  final Uint8List? userAvatar;

  const RhymeGenerationScreen({
    super.key,
    required this.rhyme,
    this.userAvatar,
  });

  @override
  ConsumerState<RhymeGenerationScreen> createState() => _RhymeGenerationScreenState();
}

class _RhymeGenerationScreenState extends ConsumerState<RhymeGenerationScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _progressController = AnimationController(
      duration: const Duration(seconds: 30), // Simulate 30 second generation
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _pulseController.repeat(reverse: true);
    _startGeneration();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startGeneration() async {
    final stages = [
      {'progress': 0.2, 'message': 'Analyzing your avatar...', 'duration': 3},
      {'progress': 0.4, 'message': 'Creating 3D scene...', 'duration': 5},
      {'progress': 0.6, 'message': 'Adding character animations...', 'duration': 7},
      {'progress': 0.8, 'message': 'Rendering video...', 'duration': 10},
      {'progress': 1.0, 'message': 'Finalizing your rhyme...', 'duration': 5},
    ];

    for (var stage in stages) {
      if (!mounted) return;
      
      ref.read(rhymeGenerationStateProvider.notifier).state = stage['message'] as String;
      
      // Animate to the target progress
      await _progressController.animateTo(
        stage['progress'] as double,
        duration: Duration(seconds: stage['duration'] as int),
      );
      
      ref.read(rhymeGenerationProgressProvider.notifier).state = stage['progress'] as double;
    }

    // Generation complete
    ref.read(rhymeGenerationStateProvider.notifier).state = 'Complete!';
    
    // Navigate to video player after a brief delay
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      context.go('/video-player', extra: {
        'rhyme': widget.rhyme,
        'userAvatar': widget.userAvatar,
      });
    }
  }

  String get rhymeTitle {
    if (widget.rhyme is Map) {
      return widget.rhyme['title'] ?? 'Unknown Rhyme';
    }
    return widget.rhyme?.title ?? 'Unknown Rhyme';
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(rhymeGenerationProgressProvider);
    final state = ref.watch(rhymeGenerationStateProvider);
    
    return Scaffold(
      backgroundColor: RhymeStarColors.backgroundTeal,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Creating Your Rhyme',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Main content
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Avatar preview (if available)
                    if (widget.userAvatar != null)
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: RhymeStarColors.primaryTurquoise,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: RhymeStarColors.primaryTurquoise.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(47),
                            child: Image.memory(
                              widget.userAvatar!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // Rhyme title
                    Text(
                      rhymeTitle,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: RhymeStarColors.titleBlue,
                        fontSize: 24,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Progress circle
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background circle
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CircularProgressIndicator(
                              value: 1.0,
                              strokeWidth: 8,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation(Colors.grey[200]!),
                            ),
                          ),
                          // Progress circle
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 8,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation(RhymeStarColors.primaryTurquoise),
                            ),
                          ),
                          // Percentage text
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: RhymeStarColors.titleBlue,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Status message
                    Text(
                      state,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Additional info
                    Text(
                      'This may take a few moments...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Fun tip
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: RhymeStarColors.starYellow,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tip: Your personalized rhyme video will be ready to watch and share!',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 