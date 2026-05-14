import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../l10n/app_localizations.dart';
import '../../services/barcode_service.dart';
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
  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  final BarcodeService _barcodeService = BarcodeService();
  final GeminiRecipeService _geminiService = GeminiRecipeService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  bool _isScanning = false;
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

      _startBarcodeScanning();
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  void _startBarcodeScanning() {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      _cameraController!.startImageStream(_processCameraImage);
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing || _isScanning || _capturedImage != null) return;

    _isScanning = true;

    try {
      final camera = _cameraController!.description;
      final rotation =
          InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
              InputImageRotation.rotation0deg;
      final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.nv21;

      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
      final barcodes = await _barcodeScanner.processImage(inputImage);

      if (barcodes.isNotEmpty && !_isProcessing && _capturedImage == null) {
        final String? code = barcodes.first.rawValue;
        if (code != null) {
          // Pause camera stream to process barcode
          await _cameraController?.stopImageStream();
          await _processBarcode(code);
          return;
        }
      }
    } catch (e) {
      debugPrint('Error processing camera image: $e');
    } finally {
      if (mounted) {
        _isScanning = false;
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _barcodeScanner.close();
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
      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }

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
    _startBarcodeScanning();
  }

  Future<void> _sendToAi() async {
    if (_isProcessing || _capturedImage == null) return;

    final l10n = AppLocalizations.of(context)!;
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
        healthConditions: profile?.healthConditions ?? '',
      );

      if (!mounted) return;
      context.pushReplacement(
        '/recipe/edit',
        extra: {
          'initialDraft': _buildDraftRecipe(draft),
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

  Future<void> _processBarcode(String code) async {
    final l10n = AppLocalizations.of(context)!;
    final profile = context.read<ProfileProvider>().profile;
    if (profile == null || !profile.isAiFeatureAvailable) {
      context.push('/subscription', extra: SubscriptionTier.standard);
      return;
    }

    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final product = await _barcodeService.fetchProductByBarcode(code);
      GeminiRecipeDraft draft;
      if (product == null) {
        final prompt =
            'Search the web for the nutritional information and ingredients of the product with barcode: "$code". Create a basic nutritional entry for the product you find. If you cannot find any product with this barcode, return an empty object or name it "Unknown".';
        final profile = context.read<ProfileProvider>().profile;
        draft = await _geminiService.generateRecipeFromDescription(
          description: prompt,
          locale: Localizations.localeOf(context).languageCode,
          healthConditions: profile?.healthConditions ?? '',
        );
        if (draft.name.isEmpty || draft.name.toLowerCase() == 'unknown') {
          throw Exception(l10n.productNotFoundError);
        }
      } else {
        final profile = context.read<ProfileProvider>().profile;
        draft = await _geminiService.generateRecipeFromBarcode(
          productData: product,
          locale: Localizations.localeOf(context).languageCode,
          healthConditions: profile?.healthConditions ?? '',
        );
      }

      if (!mounted) return;

      context.pushReplacement(
        '/recipe/edit',
        extra: {
          'initialDraft': _buildDraftRecipe(draft),
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
        // Resume scanning if error occurred
        _startBarcodeScanning();
      }
    }
  }

  String _detectMimeType(String fileName) {
    if (fileName.endsWith('.png')) return 'image/png';
    if (fileName.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Recipe _buildDraftRecipe(GeminiRecipeDraft draft) {
    return Recipe(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: draft.name,
      description: draft.description,
      clarification: draft.clarification,
      nutrients: draft.nutrients,
      ingredients: draft.ingredients,
      icon: draft.icon,
      isUserRecipe: true,
      instructions: const [],
    );
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

                if (_cameraController?.value.isStreamingImages == true) {
                  await _cameraController?.stopImageStream();
                }

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
          if (_capturedImage != null)
            Positioned.fill(
              child: Image.file(
                File(_capturedImage!.path),
                fit: BoxFit.cover,
              ),
            )
          else if (_isCameraInitialized && _cameraController != null)
            Positioned.fill(
              // Using SizedBox.expand to ensure CameraPreview fills the background properly
              // (might require clipping or BoxFit depending on aspect ratio, but we'll let CameraPreview handle it)
              child: CameraPreview(_cameraController!),
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
              bottom: 140,
              left: 20,
              right: 20,
              child: ClipRRect(
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
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      maxLines: 1,
                      decoration: InputDecoration(
                        hintText: l10n.recipeDescriptionExample,
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        icon: const Icon(Symbols.edit,
                            color: Colors.white70, size: 20),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Action Button
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: _buildMainActionButton(Theme.of(context)),
          ),

          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
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
        onTap: isCaptured
            ? (isAiAvailable
                ? _sendToAi
                : () =>
                    context.push('/subscription', extra: SubscriptionTier.standard))
            : _captureImage,
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
              Icon(
                isCaptured
                    ? (isAiAvailable ? Symbols.send : Symbols.lock)
                    : Symbols.photo_camera,
                color: isCaptured ? Colors.white : AppColors.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                isCaptured ? l10n.recipeGenerateAndOpenEditor : l10n.camera,
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 2),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          const SizedBox(height: 20),
          Container(
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
        ],
      ),
    );
  }
}
