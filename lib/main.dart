import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home/home_screen.dart';
import 'styles/app_colors.dart';
import 'styles/app_styles.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calorie Tracker',
      theme: _buildTheme(Brightness.light),
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final bool isLight = brightness == Brightness.light;

  final Color background = isLight ? AppColors.backgroundLight : AppColors.backgroundDark;
  final Color textColor = isLight ? AppColors.textLight : AppColors.textDark;
  final Color subtleTextColor = isLight ? AppColors.subtleTextLight : AppColors.subtleTextDark;
  final Color cardColor = isLight ? AppColors.cardLight : AppColors.cardDark;
  final Color cardBorderColor = isLight ? AppColors.cardBorderLight : AppColors.cardBorderDark;

  final baseTheme = ThemeData(
    brightness: brightness,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: background,
    useMaterial3: true,
  );

  return baseTheme.copyWith(
    colorScheme: baseTheme.colorScheme.copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      surface: cardColor,
      onSurface: textColor,
      background: background,
    ),
    textTheme: GoogleFonts.manropeTextTheme(baseTheme.textTheme).apply(
      bodyColor: textColor,
      displayColor: textColor,
    ).copyWith(
      displayLarge: const TextStyle(fontWeight: FontWeight.w800, fontSize: 48, letterSpacing: -1),
      headlineSmall: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
      titleLarge: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      titleMedium: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      bodyLarge: const TextStyle(fontSize: 14),
      bodyMedium: const TextStyle(fontSize: 12),
      bodySmall: TextStyle(color: subtleTextColor, fontSize: 10, letterSpacing: 0.5, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(color: subtleTextColor, fontSize: 10, letterSpacing: 0.5, fontWeight: FontWeight.bold, ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppStyles.defaultBorderRadius,
        side: BorderSide(color: cardBorderColor, width: 1),
      ),
      color: cardColor,
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: textColor,
      titleTextStyle: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 22, color: textColor),
      centerTitle: false,
    ),
     elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: AppStyles.buttonRadius),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        elevation: 0,
      ),
    ),
    iconTheme: IconThemeData(
      color: textColor,
      size: 28
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: cardColor.withOpacity(0.8),
      selectedItemColor: AppColors.primary,
      unselectedItemColor: subtleTextColor,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      unselectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
    ),
  );
}
