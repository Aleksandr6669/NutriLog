import 'package:shared_preferences/shared_preferences.dart';

class AccountConnectionState {
  final bool isSignedIn;
  final String email;

  const AccountConnectionState({
    required this.isSignedIn,
    required this.email,
  });
}

class AccountConnectionService {
  static const String _signedInKey = 'account_signed_in';
  static const String _emailKey = 'account_email';

  Future<AccountConnectionState> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AccountConnectionState(
      isSignedIn: prefs.getBool(_signedInKey) ?? false,
      email: prefs.getString(_emailKey) ?? '',
    );
  }

  Future<void> signIn(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_signedInKey, true);
    await prefs.setString(_emailKey, email);
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_signedInKey, false);
    await prefs.remove(_emailKey);
  }
}
