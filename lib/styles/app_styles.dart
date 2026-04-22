import 'package:flutter/material.dart';
import 'package:nutri_log/styles/app_colors.dart';

class AppStyles {
  static final BorderRadius largeBorderRadius = BorderRadius.circular(32);
  static final BorderRadius defaultBorderRadius = BorderRadius.circular(24);
  static final BorderRadius cardRadius =
      BorderRadius.circular(16); // Updated for new design
  static final BorderRadius mediumBorderRadius = BorderRadius.circular(16);
  static final BorderRadius smallBorderRadius = BorderRadius.circular(10);
  static final BorderRadius buttonRadius = BorderRadius.circular(99);

  // Old outlined style, kept for compatibility if needed elsewhere
  static InputDecoration inputDecoration(String label, [IconData? icon]) {
    return InputDecoration(
      labelText: label,
      prefixIcon:
          icon != null ? Icon(icon, color: AppColors.primary, size: 24) : null,
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
      fillColor: Colors.white.withValues(alpha: 0.5),
    );
  }

  // New underline style from the mockup
  static InputDecoration underlineInputDecoration(
      {required String label, String? suffix}) {
    return InputDecoration(
      labelText: label,
      suffixText: suffix,
      alignLabelWithHint: true,
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 16),
      floatingLabelStyle: const TextStyle(color: AppColors.primary),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}
