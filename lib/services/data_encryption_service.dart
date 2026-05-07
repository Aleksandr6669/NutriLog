import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;

/// Сервис для шифрования приватных данных пользователя перед отправкой в облако.
/// Использует UID пользователя для генерации детерминированного ключа шифрования.
///
/// Приватные данные:
/// - userProfile
/// - diaryLogs
/// - userRecipes
/// - aiReportHistory
///
/// Публичные данные (не шифруются):
/// - communityRecipes (если они опубликованы)
class DataEncryptionService {
  DataEncryptionService._();

  static final DataEncryptionService instance = DataEncryptionService._();

  /// Список ключей документов, которые должны быть шифрованы
  static const List<String> _privateDocumentKeys = [
    'userProfile',
    'diaryLogs',
    'userRecipes',
    'aiReportHistory',
    'notificationSettings',
  ];

  /// Генерирует ключ шифрования на основе UID пользователя.
  /// Преобразует UID в 32-байтный ключ для AES-256.
  static encrypt.Key _generateKeyFromUid(String uid) {
    // Дублируем и берем первые 32 байта (256 бит) для AES-256
    final bytes = utf8.encode(uid);
    final keyBytes = <int>[];
    for (int i = 0; i < 32; i++) {
      keyBytes.add(bytes[i % bytes.length]);
    }
    return encrypt.Key(Uint8List.fromList(keyBytes));
  }

  /// Генерирует IV (Initialization Vector) на основе UID.
  /// 16 байт (128 бит) для IV.
  static encrypt.IV _generateIvFromUid(String uid) {
    final bytes = utf8.encode(uid);
    final ivBytes = <int>[];
    for (int i = 0; i < 16; i++) {
      ivBytes.add(bytes[(i + 1) % bytes.length]);
    }
    return encrypt.IV(Uint8List.fromList(ivBytes));
  }

  /// Проверяет, должны ли быть данные с этим ключом шифрованы
  static bool _shouldEncrypt(String documentKey) {
    return _privateDocumentKeys.contains(documentKey);
  }

  /// Шифрует данные для отправки в облако.
  /// 
  /// Если документ в списке приватных, шифруется вся его содержимое.
  /// Добавляется метаполе `_encrypted: true` для отслеживания зашифрованных данных.
  Map<String, dynamic> encryptMapForCloud(
    String documentKey,
    Map<String, dynamic> data,
    String uid,
  ) {
    if (!_shouldEncrypt(documentKey)) {
      // Публичные данные не шифруются
      return data;
    }

    try {
      final key = _generateKeyFromUid(uid);
      final iv = _generateIvFromUid(uid);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      // Сериализуем данные в JSON
      final jsonString = jsonEncode(data);

      // Шифруем
      final encrypted = encrypter.encrypt(jsonString, iv: iv);

      // Возвращаем только зашифрованные данные и метаданные
      return {
        '_encrypted': true,
        '_data': encrypted.base64,
        '_encryptedAt': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      // Если шифрование не удалось, возвращаем оригинальные данные
      // (в production должен быть fail-safe или логирование)
      return {
        ...data,
        '_encryptionFailed': true,
      };
    }
  }

  /// Дешифрует данные полученные из облака.
  ///
  /// Проверяет метаполе `_encrypted`. Если true - дешифрует содержимое.
  Map<String, dynamic> decryptMapFromCloud(
    String documentKey,
    Map<String, dynamic> data,
    String uid,
  ) {
    if (!_shouldEncrypt(documentKey)) {
      // Публичные данные не дешифруются
      return data;
    }

    // Если данные не отмечены как зашифрованные, возвращаем как есть
    if (data['_encrypted'] != true) {
      return data;
    }

    try {
      final encryptedBase64 = data['_data'] as String?;
      if (encryptedBase64 == null || encryptedBase64.isEmpty) {
        return {};
      }

      final key = _generateKeyFromUid(uid);
      final iv = _generateIvFromUid(uid);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      // Дешифруем
      final decrypted =
          encrypter.decrypt64(encryptedBase64, iv: iv);

      // Десериализуем JSON
      return jsonDecode(decrypted) as Map<String, dynamic>;
    } catch (e) {
      // Если дешифрование не удалось, возвращаем пустую карту
      return {};
    }
  }

  /// Шифрует список карт (например, для коллекций)
  List<Map<String, dynamic>> encryptListForCloud(
    String collectionPath,
    List<Map<String, dynamic>> dataList,
    String uid,
  ) {
    if (!_shouldEncrypt(collectionPath)) {
      return dataList;
    }

    return dataList.map((item) {
      return encryptMapForCloud(collectionPath, item, uid);
    }).toList();
  }

  /// Дешифрует список карт
  List<Map<String, dynamic>> decryptListFromCloud(
    String collectionPath,
    List<Map<String, dynamic>> dataList,
    String uid,
  ) {
    if (!_shouldEncrypt(collectionPath)) {
      return dataList;
    }

    return dataList.map((item) {
      return decryptMapFromCloud(collectionPath, item, uid);
    }).toList();
  }
}
