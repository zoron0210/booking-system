import 'package:flutter/material.dart';

class AppRatingStars extends StatelessWidget {
  const AppRatingStars({
    super.key,
    required this.rating,
    this.size = 16,
    this.color = Colors.amber,
    this.spacing = 0,
    this.allowHalfStars = true,
    this.semanticLabel,
  });

  final double rating;
  final double size;
  final Color color;
  final double spacing;
  final bool allowHalfStars;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final value = rating.clamp(0, 5);
    return Semantics(
      label: semanticLabel ?? '${value.toStringAsFixed(1)} out of 5 stars',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var star = 1; star <= 5; star++) ...[
              if (star > 1 && spacing > 0) SizedBox(width: spacing),
              Icon(
                value >= star
                    ? Icons.star_rounded
                    : allowHalfStars && value >= star - .5
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
                color: color,
                size: size,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppRatingInput extends StatelessWidget {
  const AppRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    required this.keyPrefix,
    required this.tooltipForRating,
    this.enabled = true,
    this.size = 30,
    this.color = Colors.amber,
  });

  final int rating;
  final ValueChanged<int> onChanged;
  final String keyPrefix;
  final String Function(int rating) tooltipForRating;
  final bool enabled;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var star = 1; star <= 5; star++)
        IconButton(
          tooltip: tooltipForRating(star),
          onPressed: enabled ? () => onChanged(star) : null,
          icon: Icon(
            key: ValueKey('$keyPrefix$star'),
            star <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
            color: color,
            size: size,
          ),
        ),
    ],
  );
}
