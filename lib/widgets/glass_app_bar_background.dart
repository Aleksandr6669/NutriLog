import 'dart:ui';

import 'package:flutter/material.dart';

const double kGlassBlurSigma = 10.0;
const double kGlassSurfaceAlpha = 0.18;

class GlassAppBarBackground extends StatelessWidget {
  final Color? backgroundColor;

  const GlassAppBarBackground({super.key, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRect(
      child: BackdropFilter(
        filter:
            ImageFilter.blur(sigmaX: kGlassBlurSigma, sigmaY: kGlassBlurSigma),
        child: SizedBox.expand(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor ??
                  theme.colorScheme.surface
                      .withValues(alpha: kGlassSurfaceAlpha),
            ),
          ),
        ),
      ),
    );
  }
}

double glassAppBarTotalHeight(BuildContext context) {
  return MediaQuery.paddingOf(context).top + kToolbarHeight;
}

EdgeInsets glassBodyPadding(
  BuildContext context, {
  double left = 16,
  double top = 16,
  double right = 16,
  double bottom = 0,
}) {
  return EdgeInsets.fromLTRB(
    left,
    glassAppBarTotalHeight(context) + top,
    right,
    bottom,
  );
}

AppBar buildGlassAppBar({
  required Widget title,
  bool centerTitle = false,
  Widget? leading,
  List<Widget>? actions,
  double? titleSpacing,
  bool automaticallyImplyLeading = true,
  Color? backgroundColor,
}) {
  return AppBar(
    title: title,
    centerTitle: centerTitle,
    leading: leading,
    actions: actions,
    titleSpacing: titleSpacing,
    automaticallyImplyLeading: automaticallyImplyLeading,
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    forceMaterialTransparency: true,
    flexibleSpace: GlassAppBarBackground(backgroundColor: backgroundColor),
  );
}
