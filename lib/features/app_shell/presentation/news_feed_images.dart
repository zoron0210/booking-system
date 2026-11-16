part of 'news_feed.dart';

class _AsyncBase64Image extends StatefulWidget {
  const _AsyncBase64Image({
    required this.encodedData,
    required this.fit,
    required this.placeholder,
    required this.fallback,
    this.width,
    this.height,
  });

  final String encodedData;
  final BoxFit fit;
  final Widget placeholder;
  final Widget fallback;
  final double? width;
  final double? height;

  @override
  State<_AsyncBase64Image> createState() => _AsyncBase64ImageState();
}

class _AsyncBase64ImageState extends State<_AsyncBase64Image> {
  late Future<Uint8List?> _decodedData;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant _AsyncBase64Image oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.encodedData != oldWidget.encodedData) _decode();
  }

  void _decode() {
    _decodedData = compute(_decodeBase64Image, widget.encodedData);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _decodedData,
    builder: (context, snapshot) {
      final bytes = snapshot.data;
      if (snapshot.hasError ||
          (snapshot.connectionState == ConnectionState.done && bytes == null)) {
        return widget.fallback;
      }
      if (bytes == null) return widget.placeholder;
      return Image.memory(
        bytes,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => widget.fallback,
      );
    },
  );
}

Uint8List? _decodeBase64Image(String encodedData) {
  try {
    return base64Decode(encodedData);
  } on FormatException {
    return null;
  }
}
