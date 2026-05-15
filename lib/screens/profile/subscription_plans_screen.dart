import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:nutri_log/models/user_profile.dart';
import 'package:nutri_log/providers/profile_provider.dart';
import 'package:nutri_log/l10n/app_localizations.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  final SubscriptionTier? initialTier;
  const SubscriptionPlansScreen({super.key, this.initialTier});

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  late PageController _pageController;
  int _currentPage = 1; // Default to Standard

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>().profile;
    if (widget.initialTier != null) {
      _currentPage = widget.initialTier!.index;
    } else if (profile != null) {
      _currentPage = profile.tier.index;
    }
    _pageController = PageController(initialPage: _currentPage, viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectTier(SubscriptionTier tier) {
    final profile = context.read<ProfileProvider>().profile;
    if (profile == null) return;

    final subscriptionUntil = tier == SubscriptionTier.free 
        ? null 
        : DateTime.now().add(const Duration(days: 30));

    context.read<ProfileProvider>().updateProfile(
      profile.copyWith(
        tier: tier,
        subscriptionUntil: subscriptionUntil,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      extendBodyBehindAppBar: true,
      appBar: buildGlassAppBar(
        title: Text(l10n.chooseYourPlan, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: kToolbarHeight + 40),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              children: [
                _buildPlanCard(
                  tier: SubscriptionTier.free,
                  title: l10n.tierFree,
                  description: l10n.freePlanDesc,
                  icon: Symbols.person,
                  color: Colors.grey,
                  features: [
                    l10n.featureBasicDiary,
                    l10n.featureWaterSteps,
                    l10n.featureBasicRecipes,
                  ],
                ),
                _buildPlanCard(
                  tier: SubscriptionTier.standard,
                  title: l10n.tierStandard,
                  description: l10n.standardPlanDesc,
                  icon: Symbols.star,
                  color: Colors.blue,
                  features: [
                    l10n.featureAiScanner,
                    l10n.featureAiGoals,
                    l10n.featureUnlimitedRecipes,
                  ],
                  isPopular: true,
                ),
                _buildPlanCard(
                  tier: SubscriptionTier.premium,
                  title: l10n.tierPremium,
                  description: l10n.premiumPlanDesc,
                  icon: Symbols.workspace_premium,
                  color: Colors.amber.shade700,
                  features: [
                    l10n.featureAiScanner,
                    l10n.featureAiGoals,
                    l10n.featureAiAnalytics,
                    l10n.featureUnlimitedRecipes,
                    l10n.featurePersonalAdvice,
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          _buildPageIndicator(),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required SubscriptionTier tier,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required List<String> features,
    bool isPopular = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final profile = context.watch<ProfileProvider>().profile;
    final isCurrent = profile?.tier == tier;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: isCurrent ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          if (isPopular)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'POPULAR',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 48, color: color),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
                ),
                if (!isCurrent)
                  Text(
                    l10n.tapToSelectPlan,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.4),
                ),
                const Divider(height: 40),
                Text(
                  l10n.planFeatures.toUpperCase(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: features.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, size: 20, color: color.withValues(alpha: 0.6)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                features[index],
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isCurrent ? null : () => _selectTier(tier),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade200,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      isCurrent ? l10n.currentPlan : l10n.selectPlan,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isSelected = _currentPage == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isSelected ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
