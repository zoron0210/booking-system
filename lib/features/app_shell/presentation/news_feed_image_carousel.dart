import 'package:flutter/material.dart';

class NewsFeedImageCarousel extends StatefulWidget {
  const NewsFeedImageCarousel({
    super.key,
    required this.images,
    required this.imageBuilder,
  });

  static const cardHeight = 160.0;

  final List<String> images;
  final Widget Function(String value) imageBuilder;

  @override
  State<NewsFeedImageCarousel> createState() => _NewsFeedImageCarouselState();
}

class _NewsFeedImageCarouselState extends State<NewsFeedImageCarousel> {
  late final PageController _controller;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: widget.images.length > 1 ? widget.images.length * 1000 : 0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multiple = widget.images.length > 1;
    return SizedBox(
      height: NewsFeedImageCarousel.cardHeight,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: multiple ? null : 1,
            onPageChanged: (page) {
              setState(() => _index = page % widget.images.length);
            },
            itemBuilder: (_, page) =>
                widget.imageBuilder(widget.images[page % widget.images.length]),
          ),
          if (multiple)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var dot = 0; dot < widget.images.length; dot++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: dot == _index ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: dot == _index
                            ? Colors.white
                            : Colors.white.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
