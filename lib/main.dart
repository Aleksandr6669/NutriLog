import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'dart:ui';
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
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    // TODO: Add other screens here
    Center(child: Text('Recipes Screen')),
    Center(child: Text('Analysis Screen')),
    Center(child: Text('Profile Screen')),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      extendBody: true,
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final BorderRadius borderRadius = BorderRadius.circular(30);

    return Container(
      height: 90,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            decoration: BoxDecoration(
              color: theme.bottomNavigationBarTheme.backgroundColor?.withAlpha(180),
              border: Border.all(color: AppColors.primary.withAlpha(30)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Symbols.menu_book,
                  label: 'Дневник',
                  isSelected: currentIndex == 0,
                  onTap: () => onTap(0),
                ),
                _NavItem(
                  icon: Symbols.receipt_long,
                  label: 'Рецепты',
                  isSelected: currentIndex == 1,
                  onTap: () => onTap(1),
                ),
                _NavItem(
                  icon: Symbols.analytics,
                  label: 'Анализ',
                  isSelected: currentIndex == 2,
                  onTap: () => onTap(2),
                ),
                _NavItem(
                  icon: Symbols.person,
                  label: 'Профиль',
                  isSelected: currentIndex == 3,
                  onTap: () => onTap(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSelected
        ? theme.bottomNavigationBarTheme.selectedItemColor
        : theme.bottomNavigationBarTheme.unselectedItemColor;
    
    final labelStyle = (isSelected
        ? theme.bottomNavigationBarTheme.selectedLabelStyle
        : theme.bottomNavigationBarTheme.unselectedLabelStyle)
      ?.copyWith(color: color);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                fill: isSelected ? 1.0 : 0.0,
                weight: isSelected ? 600.0 : 300.0,
              ),
              const SizedBox(height: 4),
              Text(label, style: labelStyle),
            ],
          ),
        ),
      ),
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
    ),
    textTheme: GoogleFonts.manropeTextTheme(baseTheme.textTheme).apply(
      bodyColor: textColor,
      displayColor: textColor,
    ).copyWith(
      displayLarge: TextStyle(fontWeight: FontWeight.w800, fontSize: 48, letterSpacing: -1, color: textColor),
      headlineSmall: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: textColor),
      titleLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
      titleMedium: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
      bodyLarge: TextStyle(fontSize: 14, color: textColor),
      bodyMedium: TextStyle(fontSize: 12, color: textColor),
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
      backgroundColor: cardColor.withAlpha(204),
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
