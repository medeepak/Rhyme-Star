import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../theme.dart';

// Providers for managing upload photo state
final childNameProvider = StateProvider<String>((ref) => '');
final uploadedImageProvider = StateProvider<dynamic>((ref) => null); // File for mobile, Uint8List for web
final isUploadingProvider = StateProvider<bool>((ref) => false);
final faceDetectionValidProvider = StateProvider<bool>((ref) => false);

class UploadPhotoScreen extends ConsumerStatefulWidget {
  const UploadPhotoScreen({super.key});

  @override
  ConsumerState<UploadPhotoScreen> createState() => _UploadPhotoScreenState();
}

class _UploadPhotoScreenState extends ConsumerState<UploadPhotoScreen> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      ref.read(childNameProvider.notifier).state = _nameController.text;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      ref.read(isUploadingProvider.notifier).state = true;
      
      // Use file_picker to select image files
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        allowMultiple: false,
        withData: kIsWeb, // For web, we need the bytes
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        // Validate file size (5MB = 5 * 1024 * 1024 bytes)
        const maxSizeBytes = 5 * 1024 * 1024;
        if (file.size > maxSizeBytes) {
          _showErrorDialog('File size must be 5MB or less. Selected file is ${(file.size / (1024 * 1024)).toStringAsFixed(1)}MB.');
          return;
        }

        // Validate file type
        final extension = file.extension?.toLowerCase();
        if (extension == null || !['jpg', 'jpeg', 'png'].contains(extension)) {
          _showErrorDialog('Please select a JPG or PNG file.');
          return;
        }

        // Store the file data
        if (kIsWeb) {
          // For web, store the bytes
          ref.read(uploadedImageProvider.notifier).state = file.bytes;
        } else {
          // For mobile, store the file path
          ref.read(uploadedImageProvider.notifier).state = file.path;
        }

        // Perform face detection validation
        await _performFaceDetection(file);
      } else {
        // User cancelled the file picker
        ref.read(isUploadingProvider.notifier).state = false;
      }
    } catch (e) {
      _showErrorDialog('Failed to pick image: ${e.toString()}');
      ref.read(isUploadingProvider.notifier).state = false;
    }
  }

  Future<void> _performFaceDetection(PlatformFile imageFile) async {
    try {
      // Simulate face detection processing
      await Future.delayed(const Duration(seconds: 2));
      
      // For demo purposes, we'll always detect a face successfully
      // In real implementation, this would use ML Kit or similar for actual face detection
      final isValidFace = true; // Always succeed in demo mode
      
      if (isValidFace) {
        ref.read(faceDetectionValidProvider.notifier).state = true;
        _showSuccessDialog('Face detected successfully!');
      } else {
        ref.read(faceDetectionValidProvider.notifier).state = false;
        ref.read(uploadedImageProvider.notifier).state = null;
        _showErrorDialog('No face detected in image. Please upload a clear photo of the child.');
      }
    } catch (e) {
      ref.read(faceDetectionValidProvider.notifier).state = false;
      ref.read(uploadedImageProvider.notifier).state = null;
      _showErrorDialog('Face detection failed: ${e.toString()}');
    } finally {
      ref.read(isUploadingProvider.notifier).state = false;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleContinue() async {
    final childName = ref.read(childNameProvider);
    final uploadedImage = ref.read(uploadedImageProvider);
    final isFaceValid = ref.read(faceDetectionValidProvider);

    if (childName.trim().isEmpty) {
      _showErrorDialog('Please enter the child\'s name.');
      return;
    }

    if (uploadedImage == null) {
      _showErrorDialog('Please upload a photo.');
      return;
    }

    if (!isFaceValid) {
      _showErrorDialog('Please upload a valid photo with a clear face.');
      return;
    }

    try {
      // Navigate to avatar generation screen with uploaded data
      if (mounted) {
        context.go('/avatar-generation', extra: {
          'uploadedImage': uploadedImage,
          'childName': childName.trim(),
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to save data: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    final childName = ref.watch(childNameProvider);
    final uploadedImage = ref.watch(uploadedImageProvider);
    final isUploading = ref.watch(isUploadingProvider);
    final isFaceValid = ref.watch(faceDetectionValidProvider);
    
    final canContinue = childName.trim().isNotEmpty && 
                       uploadedImage != null && 
                       isFaceValid && 
                       !isUploading;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF87CEEB), // Sky blue
              Color(0xFF4FC3F7), // Light blue
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 24 : 32,
              vertical: isSmallScreen ? 16 : 24,
            ),
            child: Column(
              children: [
                const Spacer(flex: 1),
                
                // Title
                Text(
                  'Upload a photo\nand enter the child\'s\nname',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 24 : 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1976D2), // Dark blue
                    height: 1.3,
                  ),
                ),
                
                SizedBox(height: isSmallScreen ? 40 : 50),
                
                // Photo Upload Area
                UploadPhotoArea(
                  isSmallScreen: isSmallScreen,
                  uploadedImage: uploadedImage,
                  isUploading: isUploading,
                  isFaceValid: isFaceValid,
                  onTap: _pickImage,
                ),
                
                SizedBox(height: isSmallScreen ? 30 : 40),
                
                // Name Input Field
                ChildNameInput(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  isSmallScreen: isSmallScreen,
                ),
                
                const Spacer(flex: 2),
                
                // Continue Button
                ContinueButton(
                  isSmallScreen: isSmallScreen,
                  canContinue: canContinue,
                  isUploading: isUploading,
                  onPressed: canContinue ? _handleContinue : null,
                ),
                
                SizedBox(height: isSmallScreen ? 20 : 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UploadPhotoArea extends StatelessWidget {
  final bool isSmallScreen;
  final dynamic uploadedImage;
  final bool isUploading;
  final bool isFaceValid;
  final VoidCallback onTap;

  const UploadPhotoArea({
    super.key,
    required this.isSmallScreen,
    required this.uploadedImage,
    required this.isUploading,
    required this.isFaceValid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = isSmallScreen ? 200.0 : 240.0;
    
    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF87CEEB),
            width: 3,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: CustomPaint(
          painter: DashedBorderPainter(
            color: const Color(0xFF87CEEB),
            strokeWidth: 2,
            dashLength: 8,
            gapLength: 6,
          ),
          child: _buildContent(size),
        ),
      ),
    );
  }

  Widget _buildContent(double size) {
    if (isUploading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF4FC3F7),
            ),
            const SizedBox(height: 16),
            Text(
              'Processing...',
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                color: const Color(0xFF666666),
              ),
            ),
          ],
        ),
      );
    }

    if (uploadedImage != null) {
      return Stack(
        children: [
          // Actual uploaded image preview
          Container(
            width: double.infinity,
            height: double.infinity,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFaceValid ? Colors.green : Colors.orange,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: kIsWeb && uploadedImage is Uint8List
                  ? Image.memory(
                      uploadedImage as Uint8List,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : !kIsWeb && uploadedImage is String
                      ? Image.file(
                          File(uploadedImage as String),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : Container(
                          color: const Color(0xFFE3F2FD),
                          child: const Icon(
                            Icons.photo,
                            size: 60,
                            color: Color(0xFF4FC3F7),
                          ),
                        ),
            ),
          ),
          // Validation indicator
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isFaceValid ? Colors.green : Colors.orange,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFaceValid ? Icons.check : Icons.face,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      );
    }

    // Default upload state
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt,
            size: isSmallScreen ? 40 : 50,
            color: const Color(0xFF87CEEB),
          ),
          const SizedBox(height: 12),
          Text(
            'Tap to upload',
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
              color: const Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'JPG/PNG ≤ 5MB',
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 14,
              color: const Color(0xFF999999),
            ),
          ),
        ],
      ),
    );
  }
}

class ChildNameInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSmallScreen;

  const ChildNameInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 20 : 24,
        vertical: isSmallScreen ? 16 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(isSmallScreen ? 25 : 30),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 8,
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isSmallScreen ? 18 : 22,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1976D2),
        ),
        decoration: InputDecoration(
          hintText: 'Samantha',
          hintStyle: TextStyle(
            fontSize: isSmallScreen ? 18 : 22,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1976D2).withOpacity(0.6),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        maxLength: 50,
        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
      ),
    );
  }
}

class ContinueButton extends StatelessWidget {
  final bool isSmallScreen;
  final bool canContinue;
  final bool isUploading;
  final VoidCallback? onPressed;

  const ContinueButton({
    super.key,
    required this.isSmallScreen,
    required this.canContinue,
    required this.isUploading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: canContinue 
              ? const Color(0xFFFF6B47) // Orange
              : const Color(0xFFFFB4A0), // Light orange (disabled)
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 16 : 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isSmallScreen ? 25 : 30),
          ),
          elevation: canContinue ? 6 : 2,
          shadowColor: Colors.black.withOpacity(0.3),
        ),
        child: isUploading
            ? SizedBox(
                height: isSmallScreen ? 20 : 24,
                width: isSmallScreen ? 20 : 24,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Continue',
                style: TextStyle(
                  fontSize: isSmallScreen ? 18 : 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final borderRadius = 20.0;
    final rect = Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, 
        size.width - strokeWidth, size.height - strokeWidth);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    
    final path = Path()..addRRect(rrect);
    
    // Draw dashed border
    _drawDashedPath(canvas, paint, path);
  }

  void _drawDashedPath(Canvas canvas, Paint paint, Path path) {
    final pathMetrics = path.computeMetrics();
    
    for (final metric in pathMetrics) {
      double distance = 0.0;
      bool draw = true;
      
      while (distance < metric.length) {
        final length = draw ? dashLength : gapLength;
        if (draw) {
          final extractPath = metric.extractPath(distance, distance + length);
          canvas.drawPath(extractPath, paint);
        }
        distance += length;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
