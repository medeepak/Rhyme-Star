import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data';
import '../theme.dart';
import 'rhyme_confirmation_modal.dart';

// Providers for managing home screen state
final gemBalanceProvider = StateProvider<int>((ref) => 120); // Starting with 120 gems
final generatedAvatarProvider = StateProvider<Uint8List?>((ref) => null);
final createdRhymesProvider = StateProvider<List<String>>((ref) => []); // List of created rhyme IDs

// Rhyme data model
class RhymeItem {
  final String id;
  final String title;
  final String icon;
  final int gems;
  final String duration;
  final bool isPremium;

  RhymeItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.gems,
    required this.duration,
    this.isPremium = false,
  });
}

// Sample rhyme catalog
final rhymeCatalogProvider = Provider<List<RhymeItem>>((ref) => [
  RhymeItem(
    id: 'wheels_on_bus',
    title: 'Wheels on the Bus',
    icon: '🚌',
    gems: 30,
    duration: '45s',
  ),
  RhymeItem(
    id: 'johnny_johnny',
    title: 'Johnny Johnny Yes Papa',
    icon: '👶',
    gems: 30,
    duration: '30s',
  ),
  RhymeItem(
    id: 'baa_baa_black_sheep',
    title: 'Baa Baa Black Sheep',
    icon: '🐑',
    gems: 30,
    duration: '30s',
  ),
  RhymeItem(
    id: 'twinkle_little_star',
    title: 'Twinkle Twinkle Little Star',
    icon: '⭐',
    gems: 30,
    duration: '35s',
  ),
  RhymeItem(
    id: 'old_macdonald',
    title: 'Old MacDonald',
    icon: '🚜',
    gems: 30,
    duration: '40s',
  ),
  RhymeItem(
    id: 'mary_had_lamb',
    title: 'Mary Had a Little Lamb',
    icon: '🐑',
    gems: 30,
    duration: '25s',
  ),
]);

class HomeScreen extends ConsumerStatefulWidget {
  final Uint8List? userAvatar;

  const HomeScreen({Key? key, this.userAvatar}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Set the avatar if provided
    if (widget.userAvatar != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(generatedAvatarProvider.notifier).state = widget.userAvatar;
      });
    }
  }

  Future<void> _onRefresh() async {
    // Simulate refresh delay
    await Future.delayed(const Duration(seconds: 1));
    // In a real app, this would refresh gem balance and rhyme catalog from server
  }

  void _buyGems() {
    // TODO: Implement gem purchase flow
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buy Gems'),
        content: const Text('Gem purchase feature coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _createRhyme(RhymeItem rhyme) {
    final gems = ref.read(gemBalanceProvider);
    if (gems >= rhyme.gems) {
      // Show confirmation modal
      showRhymeConfirmationModal(
        context: context,
        rhyme: RhymeConfirmationData(
          id: rhyme.id,
          title: rhyme.title,
          thumbnail: rhyme.icon,
          gems: rhyme.gems,
          duration: rhyme.duration,
          quality: rhyme.isPremium ? 'High' : 'Standard',
          isPremium: rhyme.isPremium,
        ),
        onConfirm: () {
          // Deduct gems and mark as created
          ref.read(gemBalanceProvider.notifier).state = gems - rhyme.gems;
          ref.read(createdRhymesProvider.notifier).update((state) => [...state, rhyme.id]);
          
          // Navigate to rhyme generation screen
          context.go('/rhyme-generation', extra: {
            'rhyme': rhyme,
            'userAvatar': widget.userAvatar,
          });
        },
        onCancel: () {
          // User cancelled, do nothing
        },
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Not Enough Gems'),
          content: Text('You need ${rhyme.gems} gems to create this rhyme. Buy more gems!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/gem-store');
              },
              child: const Text('Buy Gems'),
            ),
          ],
        ),
      );
    }
  }

  void _navigateToCatalog() {
    print('Navigating to rhyme catalog');
    context.go('/rhyme-catalog', extra: {
      'userAvatar': widget.userAvatar,
    });
  }

  @override
  Widget build(BuildContext context) {
    final gemBalance = ref.watch(gemBalanceProvider);
    final userAvatar = ref.watch(generatedAvatarProvider);
    final rhymeCatalog = ref.watch(rhymeCatalogProvider);
    final createdRhymes = ref.watch(createdRhymesProvider);

    return Scaffold(
      backgroundColor: RhymeStarColors.backgroundTeal,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
                child: Row(
                  children: [
                    Icon(
                      Icons.menu,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Home Hub',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Avatar Display Area
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF87CEEB), // Light blue background
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Avatar with background scene
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF87CEEB),
                            Color(0xFF98FB98),
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Background hills
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: CustomPaint(
                              size: Size(double.infinity, 40),
                              painter: HillsPainter(),
                            ),
                          ),
                          // Clouds
                          Positioned(
                            top: 20,
                            left: 40,
                            child: Icon(Icons.cloud, color: Colors.white, size: 30),
                          ),
                          Positioned(
                            top: 15,
                            right: 60,
                            child: Icon(Icons.cloud, color: Colors.white, size: 20),
                          ),
                          // Avatar
                          Center(
                            child: userAvatar != null
                                ? ClipOval(
                                    child: Image.memory(
                                      userAvatar,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.orange[300],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.child_care,
                                      size: 40,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Gem Balance and Buy Button
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.diamond, color: RhymeStarColors.starYellow, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '$gemBalance',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _buyGems,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: RhymeStarColors.hillGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'BUY GEMS',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Colors.white,
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

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Promotional Banner
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: RhymeStarColors.starYellow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, color: RhymeStarColors.starOrange, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Try the 60-second version for extra fun!',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.black, size: 24),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Nursery Rhyme Catalog Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () => _navigateToCatalog(),
                  child: Row(
                    children: [
                      Text(
                        'Nursery rhyme catalog',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right, color: Colors.white, size: 24),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Rhyme Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75, // Increased height to prevent overflow
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final rhyme = rhymeCatalog[index];
                    final isCreated = createdRhymes.contains(rhyme.id);
                    
                    return RhymeCard(
                      rhyme: rhyme,
                      isCreated: isCreated,
                      onTap: () => _createRhyme(rhyme),
                    );
                  },
                  childCount: rhymeCatalog.length,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 60)), // Increased bottom padding
          ],
        ),
      ),
    );
  }
}

class RhymeCard extends StatelessWidget {
  final RhymeItem rhyme;
  final bool isCreated;
  final VoidCallback onTap;

  const RhymeCard({
    Key? key,
    required this.rhyme,
    required this.isCreated,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon and status area
            Flexible(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      RhymeStarColors.primaryTurquoise.withOpacity(0.3),
                      RhymeStarColors.hillGreen.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        rhyme.icon,
                        style: const TextStyle(fontSize: 44), // Slightly smaller icon
                      ),
                    ),
                    if (isCreated)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: RhymeStarColors.hillGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    // Gem cost badge
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: RhymeStarColors.starYellow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${rhyme.gems}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.diamond,
                              color: RhymeStarColors.starOrange,
                              size: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Title and duration
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rhyme.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.black,
                      fontSize: 13,
                      height: 1.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rhyme.duration,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HillsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = RhymeStarColors.hillGreen
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(size.width * 0.3, 0, size.width * 0.6, size.height * 0.3);
    path.quadraticBezierTo(size.width * 0.8, size.height * 0.6, size.width, 0);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
