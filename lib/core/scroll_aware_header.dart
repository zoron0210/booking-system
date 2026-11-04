import 'package:flutter/material.dart';

class ScrollAwareHeader extends StatefulWidget {
  const ScrollAwareHeader({
    super.key,
    required this.header,
    required this.body,
  });

  final Widget header;
  final Widget body;

  @override
  State<ScrollAwareHeader> createState() => _ScrollAwareHeaderState();
}

class _ScrollAwareHeaderState extends State<ScrollAwareHeader> {
  var _headerVisible = true;

  bool _handleScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    final delta = notification is ScrollUpdateNotification
        ? notification.scrollDelta
        : null;
    final shouldShow =
        notification.metrics.pixels <=
            notification.metrics.minScrollExtent + 1 ||
        delta != null && delta < 0;
    final shouldHide = delta != null && delta > 0;
    if ((shouldShow && !_headerVisible) || (shouldHide && _headerVisible)) {
      setState(() => _headerVisible = shouldShow);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ClipRect(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          curve: Curves.easeInOut,
          child: _headerVisible ? widget.header : const SizedBox.shrink(),
        ),
      ),
      Expanded(
        child: NotificationListener<ScrollNotification>(
          onNotification: _handleScroll,
          child: widget.body,
        ),
      ),
    ],
  );
}
