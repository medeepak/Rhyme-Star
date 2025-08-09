import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data';
import '../theme.dart';
import 'rhyme_confirmation_modal.dart';

// Providers for managing catalog state
final catalogSearchProvider = StateProvider<String>((ref) => '');
final userAvatarCatalogProvider = StateProvider<Uint8List?>((ref) => null);
final gemBalanceCatalogProvider = StateProvider<int>((ref) => 120);
final createdRhymesCatalogProvider = StateProvider<List<String>>((ref) => []);

// Extended Rhyme data model for catalog
class CatalogRhymeItem {
  final String id;
  final String title;
  final String illustration;
  final int gems;
  final String duration;
  final bool isPremium;
  final Color primaryColor;
  final Color secondaryColor;

  CatalogRhymeItem({
    required this.id,
    required this.title,
    required this.illustration,
    required this.gems,
    required this.duration,
    this.isPremium = false,
    required this.primaryColor,
    required this.secondaryColor,
  });
}

class RhymeCatalogScreen extends ConsumerStatefulWidget {
  final Uint8List? userAvatar;

  const RhymeCatalogScreen({
    Key? key,
    this.userAvatar,
  }) : super(key: key);

  @override
  ConsumerState<RhymeCatalogScreen> createState() => _RhymeCatalogScreenState();
}

class _RhymeCatalogScreenState extends ConsumerState<RhymeCatalogScreen> {
  final List<CatalogRhymeItem> allRhymes = [
    CatalogRhymeItem(
      id: 'baa_baa_black_sheep',
      title: 'Baa Baa Black Sheep',
      illustration: '🐑🚗',
      gems: 30,
      duration: '20s',
      primaryColor: Color(0xFF87CEEB),
      secondaryColor: Color(0xFF98FB98),
    ),
    CatalogRhymeItem(
      id: 'wheels_on_the_bus',
      title: 'Wheels on the Bus',
      illustration: '⭐🎵',
      gems: 20,
      duration: '20s',
      primaryColor: Color(0xFF98FB98),
      secondaryColor: Color(0xFFFFE135),
    ),
    CatalogRhymeItem(
      id: 'twinkle_twinkle',
      title: 'Twinkle Twinkle Little Star',
      illustration: '⭐🌙',
      gems: 60,
      duration: '20s',
      primaryColor: Color(0xFF87CEEB),
      secondaryColor: Color(0xFFFFE135),
    ),
    CatalogRhymeItem(
      id: 'old_macdonald',
      title: 'Old MacDonald Had a Farm',
      illustration: '👦🌾',
      gems: 20,
      duration: '20s',
      primaryColor: Color(0xFF4169E1),
      secondaryColor: Color(0xFFFFE135),
    ),
    CatalogRhymeItem(
      id: 'mary_had_lamb',
      title: 'Mary Had a Little Lamb',
      illustration: '🐑👧',
      gems: 30,
      duration: '30s',
      primaryColor: Color(0xFF87CEEB),
      secondaryColor: Color(0xFFDDA0DD),
    ),
    CatalogRhymeItem(
      id: 'abc_song',
      title: 'ABC Song',
      illustration: '👦👧',
      gems: 30,
      duration: '20s',
      primaryColor: Color(0xFFFF8C69),
      secondaryColor: Color(0xFFFFE135),
    ),
  ];

  List<CatalogRhymeItem> get filteredRhymes {
    final searchQuery = ref.watch(catalogSearchProvider).toLowerCase();
    print('Search query: "$searchQuery"');
    if (searchQuery.isEmpty) {
      print('Returning all ${allRhymes.length} rhymes');
      return allRhymes;
    }
    final filtered = allRhymes.where((rhyme) => 
      rhyme.title.toLowerCase().contains(searchQuery)
    ).toList();
    print('Filtered to ${filtered.length} rhymes');
    return filtered;
  }

