import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/diary/diary_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/analysis/analysis_screen.dart';
import 'screens/search/search_screen.dart';
import 'providers/diary_provider.dart';

Future main() async {
  await dotenv.load(fileName: ".env");
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => DiaryProvider()),
      
      ],
      child: const CalorieTrackerApp(),
    ),
  );
}

//--------- THEME PROVIDER ---------//

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

//--------- APP ROUTER ---------//

final _router = GoRouter(
  initialLocation: '/diary',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return MainScreen(child: child);
      },
      routes: [
        GoRoute(
          path: '/diary',
          builder: (context, state) => const DiaryScreen(),
        ),
        GoRoute(
          path: '/analysis',
          builder: (context, state) => const AnalysisScreen(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
  ],
);

//--------- APP ---------//

class CalorieTrackerApp extends StatelessWidget {
  const CalorieTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp.router(
      title: 'Calorie Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      routerConfig: _router,
    );
  }
}

//--------- MAIN SCREEN WITH BOTTOM NAV ---------//

class MainScreen extends StatelessWidget {
  final Widget child;
  const MainScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Symbols.menu_book),
            label: 'ДНЕВНИК',
          ),
          BottomNavigationBarItem(
            icon: Icon(Symbols.search),
            label: 'ПОИСК',
          ),
          BottomNavigationBarItem(
            icon: Icon(Symbols.bar_chart),
            label: 'АНАЛИЗ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Symbols.person),
            label: 'ПРОФИЛЬ',
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/diary')) {
      return 0;
    }
    if (location.startsWith('/search')) {
      return 1;
    }
    if (location.startsWith('/analysis')) {
      return 2;
    }
    if (location.startsWith('/profile')) {
      return 3;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        GoRouter.of(context).go('/diary');
        break;
      case 1:
        GoRouter.of(context).go('/search');
        break;
      case 2:
        GoRouter.of(context).go('/analysis');
        break;
      case 3:
        GoRouter.of(context).go('/profile');
        break;
    }
  }
}

//--------- APP THEME ---------//

class AppTheme {
  static const Color _primaryColor = Color(0xFF00C753);
  static const Color _backgroundLight = Color(0xFFF5F8F7);
  static const Color _backgroundDark = Color(0xFF0F2317);

  static final TextTheme _textTheme = TextTheme(
    displayLarge: GoogleFonts.manrope(fontWeight: FontWeight.w800),
    displayMedium: GoogleFonts.manrope(fontWeight: FontWeight.w800),
    displaySmall: GoogleFonts.manrope(fontWeight: FontWeight.w800),
    headlineLarge: GoogleFonts.manrope(fontWeight: FontWeight.w700),
    headlineMedium: GoogleFonts.manrope(fontWeight: FontWeight.w700),
    headlineSmall: GoogleFonts.manrope(fontWeight: FontWeight.w700),
    titleLarge: GoogleFonts.manrope(fontWeight: FontWeight.w600),
    titleMedium: GoogleFonts.manrope(fontWeight: FontWeight.w600),
    titleSmall: GoogleFonts.manrope(fontWeight: FontWeight.w600),
    bodyLarge: GoogleFonts.manrope(),
    bodyMedium: GoogleFonts.manrope(),
    bodySmall: GoogleFonts.manrope(),
    labelLarge: GoogleFonts.manrope(fontWeight: FontWeight.w500),
    labelMedium: GoogleFonts.manrope(fontWeight: FontWeight.w500),
    labelSmall: GoogleFonts.manrope(fontWeight: FontWeight.w500),
  );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: _primaryColor,
    scaffoldBackgroundColor: _backgroundLight,
    colorScheme: const ColorScheme.light(
      primary: _primaryColor,
      secondary: _primaryColor,
      surface: Colors.white,
    ),
    textTheme: _textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: _backgroundLight,
      elevation: 0,
      titleTextStyle: _textTheme.headlineSmall?.copyWith(color: Colors.black),
      iconTheme: const IconThemeData(color: Colors.black),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: _primaryColor,
      unselectedItemColor: Colors.grey[500],
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: _primaryColor,
    scaffoldBackgroundColor: _backgroundDark,
    colorScheme: const ColorScheme.dark(
      primary: _primaryColor,
      secondary: _primaryColor,
      surface: Color(0xFF1A2C21),
    ),
    textTheme: _textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: _backgroundDark,
      elevation: 0,
      titleTextStyle: _textTheme.headlineSmall?.copyWith(color: Colors.white),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: const Color(0xFF1A2C21),
      selectedItemColor: _primaryColor,
      unselectedItemColor: Colors.grey[400],
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF1A2C21),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[800]!),
      ),
    ),
  );
}
