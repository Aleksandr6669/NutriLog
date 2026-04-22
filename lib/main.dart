import 'dart:async';
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

final ValueNotifier<String?> _startupWarningMessage = ValueNotifier(null);
final ValueNotifier<_FatalAppError?> _fatalAppError = ValueNotifier(null);

class _FatalAppError {
  final String title;
  final String details;

  const _FatalAppError({
    required this.title,
    required this.details,
  });
}

void _reportStartupWarning(String message) {
  if (_startupWarningMessage.value == message) return;
  _startupWarningMessage.value = message;
}

void _reportFatalAppError(String title, Object error, [StackTrace? stackTrace]) {
  final detailsBuffer = StringBuffer()
    ..writeln(error.toString());

  if (stackTrace != null) {
    final lines = stackTrace
        .toString()
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .take(6);
    if (lines.isNotEmpty) {
      detailsBuffer
        ..writeln()
        ..writeAll(lines, '\n');
    }
  }

  final fatalError = _FatalAppError(
    title: title,
    details: detailsBuffer.toString().trim(),
  );

  _fatalAppError.value = fatalError;
  debugPrint('FATAL_APP_ERROR: $title');
  debugPrint(fatalError.details);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);

    // Не переводим всё приложение в фатальный экран из-за локальных ошибок
    // (например, жесты выделения текста в одном конкретном виджете).
    // Фатальными считаем только uncaught zone/platform ошибки.
    debugPrint('FLUTTER_ERROR: ${details.exceptionAsString()}');
    if (details.stack != null) {
      final lines = details.stack
          .toString()
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .take(6)
          .join('\n');
      debugPrint(lines);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    _reportFatalAppError(
      'Необработанная ошибка платформы',
      error,
      stack,
    );
    return true;
  };

  ErrorWidget.builder = (details) {
    _reportFatalAppError(
      'Виджет не смог построиться',
      details.exception,
      details.stack,
    );
    return _FatalErrorScreen(
      title: 'Интерфейс не загрузился',
      message: details.exception.toString(),
    );
  };

  // Критично быстро показать UI: тяжелые сервисы инициализируем в фоне.
  _bootstrapServices();
  GoogleFonts.config.allowRuntimeFetching = false;

  runZonedGuarded(
    () => runApp(const MyApp()),
    (error, stackTrace) {
      _reportFatalAppError(
        'Необработанная ошибка приложения',
        error,
        stackTrace,
      );
    },
  );
}

Future<void> _bootstrapServices() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env может отсутствовать в локальной среде.
    _reportStartupWarning('Не удалось загрузить .env. AI-функции могут быть недоступны.');
  }

  try {
    await initializeDateFormatting('ru_RU', null);
  } catch (_) {
    // Не блокируем запуск приложения из-за локализации дат.
    _reportStartupWarning('Локализация дат не инициализировалась. Форматы дат могут быть упрощены.');
  }

  if (!kIsWeb) {
    try {
      final notificationService = AppNotificationService();
      final notificationSettingsService = NotificationSettingsService();
      await notificationService.initialize();
      final settings = await notificationSettingsService.load();
      await notificationService.applySettings(settings);
    } catch (_) {
      // Плагины уведомлений не должны ломать старт UI.
      _reportStartupWarning('Не удалось поднять уведомления. Приложение запущено в безопасном режиме.');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriLog',
      theme: _buildTheme(Brightness.light),
      debugShowCheckedModeBanner: false,
      navigatorObservers: [_UnfocusOnRouteChangeObserver()],
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
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        return ValueListenableBuilder<_FatalAppError?>(
          valueListenable: _fatalAppError,
          builder: (context, fatalError, _) {
            if (fatalError != null) {
              return _FatalErrorScreen(
                title: fatalError.title,
                message: fatalError.details,
              );
            }

            return ValueListenableBuilder<String?>(
              valueListenable: _startupWarningMessage,
              builder: (context, warningMessage, _) {
                return Stack(
                  children: [
                    content,
                    if (warningMessage != null)
                      _StartupWarningBanner(
                        message: warningMessage,
                        onClose: () => _startupWarningMessage.value = null,
                      ),
                  ],
                );
              },
            );
          },
        );
      },
      home: const AppBootstrapScreen(),
    );
  }
}

class _UnfocusOnRouteChangeObserver extends NavigatorObserver {
  _UnfocusOnRouteChangeObserver();

  void _clearFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _clearFocus();
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _clearFocus();
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _clearFocus();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
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
    StartupState state;
    try {
      state = await _startupService.loadState();
    } catch (_) {
      // Защита от зависания стартового экрана при сбое plugin/prefs.
      _reportStartupWarning(
        'Стартовые данные не загрузились. Приложение открылось без онбординга и уведомлений о новой версии.',
      );
      state = const StartupState(
        needsOnboarding: false,
        whatsNewText: null,
        currentVersion: '0.0.0+0',
      );
    }
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
    // На iOS предотвращаем кейс, когда при смене вкладки остается активный
    // EditableText и система пытается показать toolbar без корректного Overlay.
    FocusManager.instance.primaryFocus?.unfocus();

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

class _StartupWarningBanner extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  const _StartupWarningBanner({
    required this.message,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.paddingOf(context).top + 12;

    return Positioned(
      top: topPadding,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: kGlassBlurSigma,
              sigmaY: kGlassBlurSigma,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                border: Border.all(
                  color: const Color(0xFFFF8A65).withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3EE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Symbols.warning_rounded,
                      color: Color(0xFFD96B45),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Безопасный запуск',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF3D2A22),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF6B554D),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Symbols.close_rounded),
                    color: const Color(0xFF7A6258),
                    tooltip: 'Закрыть',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FatalErrorScreen extends StatelessWidget {
  final String title;
  final String message;

  const _FatalErrorScreen({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F3EF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1EC),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Symbols.error_rounded,
                      color: Color(0xFFD46546),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2F221D),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Приложение перехватило ошибку вместо белого экрана. Ниже причина, которую можно сразу прислать для фикса.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF69554D),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE8DDD5),
                      ),
                    ),
                    child: Text(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: const Color(0xFF4C3B33),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
