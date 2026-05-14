import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/recipe.dart';
import '../../models/user_profile.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/recipe_loader.dart';
import '../../services/recipe_service.dart';
import '../../styles/app_colors.dart';
import '../../styles/app_styles.dart';
import '../../widgets/glass_app_bar_background.dart';
import 'fab_menu_item.dart';
import 'package:provider/provider.dart';
import '../../providers/profile_provider.dart';
import '../../l10n/app_localizations.dart';

class RecipesScreen extends StatefulWidget {
  final bool selectionMode;
  final Set<String> initialSelectedRecipeIds;

  const RecipesScreen({
    super.key,
    this.selectionMode = false,
    this.initialSelectedRecipeIds = const <String>{},
  });

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  String? _streamErrorMessage;
  final _searchController = TextEditingController();
  final RecipeService _recipeService = RecipeService();

  List<Recipe> _allRecipes = [];
  List<Recipe> _filteredRecipes = [];
  bool _isLoading = true;
  bool _selectedRecipesCollapsed = true;
  bool _isDeleteSelectionMode = false;
  late Map<String, int> _selectedRecipeCounts;
  final List<String> _selectedOrder = [];
  final Set<String> _selectedRecipeIdsForDelete = <String>{};
  bool _showFabMenu = false;
  String _locale = 'ru';
  StreamSubscription<List<Recipe>>? _publicRecipesSubscription;
  StreamSubscription<List<Recipe>>? _privateRecipesSubscription;
  StreamSubscription<void>? _cacheUpdatesSubscription;
  final Set<String> _knownRealtimeRecipeIds = <String>{};
  String? _highlightedAppearedRecipeId;
  bool _isRecipeFeedInitialized = false;
  List<Recipe> _cachedDefaultRecipes = const [];
  String? _cachedDefaultRecipesLocale;

