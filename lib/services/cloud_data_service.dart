import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_auth_service.dart';
import 'firebase_bootstrap_service.dart';

class CloudDataService {
  CloudDataService._();

  static final CloudDataService instance = CloudDataService._();
  // Local-first: UI всегда работает на локальных данных, облако синкается фоном.
  // Для полного отключения облака переключите в true.
  static const bool _forceLocalOnly = false;
  static const String _lastSyncAtKey = 'cloud_last_sync_at';
  static const Duration _cloudTimeout = Duration(seconds: 3);

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  String? get _uid => FirebaseAuthService.instance.currentUser?.uid;
  String? get currentUserId => _uid;
  bool get isLocalOnlyMode => _forceLocalOnly;

  bool get isSignedIn => !_forceLocalOnly && FirebaseAuthService.instance.isSignedIn;

  DocumentReference<Map<String, dynamic>> _docRef(String key) {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('User is not signed in.');
    }

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('appData')
        .doc(key);
  }

  Future<void> _ensureUserRootDocument() async {
    if (_forceLocalOnly) return;

    final uid = _uid;
    final user = FirebaseAuthService.instance.currentUser;
    if (uid == null || uid.isEmpty || user == null) return;

    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': user.email,
      'displayName': user.displayName,
      'cloudSyncEnabled': true,
      'appDataMirror': FieldValue.delete(),
      'appDataMirrorMeta': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).timeout(_cloudTimeout);
  }

  Future<Map<String, dynamic>?> readMap(String key) async {
    if (_forceLocalOnly) return null;
    if (!isSignedIn) return null;

    try {
      await FirebaseBootstrapService.ensureInitialized();
      await _ensureUserRootDocument();
      final snapshot = await _docRef(key).get().timeout(_cloudTimeout);
      if (!snapshot.exists) return null;

      await markSyncNow();
      return snapshot.data();
    } catch (_) {
      // Офлайн/таймаут: вызывающий код должен продолжать работать по локальным данным.
      return null;
    }
  }

  Future<void> writeMap(String key, Map<String, dynamic> data) async {
    if (_forceLocalOnly) return;
    if (!isSignedIn) return;

    try {
      await FirebaseBootstrapService.ensureInitialized();
      await _ensureUserRootDocument();
      await _docRef(key)
          .set(data, SetOptions(merge: false))
          .timeout(_cloudTimeout);
      await markSyncNow();
    } catch (_) {
      // Офлайн/таймаут: сохраняем только локально.
    }
  }

  Future<List<Map<String, dynamic>>> readCollection(
      String collectionPath) async {
    if (_forceLocalOnly) return const [];
    if (!isSignedIn) return const [];

    try {
      await FirebaseBootstrapService.ensureInitialized();
      final snapshot =
          await _firestore.collection(collectionPath).get().timeout(_cloudTimeout);
      await markSyncNow();
      return snapshot.docs
          .map((doc) => <String, dynamic>{
                ...doc.data(),
                '__docId': doc.id,
              })
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> upsertDocument(
    String collectionPath,
    String docId,
    Map<String, dynamic> data,
  ) async {
    if (_forceLocalOnly) return;
    if (!isSignedIn) return;

    try {
      await FirebaseBootstrapService.ensureInitialized();
      await _firestore
          .collection(collectionPath)
          .doc(docId)
          .set(data, SetOptions(merge: false))
          .timeout(_cloudTimeout);
      await markSyncNow();
    } catch (_) {
      // Офлайн/таймаут: локальные данные остаются источником истины.
    }
  }

  Future<void> deleteDocument(String collectionPath, String docId) async {
    if (_forceLocalOnly) return;
    if (!isSignedIn) return;

    try {
      await FirebaseBootstrapService.ensureInitialized();
      await _firestore
          .collection(collectionPath)
          .doc(docId)
          .delete()
          .timeout(_cloudTimeout);
      await markSyncNow();
    } catch (_) {
      // Офлайн/таймаут: удаление в облаке будет выполнено позже.
    }
  }

  Future<DateTime?> getLastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastSyncAtKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  Future<void> markSyncNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _lastSyncAtKey, DateTime.now().toUtc().toIso8601String());
  }

  /// Real-time stream для коллекции Firestore.
  Stream<List<Map<String, dynamic>>> collectionStream(String collectionPath) {
    if (_forceLocalOnly) return Stream.value(const <Map<String, dynamic>>[]);
    return _firestore.collection(collectionPath).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => <String, dynamic>{
                    ...doc.data(),
                    '__docId': doc.id,
                  })
              .toList(growable: false),
        ).handleError((_) {
          // Офлайн/permission ошибки стрима игнорируем: UI работает с локальным кешем.
        });
  }

  /// Real-time stream для одного документа `users/{uid}/appData/{key}`.
  /// Переключается при смене аккаунта. Пропускает обновления от локальных записей,
  /// чтобы не вызывать лишних перерисовок.
  Stream<Map<String, dynamic>?> docStream(String key) {
    if (_forceLocalOnly) return Stream.value(null);
    return FirebaseAuthService.instance.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(null);
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('appData')
          .doc(key)
          .snapshots()
          .where((snap) => !snap.metadata.hasPendingWrites)
          .map((snap) => snap.exists ? snap.data() : null);
    }).handleError((_) {
      // Офлайн/permission ошибки стрима не должны ломать локальную работу.
    });
  }

  /// Отправляет рецепт в коллекцию donatedRecipes.
  /// После записи никто (включая автора) не может изменить или удалить документ —
  /// это обеспечивается правилами Firestore (только create разрешён).
  Future<void> donateRecipe(Map<String, dynamic> recipeData) async {
    if (_forceLocalOnly) return;
    if (!isSignedIn) throw StateError('User is not signed in.');

    await FirebaseBootstrapService.ensureInitialized();
    await _ensureUserRootDocument();
    final uid = _uid!;
    final docId = recipeData['id'] as String? ?? uid;
    await _firestore.collection('donatedRecipes').doc(docId).set({
      ...recipeData,
      'donatedBy': uid,
      'donatedAt': FieldValue.serverTimestamp(),
      'isDonated': true,
    });
    await markSyncNow();
  }
}
