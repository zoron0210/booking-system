import 'package:flutter/material.dart';

abstract final class SocialHomePalette {
  static const canvas = Color(0xFF0B1326);
  static const surface = Color(0xFF131B2E);
  static const surfaceRaised = Color(0xFF171F33);
  static const border = Color(0xFF29334A);
  static const text = Color(0xFFDAE2FD);
  static const muted = Color(0xFF929BB2);
  static const primary = Color(0xFF4F46E5);
  static const coral = Color(0xFFFF6B4A);
  static const mint = Color(0xFF10B981);
}

@immutable
class SocialHomeColors extends ThemeExtension<SocialHomeColors> {
  const SocialHomeColors({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.text,
    required this.muted,
    required this.primary,
    required this.coral,
    required this.mint,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color text;
  final Color muted;
  final Color primary;
  final Color coral;
  final Color mint;

  static SocialHomeColors of(BuildContext context) =>
      Theme.of(context).extension<SocialHomeColors>() ??
      const SocialHomeColors(
        canvas: SocialHomePalette.canvas,
        surface: SocialHomePalette.surface,
        surfaceRaised: SocialHomePalette.surfaceRaised,
        border: SocialHomePalette.border,
        text: SocialHomePalette.text,
        muted: SocialHomePalette.muted,
        primary: SocialHomePalette.primary,
        coral: SocialHomePalette.coral,
        mint: SocialHomePalette.mint,
      );

  static SocialHomeColors forBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const SocialHomeColors(
        canvas: SocialHomePalette.canvas,
        surface: SocialHomePalette.surface,
        surfaceRaised: SocialHomePalette.surfaceRaised,
        border: SocialHomePalette.border,
        text: SocialHomePalette.text,
        muted: SocialHomePalette.muted,
        primary: SocialHomePalette.primary,
        coral: SocialHomePalette.coral,
        mint: SocialHomePalette.mint,
      );
    }
    return const SocialHomeColors(
      canvas: Color(0xFFF5F6FA),
      surface: Colors.white,
      surfaceRaised: Color(0xFFEEF1F7),
      border: Color(0xFFD8DEEA),
      text: Color(0xFF182238),
      muted: Color(0xFF647089),
      primary: Color(0xFF4F46E5),
      coral: Color(0xFFD94B35),
      mint: Color(0xFF087F5B),
    );
  }

  @override
  SocialHomeColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? border,
    Color? text,
    Color? muted,
    Color? primary,
    Color? coral,
    Color? mint,
  }) => SocialHomeColors(
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    border: border ?? this.border,
    text: text ?? this.text,
    muted: muted ?? this.muted,
    primary: primary ?? this.primary,
    coral: coral ?? this.coral,
    mint: mint ?? this.mint,
  );

  @override
  SocialHomeColors lerp(
    covariant ThemeExtension<SocialHomeColors>? other,
    double t,
  ) {
    if (other is! SocialHomeColors) return this;
    return SocialHomeColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
    );
  }
}
