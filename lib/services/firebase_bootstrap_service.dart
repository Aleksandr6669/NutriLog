import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

class FirebaseBootstrapService {
  FirebaseBootstrapService._();

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized || Firebase.apps.isNotEmpty) {
      _initialized = true;
      return;
    }

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _initialized = true;
  }
}
