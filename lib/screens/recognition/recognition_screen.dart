import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../services/groq_service.dart'; // Импортируем наш обновленный сервис

class RecognitionScreen extends StatefulWidget {
  const RecognitionScreen({super.key});

  @override
  State<RecognitionScreen> createState() => _RecognitionScreenState();
}

class _RecognitionScreenState extends State<RecognitionScreen> {
  final ImagePicker _picker = ImagePicker();
  final GroqService _groqService = GroqService(); // Создаем экземпляр сервиса

  Uint8List? _imageBytes;
  String _analysisResult = "";
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _analysisResult = ""; // Очищаем предыдущий результат
      });
      _analyzeImage(bytes);
    }
  }

  Future<void> _analyzeImage(Uint8List imageBytes) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Вызываем новый метод для анализа изображений
      final result = await _groqService.analyzeImage(imageBytes);
      setState(() {
        _analysisResult = result;
      });
    } catch (e) {
      setState(() {
        _analysisResult = 'Произошла ошибка: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Распознавание еды'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_imageBytes == null)
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 250,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.dividerColor, width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Symbols.add_a_photo, size: 60, color: theme.hintColor),
                        const SizedBox(height: 16),
                        Text('Нажмите, чтобы выбрать фото', style: theme.textTheme.titleMedium),
                      ],
                    ),
                  ),
                ),
              if (_imageBytes != null)
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20.0),
                      child: Image.memory(_imageBytes!, fit: BoxFit.cover, height: 300, width: double.infinity),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Symbols.change_circle),
                      label: const Text('Выбрать другое фото'),
                    ),
                  ],
                ),
              const SizedBox(height: 32),
              if (_isLoading)
                const CircularProgressIndicator(),
              if (!_isLoading && _analysisResult.isNotEmpty)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          _analysisResult,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Implement adding to diary
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('"$_analysisResult" добавлено в дневник!')),
                            );
                          },
                          icon: const Icon(Symbols.add_circle),
                          label: const Text('Добавить в дневник'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: theme.colorScheme.onPrimary,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
