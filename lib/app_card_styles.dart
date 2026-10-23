import 'package:flutter/material.dart';

import 'app_design_system.dart';

abstract final class AppCardStyles {
  static Color get borderColor => AppColors.border;
  static const marketplaceRadius = AppRadii.marketplaceCard;
  static const merchantRadius = AppRadii.merchantCard;
  static const marketplaceImageAspectRatio = 16 / 10;
  static const merchantImageHeight = 150.0;
  static const elevation = 0.0;

  static List<BoxShadow> get raisedShadows => [
    BoxShadow(
      color: AppColors.neumorphicShadow.withValues(alpha: .18),
      blurRadius: 18,
      spreadRadius: 0,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get insetShadows => [
    BoxShadow(
      color: AppColors.neumorphicShadow.withValues(alpha: .14),
      blurRadius: 12,
      spreadRadius: 0,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: AppColors.neumorphicHighlight.withValues(alpha: .92),
      blurRadius: 8,
      spreadRadius: 0,
      offset: const Offset(0, -1),
    ),
  ];

  static BoxDecoration surfaceDecoration({
    Color? color,
    double radius = AppRadii.marketplaceCard,
    bool inset = false,
    Border? border,
  }) => BoxDecoration(
    color: color ?? AppColors.surface,
    borderRadius: BorderRadius.circular(radius),
    border: border ?? Border.all(color: AppColors.border),
    boxShadow: inset ? insetShadows : raisedShadows,
  );

  static RoundedRectangleBorder get marketplaceShape => RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(marketplaceRadius)),
    side: BorderSide(color: borderColor),
  );

  static RoundedRectangleBorder get merchantShape => RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(merchantRadius)),
    side: BorderSide(color: borderColor),
  );
}
