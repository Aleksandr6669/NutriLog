import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:ui';
import 'services/app_notification_service.dart';
import 'services/app_startup_service.dart';
import 'services/notification_settings_service.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/onboarding/whats_new_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/recipes/recipes_screen.dart';
import 'screens/stats/stats_screen.dart';
import 'styles/app_colors.dart';
import 'styles/app_styles.dart';
import 'widgets/glass_app_bar_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env может отсутствовать в локальной среде.
  }
  await initializeDateFormatting('ru_RU', null);
  if (!kIsWeb) {
    final notificationService = AppNotificationService();
    final notificationSettingsService = NotificationSettingsService();
    await notificationService.initialize();
    final settings = await notificationSettingsService.load();
    await notificationService.applySettings(settings);
  }
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriLog',
      theme: _buildTheme(Brightness.light),
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru', 'RU'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('en', 'US'),
      ],
      home: const AppBootstrapScreen(),
    );
  }
}

class AppBootstrapScreen extends StatefulWidget {
  const AppBootstrapScreen({super.key});

  @override
  State<AppBootstrapScreen> createState() => _AppBootstrapScreenState();
}

class _AppBootstrapScreenState extends State<AppBootstrapScreen> {
  final AppStartupService _startupService = AppStartupService();
  bool _loading = true;
  StartupState? _state;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final state = await _startupService.loadState();
    if (!mounted) return;
    setState(() {
      _state = state;
      _loading = false;
    });
  }

  Future<void> _completeOnboarding() async {
    await _startupService.completeOnboarding();
    await _init();
  }

  Future<void> _ackWhatsNew() async {
    final state = _state;
    if (state == null) return;
    await _startupService.markWhatsNewSeen(state.currentVersion);
    await _init();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final state = _state!;

    if (state.needsOnboarding) {
      return OnboardingScreen(
        key: const ValueKey('onboarding'),
        onCompleted: _completeOnboarding,
      );
    }

    if (state.whatsNewText != null) {
      return WhatsNewScreen(
        key: const ValueKey('whats_new'),
        version: state.currentVersion,
        text: state.whatsNewText!,
        onAcknowledged: _ackWhatsNew,
      );
    }

    return const MainScreen();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const SystemUiOverlayStyle _lightStatusBarStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    RecipesScreen(),
    StatsScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _lightStatusBarStyle,
      child: Scaffold(
        body: _widgetOptions.elementAt(_selectedIndex),
        bottomNavigationBar: _BottomNavBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
        extendBody: true,
      ),
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
          filter: ImageFilter.blur(
            sigmaX: kGlassBlurSigma,
            sigmaY: kGlassBlurSigma,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(
                alpha: kGlassSurfaceAlpha,
              ),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
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

  final Color background =
      isLight ? AppColors.backgroundLight : AppColors.backgroundDark;
  final Color textColor = isLight ? AppColors.textLight : AppColors.textDark;
  final Color subtleTextColor =
      isLight ? AppColors.subtleTextLight : AppColors.subtleTextDark;
  final Color cardColor = isLight ? AppColors.cardLight : AppColors.cardDark;
  final Color cardBorderColor =
      isLight ? AppColors.cardBorderLight : AppColors.cardBorderDark;

  final baseTheme = ThemeData(
    brightness: brightness,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: background,
    useMaterial3: true,
    fontFamily: 'Manrope',
  );

  return baseTheme.copyWith(
    colorScheme: baseTheme.colorScheme.copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      surface: cardColor,
      onSurface: textColor,
    ),
    textTheme: baseTheme.textTheme
        .apply(
          bodyColor: textColor,
          displayColor: textColor,
        )
        .copyWith(
          displayLarge: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w800,
              fontSize: 48,
              letterSpacing: -1,
              color: textColor),
          headlineSmall: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: textColor),
          titleLarge: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: textColor),
          titleMedium: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: textColor),
          bodyLarge:
              TextStyle(fontFamily: 'Manrope', fontSize: 14, color: textColor),
          bodyMedium:
              TextStyle(fontFamily: 'Manrope', fontSize: 12, color: textColor),
          bodySmall: TextStyle(
              fontFamily: 'Manrope',
              color: subtleTextColor,
              fontSize: 10,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w500),
          labelSmall: TextStyle(
              fontFamily: 'Manrope',
              color: subtleTextColor,
              fontSize: 10,
              letterSpacing: 0.5,
              fontWeight: FontWeight.bold),
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
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      titleTextStyle: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w800,
          fontSize: 22,
          color: textColor),
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: AppStyles.buttonRadius),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(
            fontFamily: 'Manrope', fontWeight: FontWeight.bold, fontSize: 16),
        elevation: 0,
      ),
    ),
    iconTheme: IconThemeData(color: textColor, size: 28),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: cardColor.withAlpha(204),
      selectedItemColor: AppColors.primary,
      unselectedItemColor: subtleTextColor,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle: const TextStyle(
          fontFamily: 'Manrope', fontSize: 10, fontWeight: FontWeight.bold),
      unselectedLabelStyle: const TextStyle(
          fontFamily: 'Manrope', fontSize: 10, fontWeight: FontWeight.bold),
    ),
  );
}
