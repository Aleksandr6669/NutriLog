import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:nutri_log/l10n/app_localizations.dart';

import 'providers/profile_provider.dart';

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
import 'screens/profile/user_agreement_screen.dart';
import 'screens/profile/changelog_screen.dart';
import 'screens/profile/connections_notifications_screen.dart';
import 'screens/recipes/create_recipe_from_description_screen.dart';
import 'screens/recipes/create_recipe_from_photo_screen.dart';
import 'screens/recipes/edit_recipe_screen.dart';
import 'screens/recipes/recipe_detail_screen.dart';
import 'models/daily_log.dart';
import 'models/recipe.dart';
import 'models/food_item.dart';
import 'models/user_profile.dart';
import 'main.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  observers: [UnfocusOnRouteChangeObserver()],
  routes: <RouteBase>[
    // --- Начальные экраны ---
    GoRoute(
      path: '/',
      builder: (context, state) => const AppBootstrapScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => OnboardingScreen(
        onCompleted: () async {
          await context.read<ProfileProvider>().reloadProfile();
          if (context.mounted) context.go('/home');
        },
      ),
    ),
    GoRoute(
      path: '/whats_new',
      builder: (context, state) {
        final version = state.uri.queryParameters['version'] ?? 'Unknown';
        final text = state.uri.queryParameters['text'] ?? '';
        return WhatsNewScreen(
          version: version,
          text: text,
          onAcknowledged: () async => context.go('/home'),
        );
      },
    ),

    // --- Основное меню (с нижней навигацией) ---
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainScreenShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/home', builder: (context, state) => const HomeScreen())
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/recipes',
              builder: (context, state) => const RecipesScreen())
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/stats', builder: (context, state) => const StatsScreen())
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen())
        ]),
      ],
    ),

    // --- Вторичные экраны (без нижней навигации) ---

    // Дневник: Детали приёма пищи, Вес, Активность
    GoRoute(
      path: '/meal/:type',
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        final type = state.pathParameters['type'] ?? 'snacks';
        final extra = state.extra as Map<String, dynamic>?;

        String mealName;
        switch (type) {
          case 'breakfast':
            mealName = l10n.breakfast;
            break;
          case 'lunch':
            mealName = l10n.lunch;
            break;
          case 'dinner':
            mealName = l10n.dinner;
            break;
          case 'snacks':
            mealName = l10n.snacks;
            break;
          default:
            mealName = extra?['mealName'] as String? ?? l10n.meals;
        }

        return MealDetailScreen(
          mealName: mealName,
          items: (extra?['items'] as List?)?.cast<FoodItem>() ?? <FoodItem>[],
          date: extra?['date'] as DateTime? ?? DateTime.now(),
        );
      },
    ),
    GoRoute(
      path: '/weight',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final date = extra?['date'] as DateTime? ?? DateTime.now();
        return WeightEntryScreen(date: date);
      },
    ),
    GoRoute(
      path: '/activity',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return ActivityLogScreen(
          date: extra?['date'] as DateTime? ?? DateTime.now(),
          initialActivities:
              (extra?['initialActivities'] as List?)?.cast<ActivityEntry>() ??
                  <ActivityEntry>[],
        );
      },
    ),

    // Рецепты: Детали, Создание (Фото/Описание/Вручную)
    GoRoute(
      path: '/recipe_detail',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return RecipeDetailScreen(
          recipe: extra?['recipe'] as Recipe,
          selectionMode: extra?['selectionMode'] as bool? ?? false,
          isSelected: extra?['isSelected'] as bool? ?? false,
        );
      },
    ),
    GoRoute(
      path: '/recipe/create_photo',
      builder: (context, state) => const CreateRecipeFromPhotoScreen(),
    ),
    GoRoute(
      path: '/recipe/create_description',
      builder: (context, state) => const CreateRecipeFromDescriptionScreen(),
    ),
    GoRoute(
      path: '/recipe/edit',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return EditRecipeScreen(
          recipe: extra?['recipe'] as Recipe?,
          initialDraft: extra?['initialDraft'] as Recipe?,
        );
      },
    ),

    // Профиль: Редактирование параметров и целей
    GoRoute(
      path: '/profile/physical',
      builder: (context, state) => EditPhysicalParamsScreen(
          profile: (state.extra as Map)['profile'] as UserProfile),
    ),
    GoRoute(
      path: '/profile/general_goals',
      builder: (context, state) => EditGeneralGoalsScreen(
          profile: (state.extra as Map)['profile'] as UserProfile),
    ),
    GoRoute(
      path: '/profile/daily_goals',
      builder: (context, state) => EditGoalsScreen(
          profile: (state.extra as Map)['profile'] as UserProfile),
    ),
    GoRoute(
      path: '/profile/connections',
      builder: (context, state) => const ConnectionsNotificationsScreen(),
    ),
    GoRoute(
      path: '/profile/agreement',
      builder: (context, state) => const UserAgreementScreen(),
    ),
    GoRoute(
      path: '/profile/changelog',
      builder: (context, state) => const ChangelogScreen(),
    ),
  ],
);
