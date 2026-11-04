import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class PremiumRefreshGate {
  PremiumRefreshGate({this.cooldown = const Duration(milliseconds: 900)});

  final Duration cooldown;
  final Stopwatch _clock = Stopwatch()..start();
  Future<void>? _activeRefresh;
  Duration? _lastRefreshFinished;

  Future<void> run(Future<void> Function() refresh) {
    final activeRefresh = _activeRefresh;
    if (activeRefresh != null) return activeRefresh;

    final lastRefreshFinished = _lastRefreshFinished;
    if (lastRefreshFinished != null) {
      final elapsed = _clock.elapsed - lastRefreshFinished;
      final remaining = cooldown - elapsed;
      if (remaining > Duration.zero) return Future<void>.delayed(remaining);
    }

    late final Future<void> request;
    request = refresh().whenComplete(() {
      _lastRefreshFinished = _clock.elapsed;
      if (identical(_activeRefresh, request)) _activeRefresh = null;
    });
    _activeRefresh = request;
    return request;
  }
}

class PremiumPressScale extends StatefulWidget {
  const PremiumPressScale({super.key, required this.child});

  final Widget child;

  @override
  State<PremiumPressScale> createState() => _PremiumPressScaleState();
}

class _PremiumPressScaleState extends State<PremiumPressScale> {
  int? _activePointer;
  bool _pressed = false;

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    setState(() => _pressed = true);
  }

  void _handlePointerEnd(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: AnimatedScale(
        scale: _pressed ? .9 : 1,
        duration: Duration(
          milliseconds: reduceMotion
              ? 0
              : _pressed
              ? 100
              : 470,
        ),
        curve: _pressed ? Curves.easeInCubic : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}

class PremiumScrollBehavior extends MaterialScrollBehavior {
  const PremiumScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      RefreshResistantScrollPhysics(parent: super.getScrollPhysics(context));
}

class RefreshResistantScrollPhysics extends ScrollPhysics {
  const RefreshResistantScrollPhysics({super.parent});

  @override
  RefreshResistantScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      RefreshResistantScrollPhysics(parent: buildParent(ancestor));

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (position.axisDirection == AxisDirection.down &&
        value < position.minScrollExtent) {
      if (position.pixels >= position.minScrollExtent) {
        return (value - position.minScrollExtent) * .65;
      }
      if (value < position.pixels) {
        return (value - position.pixels) * .65;
      }
    }
    return super.applyBoundaryConditions(position, value);
  }
}

class PremiumExpandable extends StatelessWidget {
  const PremiumExpandable({
    super.key,
    required this.expanded,
    required this.child,
  });

  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedSize(
      alignment: Alignment.topCenter,
      duration: Duration(milliseconds: reduceMotion ? 0 : 350),
      curve: Curves.easeOutCubic,
      child: ClipRect(
        child: ExcludeSemantics(
          excluding: !expanded,
          child: IgnorePointer(
            ignoring: !expanded,
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: expanded ? 1 : 0,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class RollingNumber extends StatelessWidget {
  const RollingNumber({
    super.key,
    required this.value,
    required this.style,
    this.fractionDigits = 0,
    this.prefix = '',
    this.suffix = '',
  });

  final num value;
  final TextStyle style;
  final int fractionDigits;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) => RollingDigits(
    value: '$prefix${value.toStringAsFixed(fractionDigits)}$suffix',
    style: style,
  );
}

class RollingDigits extends StatelessWidget {
  const RollingDigits({super.key, required this.value, required this.style});

  final String value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final tabularStyle = style.copyWith(
      fontFeatures: [...?style.fontFeatures, ui.FontFeature.tabularFigures()],
    );
    var trailingDigits = 0;
    final children = List<Widget>.filled(value.length, const SizedBox.shrink());
    for (var index = value.length - 1; index >= 0; index--) {
      final character = value[index];
      if (_isDigit(character)) {
        children[index] = _RollingDigit(
          key: ValueKey('rolling-digit-$index'),
          character: character,
          staggerIndex: trailingDigits++,
          style: tabularStyle,
        );
      } else {
        children[index] = Text(character, style: tabularStyle);
      }
    }

    return Semantics(
      label: value,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Reserve the complete label width while individual digits animate.
          ExcludeSemantics(
            child: Opacity(opacity: 0, child: Text(value, style: tabularStyle)),
          ),
          ExcludeSemantics(
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ],
      ),
    );
  }

  bool _isDigit(String character) =>
      character.codeUnitAt(0) >= 48 && character.codeUnitAt(0) <= 57;
}

class _RollingDigit extends StatefulWidget {
  const _RollingDigit({
    super.key,
    required this.character,
    required this.staggerIndex,
    required this.style,
  });

  final String character;
  final int staggerIndex;
  final TextStyle style;

  @override
  State<_RollingDigit> createState() => _RollingDigitState();
}

class _RollingDigitState extends State<_RollingDigit> {
  late String _displayedCharacter = widget.character;
  Timer? _stagger;

  @override
  void didUpdateWidget(covariant _RollingDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character == widget.character) return;
    _stagger?.cancel();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _stagger = Timer(
      Duration(milliseconds: reduceMotion ? 0 : widget.staggerIndex * 100),
      () {
        if (mounted) setState(() => _displayedCharacter = widget.character);
      },
    );
  }

  @override
  void dispose() {
    _stagger?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduceMotion ? 0 : 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => ClipRect(
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, .8),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Text(
        _displayedCharacter,
        key: ValueKey(_displayedCharacter),
        style: widget.style,
      ),
    );
  }
}

class SuccessCheckmark extends StatefulWidget {
  const SuccessCheckmark({
    super.key,
    this.size = 24,
    this.color = const Color(0xFF168B69),
    this.strokeWidth = 2.5,
  });

  final double size;
  final Color color;
  final double strokeWidth;

  @override
  State<SuccessCheckmark> createState() => _SuccessCheckmarkState();
}

class _SuccessCheckmarkState extends State<SuccessCheckmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 470),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Success',
    child: SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _SuccessCheckPainter(
            progress: _controller.value,
            color: widget.color,
            strokeWidth: widget.strokeWidth,
          ),
        ),
      ),
    ),
  );
}

class _SuccessCheckPainter extends CustomPainter {
  const _SuccessCheckPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final circle = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    final circleProgress = (progress / .64).clamp(0, 1);
    for (final metric in circle.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * circleProgress),
        paint,
      );
    }

    final checkProgress = ((progress - .64) / .36).clamp(0, 1);
    if (checkProgress == 0) return;
    final check = Path()
      ..moveTo(size.width * .27, size.height * .52)
      ..lineTo(size.width * .44, size.height * .68)
      ..lineTo(size.width * .75, size.height * .35);
    for (final metric in check.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * checkProgress),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SuccessCheckPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
