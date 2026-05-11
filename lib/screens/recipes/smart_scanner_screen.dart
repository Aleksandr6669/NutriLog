import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../l10n/app_localizations.dart';
import '../../services/barcode_service.dart';
import '../../services/gemini_recipe_service.dart';
import '../../styles/app_colors.dart';
import '../../widgets/glass_app_bar_background.dart';
import '../../models/recipe.dart';

class SmartScannerScreen extends StatefulWidget {
  const SmartScannerScreen({super.key});

  @override
  State<SmartScannerScreen> createState() => _SmartScannerScreenState();
}

class _SmartScannerScreenState extends State<SmartScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final BarcodeService _barcodeService = BarcodeService();
  final GeminiRecipeService _geminiService = GeminiRecipeService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isProcessing = false;
  XFile? _capturedImage;

  @override
  void dispose() {
    _controller.dispose();
    _descriptionController.dispose();
    super.dispose();
  }



  Future<void> _captureImage() async {
    if (_isProcessing) return;
    
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 1920,
      );
      
      if (image == null) return;

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



  Future<void> _sendToAi() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isProcessing || _capturedImage == null) return;

    setState(() => _isProcessing = true);
    final description = _descriptionController.text.trim();

    try {
      final bytes = await _capturedImage!.readAsBytes();
      if (!mounted) return;

      final draft = await _geminiService.generateRecipeFromPhoto(
        imageBytes: bytes,
        imageMimeType: _detectMimeType(_capturedImage!.name),
        description: description,
        locale: Localizations.localeOf(context).languageCode,
      );

      if (!mounted) return;
      context.pushReplacement(
        '/recipes/edit',
        extra: {
          'initialDraft': _buildDraftRecipe(draft),
          'initialClarification': _buildDetailedClarification(draft, description),
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
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final product = await _barcodeService.fetchProductByBarcode(code);
      if (product == null) {
        throw Exception(l10n.productNotFoundError);
      }

      final productName = product['product_name'] ?? l10n.unknownProduct;
      final brand = product['brands'] ?? '';
      
      // Используем Gemini для превращения данных о продукте в черновик рецепта/блюда
      final prompt = 'Identify this product and create a basic nutritional entry: $productName ($brand). JSON data: ${json.encode(product)}';
      
      final draft = await _geminiService.generateRecipeFromDescription(
        description: prompt,
        locale: Localizations.localeOf(context).languageCode,
      );

      if (!mounted) return;

      context.pushReplacement(
        '/recipes/edit',
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
          IconButton(
            icon: const Icon(Symbols.photo_library, color: Colors.white),
            tooltip: AppLocalizations.of(context)!.gallery,
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
          // Photo Preview (Instead of Scanner)
          if (_capturedImage != null)
            Positioned.fill(
              child: Image.file(
                File(_capturedImage!.path),
                fit: BoxFit.cover,
              ),
            )
          else
            MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && !_isProcessing && _capturedImage == null) {
                  final String? code = barcodes.first.rawValue;
                  if (code != null) {
                    _processBarcode(code);
                  }
                }
              },
            ),

          if (_capturedImage == null)
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
          Positioned(
            bottom: 140,
            left: 20,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                      icon: const Icon(Symbols.edit, color: Colors.white70, size: 20),
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

    return InkWell(
      onTap: isCaptured ? _sendToAi : _captureImage,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isCaptured
                ? [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)]
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
              isCaptured ? Symbols.send : Symbols.photo_camera,
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
