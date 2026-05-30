import 'dart:ui';
import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../l10n/app_localizations.dart';
import '../../services/gemini_recipe_service.dart';
import '../../styles/app_colors.dart';
import '../../widgets/glass_app_bar_background.dart';
import '../../models/recipe.dart';
import '../../models/user_profile.dart';
import 'package:provider/provider.dart';
import '../../providers/profile_provider.dart';

class SmartScannerScreen extends StatefulWidget {
  const SmartScannerScreen({super.key});

  @override
  State<SmartScannerScreen> createState() => _SmartScannerScreenState();
}

class _SmartScannerScreenState extends State<SmartScannerScreen> {
  CameraController? _cameraController;
  final GeminiRecipeService _geminiService = GeminiRecipeService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  XFile? _capturedImage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    if (_isProcessing ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    try {

      final image = await _cameraController!.takePicture();

      setState(() {
        _capturedImage = image;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _clearCapturedImage() {
    setState(() {
      _capturedImage = null;
    });
  }

  Future<void> _sendToAi() async {
    if (_isProcessing || _capturedImage == null) return;

    final profile = context.read<ProfileProvider>().profile;
    if (profile == null || !profile.isAiFeatureAvailable) {
      if (mounted) {
        context.push('/subscription', extra: SubscriptionTier.standard);
      }
      return;
    }

    setState(() => _isProcessing = true);
    final description = _descriptionController.text.trim();

    try {
      final bytes = await _capturedImage!.readAsBytes();
      if (!mounted) return;

      final profile = context.read<ProfileProvider>().profile;
      final draft = await _geminiService.generateRecipeFromPhoto(
        imageBytes: bytes,
        imageMimeType: _detectMimeType(_capturedImage!.name),
        description: description,
        locale: Localizations.localeOf(context).languageCode,
        healthConditions: '',
        aiContext: profile?.aiContext ?? '',
      );

      if (!mounted) return;

      // Выполняем точный расчет КБЖУ на основе нашей локальной и облачной баз данных в фоновом режиме
      final preciseCalculation = await _geminiService.estimateNutrients(
        recipeName: draft.name,
        recipeDescription: draft.description,
        ingredients: draft.ingredients
            .map((i) => RecipeIngredient(
                  name: i.name,
                  quantity: i.quantity,
                  unit: i.unit,
                ))
            .toList(),
        clarification: draft.clarification,
        locale: Localizations.localeOf(context).languageCode,
        healthConditions: '',
        profile: profile,
        aiContext: profile?.aiContext ?? '',
      );

      final calibratedDraft = Recipe(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: draft.name,
        description: draft.description,
        clarification: draft.clarification,
        nutrients: preciseCalculation.nutrients, // Используем точные калиброванные нутриенты
        ingredients: draft.ingredients,
        icon: draft.icon,
        isUserRecipe: true,
        instructions: const [],
        isReadyProduct: draft.isReadyProduct,
        healthAdvice: preciseCalculation.healthAdvice,
      );

      if (!mounted) return;
      context.pushReplacement(
        '/recipe/edit',
        extra: {
          'initialDraft': calibratedDraft,
          'initialClarification':
              _buildDetailedClarification(draft, description),
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }


  String _detectMimeType(String fileName) {
    if (fileName.endsWith('.png')) return 'image/png';
    if (fileName.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }



  String _buildDetailedClarification(
    GeminiRecipeDraft draft,
    String userDescription,
  ) {
    final userText = userDescription.trim();
    final parts = <String>[];
    if (draft.clarification.trim().isNotEmpty) {
      parts.add(draft.clarification.trim());
    }
    if (userText.isNotEmpty) {
      parts.add('Дополнение пользователя: $userText');
    }
    return parts.join('\n\n').trim();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: const GlassAppBarBackground(),
        title: Text(l10n.smartScannerTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_capturedImage != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Отменить',
              onPressed: _clearCapturedImage,
            )
          else
            IconButton(
              icon: const Icon(Symbols.photo_library, color: Colors.white),
              tooltip: l10n.gallery,
              onPressed: () async {
                if (_isProcessing) return;
                final image = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 90,
                  maxWidth: 1920,
                );
                if (image == null) return;

                setState(() {
                  _capturedImage = image;
                });
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          // Background: Either Captured Image or Live Camera Preview
          if (_capturedImage != null) ...[
            Positioned.fill(
              child: Image.file(
                File(_capturedImage!.path),
                fit: BoxFit.cover,
              ),
            ),
            if (_isProcessing)
              const Positioned.fill(
                child: IgnorePointer(
                  child: NeuralScanOverlay(),
                ),
              ),
          ] else if (_isCameraInitialized && _cameraController != null)
            Positioned.fill(
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _cameraController!.value.previewSize?.height ?? 1080,
                    height: _cameraController!.value.previewSize?.width ?? 1920,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),
            )
          else
            const Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),

          if (_capturedImage == null && _isCameraInitialized)
            _buildScannerOverlay(),

          // Thumbnail (Top Right)
          if (_capturedImage != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              right: 20,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(_capturedImage!.path),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

          // Description Field (Glassmorphism)
          if (_capturedImage != null)
            Positioned(
              bottom: 120,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: TextField(
                           controller: _descriptionController,
                           style: const TextStyle(color: Colors.white, fontSize: 15),
                           maxLines: 1,
                           decoration: InputDecoration(
                             hintText: l10n.recipeDescriptionExample,
                             hintStyle: TextStyle(
                               color: Colors.white.withValues(alpha: 0.7),
                               fontSize: 14,
                             ),
                             border: InputBorder.none,
                             contentPadding: const EdgeInsets.symmetric(
                               horizontal: 0, vertical: 10),
                             prefixIcon: const Icon(Symbols.edit,
                                 color: Colors.white70, size: 20),
                             prefixIconConstraints: const BoxConstraints(
                               minWidth: 36, minHeight: 36),
                           ),
                         ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Symbols.info, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.scannerAiInvisibleTip,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11,
                              shadows: const [
                                Shadow(
                                  color: Colors.black54,
                                  offset: Offset(0, 1),
                                  blurRadius: 3,
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Action Button
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: _buildMainActionButton(Theme.of(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionButton(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final isCaptured = _capturedImage != null;

    return Builder(builder: (context) {
      final profile = context.watch<ProfileProvider>().profile;
      final isAiAvailable = profile?.isAiFeatureAvailable ?? false;
      final isLocked = isCaptured && !isAiAvailable;

      return InkWell(
        onTap: _isProcessing
            ? null
            : (isCaptured
                ? (isAiAvailable
                    ? _sendToAi
                    : () => context.push('/subscription',
                        extra: SubscriptionTier.standard))
                : _captureImage),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isCaptured
                  ? (isLocked
                      ? [Colors.grey.shade600, Colors.grey.shade700]
                      : [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.8)
                        ])
                  : [Colors.white, Colors.white.withValues(alpha: 0.9)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isProcessing)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              else
                Icon(
                  isCaptured
                      ? (isAiAvailable ? Symbols.send : Symbols.lock)
                      : Symbols.photo_camera,
                  color: isCaptured ? Colors.white : AppColors.primary,
                  size: 28,
                ),
              const SizedBox(width: 12),
              Text(
                _isProcessing
                    ? (Localizations.localeOf(context).languageCode == 'ru'
                        ? 'Анализ...'
                        : (Localizations.localeOf(context).languageCode == 'uk'
                            ? 'Аналіз...'
                            : 'Analyzing...'))
                    : (isCaptured ? l10n.recipeGenerateAndOpenEditor : l10n.camera),
                style: TextStyle(
                  color: isCaptured ? Colors.white : AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildScannerOverlay() {
    final l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: const Alignment(0, 0.6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          l10n.scannerHint,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }
}

class ScanParticle {
  Offset position;
  double size;
  double maxOpacity;
  double speed;
  double progress;
  Color color;

  ScanParticle({
    required this.position,
    required this.size,
    required this.maxOpacity,
    required this.speed,
    required this.progress,
    required this.color,
  });
}

class NeuralScanOverlay extends StatefulWidget {
  const NeuralScanOverlay({super.key});

  @override
  State<NeuralScanOverlay> createState() => _NeuralScanOverlayState();
}

class _NeuralScanOverlayState extends State<NeuralScanOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<ScanParticle> _particles = [];
  final math.Random _random = math.Random();
  Size? _lastSize;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addListener(_updateParticles)..repeat();
  }

  void _initializeParticles(Size size) {
    _particles.clear();
    for (int i = 0; i < 45; i++) {
      _particles.add(_createParticle(size, randomProgress: true));
    }
  }

  ScanParticle _createParticle(Size size, {bool randomProgress = false}) {
    final isWhite = _random.nextBool();
    return ScanParticle(
      position: Offset(
        _random.nextDouble() * size.width,
        _random.nextDouble() * size.height,
      ),
      size: 3.0 + _random.nextDouble() * 7.0, // от 3 до 10 логических пикселей
      maxOpacity: 0.15 + _random.nextDouble() * 0.4, // полупрозрачные
      speed: 0.008 + _random.nextDouble() * 0.016, // разная скорость затухания
      progress: randomProgress ? _random.nextDouble() : 0.0,
      color: isWhite ? Colors.white : AppColors.primary,
    );
  }

  void _updateParticles() {
    if (_lastSize == null) return;
    setState(() {
      for (int i = 0; i < _particles.length; i++) {
        _particles[i].progress += _particles[i].speed;
        if (_particles[i].progress >= 1.0) {
          _particles[i] = _createParticle(_lastSize!);
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (_lastSize != size) {
          _lastSize = size;
          _initializeParticles(size);
        }
        return CustomPaint(
          size: size,
          painter: ParticlesPainter(particles: _particles),
        );
      },
    );
  }
}

class ParticlesPainter extends CustomPainter {
  final List<ScanParticle> particles;

  ParticlesPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final opacity = (particle.maxOpacity * math.sin(particle.progress * math.pi)).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = particle.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(particle.position, particle.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticlesPainter oldDelegate) {
    return true;
  }
}
