import 'package:flutter/material.dart';
import 'package:nutri_log/styles/app_colors.dart';

class AppStyles {
  static final BorderRadius largeBorderRadius = BorderRadius.circular(32);
  static final BorderRadius defaultBorderRadius = BorderRadius.circular(24);
  static final BorderRadius cardRadius = BorderRadius.circular(28);
  static final BorderRadius mediumBorderRadius = BorderRadius.circular(16);
  static final BorderRadius smallBorderRadius = BorderRadius.circular(10);
  static final BorderRadius buttonRadius = BorderRadius.circular(99);

  static InputDecoration inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary, size: 24),
      border: OutlineInputBorder(
        borderRadius: mediumBorderRadius,
        borderSide: const BorderSide(color: Colors.grey, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: mediumBorderRadius,
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: mediumBorderRadius,
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      floatingLabelStyle: const TextStyle(color: AppColors.primary),
      filled: true,
      fillColor: Colors.white.withOpacity(0.5),
    );
  }
}
