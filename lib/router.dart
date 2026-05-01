import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'screens/onboarding/onboarding_screen.dart';
import 'screens/onboarding/whats_new_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/recipes/recipes_screen.dart';
import 'screens/stats/stats_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/meal_detail/meal_detail_screen.dart';
import 'screens/home/weight_entry_screen.dart';
import 'screens/home/activity_log_screen.dart';
import 'screens/profile/edit_goals_screen.dart';
import 'screens/profile/edit_general_goals_screen.dart';
import 'screens/profile/edit_physical_params_screen.dart';
import 'services/app_startup_service.dart';
import 'main.dart'; // For AppBootstrapScreen, MainScreen

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  observers: [UnfocusOnRouteChangeObserver()],
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const AppBootstrapScreen();
      },
    ),
    GoRoute(
      path: '/onboarding',
      builder: (BuildContext context, GoRouterState state) {
        return OnboardingScreen(
          onCompleted: () async {
            context.go('/home');
          },
        );
      },
    ),
    GoRoute(
      path: '/whats_new',
      builder: (BuildContext context, GoRouterState state) {
        final version = state.uri.queryParameters['version'] ?? 'Unknown';
        final text = state.uri.queryParameters['text'] ?? '';
        return WhatsNewScreen(
          version: version,
          text: text,
          onAcknowledged: () async {
            context.go('/home');
          },
        );
      },
    ),
    StatefulShellRoute.indexedStack(
      builder: (BuildContext context, GoRouterState state, StatefulNavigationShell navigationShell) {
        return MainScreenShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/recipes',
              builder: (context, state) => const RecipesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/stats',
              builder: (context, state) => const StatsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/meal',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final type = extra?['type'] as String?;
        String mealName;
        switch (type) {
          case 'breakfast':
            mealName = 'Завтрак';
            break;
          case 'lunch':
            mealName = 'Обед';
            break;
          case 'dinner':
            mealName = 'Ужин';
            break;
          default:
            mealName = type ?? 'Приём пищи';
        }
        return MealDetailScreen(
          mealName: mealName,
          items: const [],
          date: DateTime.now(),
        );
      },
    ),
    GoRoute(
      path: '/weight',
      builder: (context, state) => WeightEntryScreen(date: DateTime.now()),
    ),
    GoRoute(
      path: '/activity',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final date = extra?['date'] as DateTime? ?? DateTime.now();
        final initialActivities = extra?['initialActivities'] as List<ActivityEntry>? ?? [];
        return ActivityLogScreen(
          date: date,
          initialActivities: initialActivities,
        );
      },
    ),
    // Other top-level screens can be added here
  ],
);
