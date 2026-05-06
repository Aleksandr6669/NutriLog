import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_auth_service.dart';
import 'firebase_bootstrap_service.dart';

class CloudDataService {
  CloudDataService._();

  static final CloudDataService instance = CloudDataService._();
  static const String _lastSyncAtKey = 'cloud_last_sync_at';

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  String? get _uid => FirebaseAuthService.instance.currentUser?.uid;

  bool get isSignedIn => FirebaseAuthService.instance.isSignedIn;

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

  Future<Map<String, dynamic>?> readMap(String key) async {
    if (!isSignedIn) return null;

    await FirebaseBootstrapService.ensureInitialized();
    final snapshot = await _docRef(key).get();
    if (!snapshot.exists) return null;

    await markSyncNow();
    return snapshot.data();
  }

  Future<void> writeMap(String key, Map<String, dynamic> data) async {
    if (!isSignedIn) return;

    await FirebaseBootstrapService.ensureInitialized();
    await _docRef(key).set(data, SetOptions(merge: false));
    await markSyncNow();
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
}