  String _cloudAccessErrorText() {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'uk') {
      return 'Немає доступу до хмари. Спробуйте пізніше.';
    }
    if (code == 'en') {
      return 'No cloud access right now. Please try again later.';
    }
    return 'Нет доступа к облаку. Попробуйте позже.';
  }

  @override
  void initState() {
    super.initState();
    _selectedRecipeCounts = {
      for (final id in widget.initialSelectedRecipeIds) id: 1,
    };
    _selectedOrder.addAll(widget.initialSelectedRecipeIds);
    _searchController.addListener(_filterRecipes);
    _startPublicRecipesStream();
    _startPrivateRecipesStream();
    _cacheUpdatesSubscription = _recipeService.cacheUpdates.listen((_) {
      if (!mounted) return;
      _loadAllRecipes();
    });
    // Перезапускаем стримы при изменении авторизации
    FirebaseAuthService.instance.authStateChanges().listen((_) {
      if (mounted) {
        _startPublicRecipesStream();
        _startPrivateRecipesStream();
      }
    });
  }

  void _startPublicRecipesStream() {
    _publicRecipesSubscription?.cancel();
    if (!FirebaseAuthService.instance.isSignedIn) return;

    _publicRecipesSubscription = _recipeService.publicRecipesStream().listen(
      (_) {
        if (mounted) {
          setState(() {
            _streamErrorMessage = null;
          });
          _loadAllRecipes();
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() {
            _streamErrorMessage = _cloudAccessErrorText();
          });
        }
      },
    );
  }

  void _startPrivateRecipesStream() {
    _privateRecipesSubscription?.cancel();
    if (!FirebaseAuthService.instance.isSignedIn) return;

    _privateRecipesSubscription = _recipeService.privateRecipesStream().listen(
      (_) {
        if (mounted) {
          setState(() {
            _streamErrorMessage = null;
          });
          _loadAllRecipes();
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() {
            _streamErrorMessage = _cloudAccessErrorText();
          });
        }
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newLocale = Localizations.localeOf(context).languageCode;
    if (newLocale != _locale || _allRecipes.isEmpty) {
      _locale = newLocale;
      _loadAllRecipes();
    }
  }

  void _addRecipeSelection(Recipe recipe) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedRecipeCounts[recipe.id] =
          (_selectedRecipeCounts[recipe.id] ?? 0) + 1;
      if (!_selectedOrder.contains(recipe.id)) {
        _selectedOrder.insert(0, recipe.id);
      }
    });
  }

  void _removeRecipeSelection(Recipe recipe) {
    _decrementRecipeSelection(recipe);
  }

  void _decrementRecipeSelection(Recipe recipe) {
    HapticFeedback.lightImpact();
    setState(() {
      final current = _selectedRecipeCounts[recipe.id] ?? 0;
      if (current <= 1) {
        _selectedRecipeCounts.remove(recipe.id);
        _selectedOrder.remove(recipe.id);
      } else {
        _selectedRecipeCounts[recipe.id] = current - 1;
      }
    });
  }

  Future<void> _openRecipeDetail(Recipe recipe) async {
    HapticFeedback.selectionClick();
    if (!widget.selectionMode) {
      await _navigateAndRefreshRoute('/recipe_detail',
          extra: {'recipe': recipe});
      return;
    }

    final isSelected = (_selectedRecipeCounts[recipe.id] ?? 0) > 0;
    final detailResult = await context.push<bool>(
      '/recipe_detail',
      extra: {
        'recipe': recipe,
        'selectionMode': true,
        'isSelected': isSelected,
      },
    );

    if (detailResult == null) return;

    if (detailResult) {
      _addRecipeSelection(recipe);
    }
  }

  void _finishSelection() {
    final selectedRecipes = <Recipe>[];
    // Используем _selectedOrder в обратном порядке (от старых к новым),
    // чтобы при добавлении в общий список и последующем реверсе в UI
    // новые элементы оказались сверху.
    for (final id in _selectedOrder.reversed) {
      final recipe = _allRecipes.firstWhere((r) => r.id == id,
          orElse: () => Recipe.empty());
      if (recipe.id.isEmpty) continue;
      final count = _selectedRecipeCounts[id] ?? 1;
      for (int i = 0; i < count; i++) {
        selectedRecipes.add(recipe);
      }
    }
    Navigator.of(context).pop(selectedRecipes);
  }

  Widget _buildSelectedRecipesBar(ThemeData theme) {
    if (!widget.selectionMode || _selectedRecipeCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedRecipes = _selectedOrder
        .map((id) => _allRecipes.firstWhere((r) => r.id == id,
            orElse: () => Recipe.empty()))
        .where((r) => r.id.isNotEmpty)
        .toList();
    final canCollapse = selectedRecipes.length > 3;
    final visibleRecipes = selectedRecipes;
    final screenHeight = MediaQuery.of(context).size.height;
    const oneCardHeight = 76.0;
    final collapsedMaxHeight = screenHeight * 0.24;
    final expandedMaxHeight = (screenHeight * 0.78) - oneCardHeight;
    final panelListMaxHeight =
        _selectedRecipesCollapsed ? collapsedMaxHeight : expandedMaxHeight;
    final panelColor = AppColors.primary.withAlpha(24);
    final itemBgColor = Colors.white.withAlpha(220);
    const iconColor = AppColors.primary;
    final recipeTiles = visibleRecipes.map(
      (recipe) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: itemBgColor,
              borderRadius: AppStyles.smallBorderRadius,
            ),
            child: Row(
              children: [
                Icon(
                  recipe.icon,
                  size: 18,
                  color: iconColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recipe.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: (_selectedRecipeCounts[recipe.id] ?? 0) > 1
                      ? Container(
                          key: ValueKey(_selectedRecipeCounts[recipe.id]),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '×${_selectedRecipeCounts[recipe.id]}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey(0)),
                ),
                IconButton(
                  icon: const Icon(Symbols.remove_circle, size: 18),
                  color: iconColor,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _removeRecipeSelection(recipe),
                  tooltip: AppLocalizations.of(context)!.deselect,
                ),
              ],
            ),
          ),
        );
      },
    ).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: AppStyles.mediumBorderRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: panelListMaxHeight),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(children: recipeTiles),
                  ),
                ),
              ),
            ),
            if (canCollapse)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedRecipesCollapsed = !_selectedRecipesCollapsed;
                    });
                  },
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        _selectedRecipesCollapsed
                            ? Symbols.expand_more
                            : Symbols.expand_less,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _selectedRecipesCollapsed
                            ? AppLocalizations.of(context)!.showAll
                            : AppLocalizations.of(context)!.collapse,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadAllRecipes() async {
    final shouldShowLoader = _allRecipes.isEmpty;
    if (shouldShowLoader) {
      setState(() => _isLoading = true);
    }

    if (_cachedDefaultRecipesLocale != _locale ||
        _cachedDefaultRecipes.isEmpty) {
      _cachedDefaultRecipes =
          await RecipeLoader.loadRecipesFromAssets(locale: _locale);
      _cachedDefaultRecipesLocale = _locale;
    }

    final userRecipes = await _recipeService.loadUserRecipes();

    // Дата создания закодирована в ID: recipe_{microseconds}_{hash}
    int createdAt(Recipe r) {
      final parts = r.id.split('_');
      if (parts.length >= 3) return int.tryParse(parts[1]) ?? 0;
      if (parts.length == 2) return int.tryParse(parts[1]) ?? 0;
      // Поддержка старых id, где timestamp был целиком числом.
      return int.tryParse(r.id) ?? 0;
    }

    List<Recipe> dedupeById(List<Recipe> recipes) {
      final byId = <String, Recipe>{};
      for (final recipe in recipes) {
        final id = recipe.id.trim();
        if (id.isEmpty) continue;
        final existing = byId[id];
        if (existing == null) {
          byId[id] = recipe;
          continue;
        }
        final preferIncoming = recipe.isUserRecipe && !existing.isUserRecipe;
        final preferExisting = existing.isUserRecipe && !recipe.isUserRecipe;
        final preferExistingPrivateOverIncomingPublic = existing.isUserRecipe &&
            !existing.isPublic &&
            recipe.isUserRecipe &&
            recipe.isPublic;
        final preferIncomingPrivateOverExistingPublic = recipe.isUserRecipe &&
            !recipe.isPublic &&
            existing.isUserRecipe &&
            existing.isPublic;

        String pickString(String current, String next) {
          if (preferExistingPrivateOverIncomingPublic) {
            return current.isNotEmpty ? current : next;
          }
          if (preferIncomingPrivateOverExistingPublic) {
            return next.isNotEmpty ? next : current;
          }
          if (preferIncoming) return next.isNotEmpty ? next : current;
          if (preferExisting) return current.isNotEmpty ? current : next;
          return next.isNotEmpty ? next : current;
        }

        byId[id] = existing.copyWith(
          name: pickString(existing.name, recipe.name),
          description: pickString(existing.description, recipe.description),
          nutrients: recipe.nutrients.isNotEmpty
              ? recipe.nutrients
              : existing.nutrients,
          ingredients: recipe.ingredients.isNotEmpty
              ? recipe.ingredients
              : existing.ingredients,
          instructions: recipe.instructions.isNotEmpty
              ? recipe.instructions
              : existing.instructions,
          icon: recipe.icon,
          isUserRecipe: existing.isUserRecipe || recipe.isUserRecipe,
          isPublic: existing.isPublic || recipe.isPublic,
          isDonated: existing.isDonated || recipe.isDonated,
        );
      }
      return byId.values.toList(growable: false);
    }

    // 1. Свои рецепты — по дате создания, новые первыми
    final dedupedUserRecipes = dedupeById(userRecipes);

    final ownRecipes = dedupedUserRecipes
        .where((r) => r.isUserRecipe && !r.isDonated)
        .toList()
      ..sort((a, b) => createdAt(b).compareTo(createdAt(a)));
    // 2. Публичные рецепты других пользователей — по дате создания, новые первыми
    final othersRecipes = dedupedUserRecipes
        .where((r) =>
            (r.isPublic || r.isDonated) && (!r.isUserRecipe || r.isDonated))
        .toList()
      ..sort((a, b) => createdAt(b).compareTo(createdAt(a)));

    final appearedIds = dedupedUserRecipes.map((r) => r.id).toSet();
    String? nextHighlightedRecipeId = _highlightedAppearedRecipeId;
    if (_isRecipeFeedInitialized) {
      final newIds = appearedIds.difference(_knownRealtimeRecipeIds);
      if (newIds.isNotEmpty) {
        final newestAppearedRecipe = dedupedUserRecipes.toList()
          ..sort((a, b) => createdAt(b).compareTo(createdAt(a)));
        final matched = newestAppearedRecipe
            .where((r) => newIds.contains(r.id))
            .cast<Recipe?>()
            .firstWhere((_) => true, orElse: () => null);
        if (matched != null) {
          nextHighlightedRecipeId = matched.id;
        }
      }
    }
    _knownRealtimeRecipeIds
      ..clear()
      ..addAll(appearedIds);
    _isRecipeFeedInitialized = true;

    // 3. Встроенные рецепты из ассетов
    final allRecipes = [
      ...ownRecipes,
      ...othersRecipes,
      ..._cachedDefaultRecipes
    ];

    setState(() {
      _highlightedAppearedRecipeId = nextHighlightedRecipeId;
      _allRecipes = allRecipes;
      final query = _searchController.text.toLowerCase();
      _filteredRecipes = query.isEmpty
          ? _allRecipes
          : _allRecipes.where((recipe) {
              return recipe.name.toLowerCase().contains(query) ||
                  recipe.description.toLowerCase().contains(query);
            }).toList(growable: false);
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _publicRecipesSubscription?.cancel();
    _privateRecipesSubscription?.cancel();
    _cacheUpdatesSubscription?.cancel();
    _searchController.removeListener(_filterRecipes);
    _searchController.dispose();
    super.dispose();
  }

  void _filterRecipes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredRecipes = _allRecipes.where((recipe) {
        return recipe.name.toLowerCase().contains(query) ||
            recipe.description.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _editRecipe(Recipe recipe) async {
    await _navigateAndRefreshRoute('/recipe/edit', extra: {'recipe': recipe});
  }

  void _toggleDeleteSelectionMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isDeleteSelectionMode = !_isDeleteSelectionMode;

      // Когда входим в режим удаления, очищаем поиск и показываем все рецепты
      if (_isDeleteSelectionMode) {
        _searchController.clear();
        _filteredRecipes = _allRecipes;
      } else {
        _selectedRecipeIdsForDelete.clear();
        // Восстанавливаем фильтрацию по текущему поисковому запросу
        _filterRecipes();
      }
    });
  }

  void _toggleRecipeForDelete(Recipe recipe) {
    HapticFeedback.lightImpact();
    if (!recipe.isUserRecipe || recipe.isDonated) {
      return;
    }
    // SnackBar при успешных действиях убран по требованию

    setState(() {
      if (_selectedRecipeIdsForDelete.contains(recipe.id)) {
        _selectedRecipeIdsForDelete.remove(recipe.id);
      } else {
        _selectedRecipeIdsForDelete.add(recipe.id);
      }
    });
  }

  Future<void> _deleteSelectedRecipes() async {
    HapticFeedback.heavyImpact();
    if (_selectedRecipeIdsForDelete.isEmpty) return;

    final byId = {for (final r in _allRecipes) r.id: r};
    final ids = _selectedRecipeIdsForDelete.where((id) {
      final recipe = byId[id];
      return recipe != null && recipe.isUserRecipe && !recipe.isDonated;
    }).toList(growable: false);
    for (final id in ids) {
      await _recipeService.deleteRecipe(id);
    }

    if (!mounted) return;

    setState(() {
      _isDeleteSelectionMode = false;
      _selectedRecipeIdsForDelete.clear();
    });

    await _loadAllRecipes();
    // SnackBar больше не показываем
  }

  Future<void> _deleteRecipe(Recipe recipe) async {
    HapticFeedback.mediumImpact();
    await _recipeService.deleteRecipe(recipe.id);
    _loadAllRecipes();
    // SnackBar больше не показываем
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = context.watch<ProfileProvider>().profile;
    final isAiAvailable = profile?.isAiFeatureAvailable ?? false;
    // final fabBottomInset = MediaQuery.of(context).padding.bottom + 8; // не используется
    final fixedTopInset = glassAppBarTotalHeight(context) + 8;

    final fixedSearch = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: ClipRRect(
        borderRadius: AppStyles.defaultBorderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: kGlassBlurSigma,
            sigmaY: kGlassBlurSigma,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface
                  .withValues(alpha: kGlassSurfaceAlpha),
              borderRadius: AppStyles.defaultBorderRadius,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.18),
              ),
            ),
            child: _buildSearchField(isFloatingGlass: true),
          ),
        ),
      ),
    );

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey[50],
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            forceMaterialTransparency: true,
            flexibleSpace: const GlassAppBarBackground(),
            title: Text(
              widget.selectionMode
                  ? AppLocalizations.of(context)!.addToMeal
                  : AppLocalizations.of(context)!.myRecipes,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
            actions: [
              if (widget.selectionMode)
                IconButton(
                  icon: const Icon(Symbols.check_circle, size: 28),
                  onPressed: _finishSelection,
                  tooltip: AppLocalizations.of(context)!.ready,
                )
              else
                IconButton(
                  onPressed: _toggleDeleteSelectionMode,
                  icon: Icon(
                    _isDeleteSelectionMode
                        ? Icons.close_rounded
                        : Icons.check_box_outlined,
                    size: 28,
                  ),
                  tooltip: _isDeleteSelectionMode
                      ? AppLocalizations.of(context)!.cancelSelection
                      : AppLocalizations.of(context)!.select,
                ),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  SizedBox(height: fixedTopInset),
                  fixedSearch,
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _buildSelectedRecipesBar(theme),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.selectionMode
                            ? AppLocalizations.of(context)!.swipeToSelectHint
                            : AppLocalizations.of(context)!
                                .swipeToEditDeleteHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        if (_isLoading)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_filteredRecipes.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _buildEmptyState(),
                          )
                        else
                          _buildRecipesList(),
                      ],
                    ),
                  ),
                ],
              ),
              if (_streamErrorMessage != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      _streamErrorMessage!,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: null,
          floatingActionButton: null,
        ),
        if (_showFabMenu)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _showFabMenu = false),
              child: Container(
                color: Colors.black.withValues(alpha: 0.15),
              ),
            ),
          ),
        if (!widget.selectionMode)
          Positioned(
            right: 24,
            bottom: (MediaQuery.of(context).padding.bottom + 26),
            child: _isDeleteSelectionMode
                ? _buildDeleteFab()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_showFabMenu) ...[
                        FabMenuItem(
                          key: UniqueKey(),
                          icon: Symbols.barcode_scanner,
                          label: AppLocalizations.of(context)!.bySmartScanner,
                          isLocked: !isAiAvailable,
                          onTap: () async {
                            setState(() => _showFabMenu = false);
                            final profile = context.read<ProfileProvider>().profile;
                            if (profile == null || !profile.isAiFeatureAvailable) {
                              context.push('/subscription', extra: SubscriptionTier.standard);
                              return;
                            }
                            await _navigateAndRefreshRoute('/recipe/scanner');
                          },
                          delay: const Duration(milliseconds: 150),
                        ),
                        const SizedBox(height: 12),
                        FabMenuItem(
                          key: UniqueKey(),
                          icon: Symbols.edit_note,
                          label: AppLocalizations.of(context)!.byDescription,
                          isLocked: !isAiAvailable,
                          onTap: () async {
                            setState(() => _showFabMenu = false);
                            final profile = context.read<ProfileProvider>().profile;
                            if (profile == null || !profile.isAiFeatureAvailable) {
                              context.push('/subscription', extra: SubscriptionTier.standard);
                              return;
                            }
                            await _navigateAndRefreshRoute(
                                '/recipe/create_description');
                          },
                          delay: const Duration(milliseconds: 100),
                        ),
                        const SizedBox(height: 12),
                        FabMenuItem(
                          key: UniqueKey(),
                          icon: Symbols.draw,
                          label: AppLocalizations.of(context)!.manually,
                          onTap: () async {
                            setState(() => _showFabMenu = false);
                            await _navigateAndRefreshRoute('/recipe/edit');
                          },
                          delay: const Duration(milliseconds: 0),
                        ),
                        const SizedBox(height: 16),
                      ],
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _showFabMenu = !_showFabMenu);
                        },
                        child: AnimatedRotation(
                          turns: _showFabMenu ? 0.125 : 0.0,
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeInOutCubic,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeInOut,
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withAlpha(100),
                                  blurRadius: _showFabMenu ? 8 : 12,
                                  spreadRadius: _showFabMenu ? 1 : 2,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Symbols.add,
                              color: Colors.white,
                              size: 30,
                              weight: 700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }

  Widget _buildDeleteFab() {
    final hasSelection = _selectedRecipeIdsForDelete.isNotEmpty;
    return GestureDetector(
      onTap: hasSelection ? _deleteSelectedRecipes : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hasSelection ? Colors.red : Colors.grey.shade400,
          boxShadow: hasSelection
              ? [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: const Icon(
          Symbols.delete,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

  Widget _buildSearchField({bool isFloatingGlass = false}) {
    final inputBorder = OutlineInputBorder(
      borderRadius: AppStyles.defaultBorderRadius,
      borderSide: BorderSide.none,
    );

    return Padding(
      padding: isFloatingGlass
          ? const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0)
          : const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.searchRecipe,
          prefixIcon: Icon(Symbols.search, color: Colors.grey.shade600),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Symbols.close, color: Colors.grey.shade600),
                  tooltip: AppLocalizations.of(context)!.clearSearchTooltip,
                  onPressed: () {
                    _searchController.clear();
                    _filterRecipes();
                  },
                )
              : null,
          filled: true,
          fillColor: isFloatingGlass
              ? Colors.white.withValues(alpha: 0.28)
              : Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          border: inputBorder,
          enabledBorder: inputBorder,
          focusedBorder: inputBorder,
        ),
      ),
    );
  }

  Widget _buildRecipesList() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final recipe = _filteredRecipes[index];
            final isSelected = (_selectedRecipeCounts[recipe.id] ?? 0) > 0;
            final item = _RecipeListItem(
              recipe: recipe,
              isHighlighted: recipe.id == _highlightedAppearedRecipeId,
              onHighlightCompleted: () {
                if (!mounted) return;
                if (_highlightedAppearedRecipeId != recipe.id) return;
                setState(() => _highlightedAppearedRecipeId = null);
              },
              isSelectionMode: widget.selectionMode || _isDeleteSelectionMode,
              isDeleteMode: _isDeleteSelectionMode && !widget.selectionMode,
              canSelectInDeleteMode: recipe.isUserRecipe && !recipe.isDonated,
              isSelected: isSelected,
              isDeleteSelected: _selectedRecipeIdsForDelete.contains(recipe.id),
              selectedCount: _selectedRecipeCounts[recipe.id] ?? 0,
              onTap: () {
                if (widget.selectionMode) {
                  _addRecipeSelection(recipe);
                  return;
                }
                if (_isDeleteSelectionMode) {
                  if (!recipe.isUserRecipe || recipe.isDonated) return;
                  _toggleRecipeForDelete(recipe);
                  return;
                }
                _openRecipeDetail(recipe);
              },
              onActionTap: widget.selectionMode
                  ? () => _addRecipeSelection(recipe)
                  : (_isDeleteSelectionMode &&
                          recipe.isUserRecipe &&
                          !recipe.isDonated
                      ? () => _toggleRecipeForDelete(recipe)
                      : null),
            );

            if (widget.selectionMode) {
              return Dismissible(
                key: ValueKey('recipe-select-${recipe.id}-$isSelected'),
                direction: DismissDirection.horizontal,
                background: _buildSwipeBackground(
                  alignment: Alignment.centerLeft,
                  color: Colors.red.shade400,
                  icon: Symbols.remove_circle,
                  label: AppLocalizations.of(context)!.removeOnePortion,
                ),
                secondaryBackground: _buildSwipeBackground(
                  alignment: Alignment.centerRight,
                  color: AppColors.primary,
                  icon: Symbols.add_circle,
                  label: AppLocalizations.of(context)!.addMore,
                ),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.endToStart) {
                    _addRecipeSelection(recipe);
                  } else if (direction == DismissDirection.startToEnd) {
                    _decrementRecipeSelection(recipe);
                  }
                  return false;
                },
                child: item,
              );
            }

            if (!recipe.isUserRecipe || recipe.isDonated) return item;

            return Dismissible(
              key: ValueKey('recipe-swipe-${recipe.id}'),
              direction: DismissDirection.horizontal,
              background: _buildSwipeBackground(
                alignment: Alignment.centerLeft,
                color: Colors.blue.shade600,
                icon: Symbols.edit,
                label: AppLocalizations.of(context)!.edit,
              ),
              secondaryBackground: _buildSwipeBackground(
                alignment: Alignment.centerRight,
                color: Colors.red.shade600,
                icon: Symbols.delete,
                label: AppLocalizations.of(context)!.delete,
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  await _editRecipe(recipe);
                  return false;
                }
                if (direction == DismissDirection.endToStart) {
                  await _deleteRecipe(recipe);
                  return true;
                }
                return false;
              },
              child: item,
            );
          },
          childCount: _filteredRecipes.length,
        ),
      ),
    );
  }

  Widget _buildSwipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppStyles.cardRadius,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      child: Row(
        mainAxisAlignment: alignment == Alignment.centerLeft
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (alignment == Alignment.centerRight)
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          if (alignment == Alignment.centerRight) const SizedBox(width: 8),
          Icon(icon, color: Colors.white),
          if (alignment == Alignment.centerLeft) const SizedBox(width: 8),
          if (alignment == Alignment.centerLeft)
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchController.text.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Symbols.search_off : Symbols.receipt_long,
            size: 80,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
          const SizedBox(height: 24),
          Text(
            isSearching
                ? AppLocalizations.of(context)!.nothingFound
                : AppLocalizations.of(context)!.noRecipesYet,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              isSearching
                  ? AppLocalizations.of(context)!.tryChangingQuery
                  : AppLocalizations.of(context)!.pressPlusToAdd,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateAndRefreshRoute(String path, {Object? extra}) async {
    final result = await context.push(path, extra: extra);
    if (result == true) {
      _loadAllRecipes();
    }
  }
}

class _RecipeListItem extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final bool isHighlighted;
  final bool isSelectionMode;
  final bool isDeleteMode;
  final bool canSelectInDeleteMode;
  final bool isSelected;
  final bool isDeleteSelected;
  final int selectedCount;
  final VoidCallback? onActionTap;
  final VoidCallback? onHighlightCompleted;

  const _RecipeListItem({
    required this.recipe,
    required this.onTap,
    this.isHighlighted = false,
    this.isSelectionMode = false,
    this.isDeleteMode = false,
    this.canSelectInDeleteMode = true,
    this.isSelected = false,
    this.isDeleteSelected = false,
    this.selectedCount = 0,
    this.onActionTap,
    this.onHighlightCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final rawCalories = recipe.nutrients['calories'];
    final calories = ((rawCalories as num?) ?? 0).round();
    final isOwnRecipe = recipe.isUserRecipe && !recipe.isDonated;

    final card = Card(
      color: Colors.white,
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: AppStyles.cardRadius,
        side: BorderSide.none,
      ),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppStyles.cardRadius,
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.05),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(recipe.icon,
                            color: theme.colorScheme.primary, size: 28),
                      ),
                      if (isSelectionMode && !isDeleteMode && selectedCount > 0)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              key: ValueKey(selectedCount),
                              constraints: const BoxConstraints(
                                  minWidth: 20, minHeight: 20),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 5),
                              decoration: BoxDecoration(
                                color: selectedCount > 1
                                    ? AppColors.primary
                                    : Colors.green.shade600,
                                borderRadius: BorderRadius.circular(999),
                                border:
                                    Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: Text(
                                selectedCount > 1 ? '$selectedCount' : '✓',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (recipe.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3.0),
                            child: Text(
                              recipe.description,
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (!isSelectionMode)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$calories ${l10n.kcal}',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isOwnRecipe)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  l10n.myRecipe,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            if (!isOwnRecipe)
                              Icon(
                                Symbols.info,
                                color: theme.colorScheme.primary,
                                size: 18,
                              ),
                          ],
                        ),
                      ],
                    )
                  else if (!isDeleteMode || canSelectInDeleteMode)
                    IconButton(
                      icon: Icon(
                        isDeleteMode
                            ? (isDeleteSelected
                                ? Symbols.check_circle
                                : Symbols.radio_button_unchecked)
                            : (isSelected
                                ? Symbols.check_circle
                                : Symbols.add_circle),
                        color: isDeleteMode
                            ? (isDeleteSelected
                                ? Colors.red
                                : theme.colorScheme.primary)
                            : (isSelected
                                ? Colors.green.shade600
                                : theme.colorScheme.primary),
                      ),
                      onPressed: onActionTap,
                      tooltip: isDeleteMode
                          ? (isDeleteSelected ? l10n.deselect : l10n.select)
                          : l10n.add,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final highlightedCard = isHighlighted
        ? _AppearedRecipeHighlight(
            onCompleted: onHighlightCompleted,
            child: card,
          )
        : card;

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: highlightedCard,
      ),
    );
  }
}