  void _handleRhymeTap(CatalogRhymeItem rhyme) {
    final gems = ref.read(gemBalanceCatalogProvider);
    final createdRhymes = ref.read(createdRhymesCatalogProvider);
    
    // Check if already created
    if (createdRhymes.contains(rhyme.id)) {
      // Navigate to playback screen
      context.go('/video-player', extra: {
        'rhyme': rhyme,
        'userAvatar': widget.userAvatar,
      });
      return;
    }
    
    if (gems >= rhyme.gems) {
      // Show confirmation modal
      showRhymeConfirmationModal(
        context: context,
        rhyme: RhymeConfirmationData(
          id: rhyme.id,
          title: rhyme.title,
          thumbnail: rhyme.illustration,
          gems: rhyme.gems,
          duration: rhyme.duration,
          quality: rhyme.isPremium ? 'High' : 'Standard',
          isPremium: rhyme.isPremium,
        ),
        onConfirm: () {
          // Deduct gems and mark as created
          ref.read(gemBalanceCatalogProvider.notifier).state = gems - rhyme.gems;
          ref.read(createdRhymesCatalogProvider.notifier).update((state) => [...state, rhyme.id]);
          
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

  @override
  void initState() {
    super.initState();
    // Set the avatar if provided
    if (widget.userAvatar != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(userAvatarCatalogProvider.notifier).state = widget.userAvatar;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(catalogSearchProvider);
    final userAvatar = ref.watch(userAvatarCatalogProvider);
    final gemBalance = ref.watch(gemBalanceCatalogProvider);
    final createdRhymes = ref.watch(createdRhymesCatalogProvider);
    
    return Scaffold(
      backgroundColor: const Color(0xFF4FC3F7), // Turquoise background
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () {
                      print('Back button tapped - navigating to home');
                      context.go('/home', extra: {
                        'userAvatar': widget.userAvatar,
                      });
                    },
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
                  
                  // Title
                  Expanded(
                    child: Text(
                      'Rhyme Catalog',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Search button
                  GestureDetector(
                    onTap: () {
                      print('Search button tapped');
                      _showSearchDialog();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: const Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content area with beige background
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5DC), // Beige background
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    
                    // Avatar and Gem Balance (optional, shown when available)
                    if (userAvatar != null || gemBalance > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            // Avatar
                            if (userAvatar != null)
                              ClipOval(
                                child: Image.memory(
                                  userAvatar,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            
                            const Spacer(),
                            
                            // Gem balance
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.diamond,
                                    color: RhymeStarColors.starYellow,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$gemBalance',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    if (userAvatar != null || gemBalance > 0)
                      const SizedBox(height: 16),
                    
                    // Search results info
                    if (searchQuery.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                color: Colors.blue[700],
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Search results for "$searchQuery" (${filteredRhymes.length} found)',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  print('Clearing search');
                                  ref.read(catalogSearchProvider.notifier).state = '';
                                },
                                icon: const Icon(Icons.clear, size: 16),
                                label: const Text('Clear'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // Rhymes Grid
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: GridView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filteredRhymes.length,
                          itemBuilder: (context, index) {
                            final rhyme = filteredRhymes[index];
                            final isCreated = createdRhymes.contains(rhyme.id);
                            
                            return CatalogRhymeCard(
                              rhyme: rhyme,
                              isCreated: isCreated,
                              onTap: () => _handleRhymeTap(rhyme),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog() {
    final TextEditingController searchController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Search Rhymes'),
        content: SizedBox(
          width: 300,
          child: TextField(
            controller: searchController,
            onChanged: (value) {
              try {
                ref.read(catalogSearchProvider.notifier).state = value;
              } catch (e) {
                print('Search update error: $e');
              }
            },
            decoration: const InputDecoration(
              hintText: 'Enter rhyme name...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              searchController.clear();
              ref.read(catalogSearchProvider.notifier).state = '';
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class CatalogRhymeCard extends StatelessWidget {
  final CatalogRhymeItem rhyme;
  final bool isCreated;
  final VoidCallback onTap;

  const CatalogRhymeCard({
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
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Illustration area
            Expanded(
              flex: 4,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      rhyme.primaryColor,
                      rhyme.secondaryColor,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Stack(
                  children: [
                    // Main illustration
                    Center(
                      child: Text(
                        rhyme.illustration,
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                    
                    // Gem cost badge
                    Positioned(
                      top: 8,
                      right: 8,
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
                              size: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Created indicator
                    if (isCreated)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: RhymeStarColors.hillGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Title and duration
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const Spacer(),
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
            ),
          ],
        ),
      ),
    );
  }
}