class _AppearedRecipeHighlight extends StatefulWidget {
  final Widget child;
  final VoidCallback? onCompleted;

  const _AppearedRecipeHighlight({required this.child, this.onCompleted});

  @override
  State<_AppearedRecipeHighlight> createState() =>
      _AppearedRecipeHighlightState();
}

class _AppearedRecipeHighlightState extends State<_AppearedRecipeHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_notified) {
          _notified = true;
          widget.onCompleted?.call();
        }
      });
    _rotationController.forward();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationController,
      child: widget.child,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: AppStyles.cardRadius,
          child: CustomPaint(
            foregroundPainter: _AppearedRecipeBorderPainter(
              progress: _rotationController.value,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _AppearedRecipeBorderPainter extends CustomPainter {
  final double progress;

  const _AppearedRecipeBorderPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Используем радиус карточки для точного совпадения
    final borderRadius = AppStyles.cardRadius.topLeft;
    final outerRRect = RRect.fromRectAndRadius(
      rect.deflate(2.0),
      borderRadius,
    );
    final innerRRect = RRect.fromRectAndRadius(
      rect.deflate(4.4),
      Radius.circular(borderRadius.x - 3),
    );

    final outerPath = Path()..addRRect(outerRRect);
    final innerPath = Path()..addRRect(innerRRect);
    final outerMetric = outerPath.computeMetrics().first;
    final innerMetric = innerPath.computeMetrics().first;

    final outerArcLength = outerMetric.length * 0.21;
    final innerArcLength = innerMetric.length * 0.14;
    final outerOffset = outerMetric.length * progress;
    final innerOffset = innerMetric.length * ((progress + 0.42) % 1.0);

    final outerSegment = outerMetric.extractPath(
      outerOffset,
      outerOffset + outerArcLength,
      startWithMoveTo: true,
    );
    final innerSegment = innerMetric.extractPath(
      innerOffset,
      innerOffset + innerArcLength,
      startWithMoveTo: true,
    );

    final outerPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final innerPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(outerSegment, outerPaint);
    canvas.drawPath(innerSegment, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _AppearedRecipeBorderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
