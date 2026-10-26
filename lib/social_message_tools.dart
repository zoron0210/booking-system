import 'package:flutter/material.dart';

import 'app_text.dart';
import 'auth_api.dart';

const _commonEmojis = [
  '😀',
  '😂',
  '😍',
  '🥰',
  '😎',
  '👏',
  '🙌',
  '👍',
  '❤️',
  '🔥',
  '🎉',
  '🏸',
  '⚽',
  '🏀',
  '🎾',
  '💪',
];

Future<String?> showSocialEmojiPicker(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final emoji in _commonEmojis)
                InkWell(
                  key: ValueKey('social-emoji-$emoji'),
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => Navigator.pop(context, emoji),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

Future<Map<String, dynamic>?> showTenorGifPicker(
  BuildContext context, {
  required AuthApi api,
  String? token,
}) => showModalBottomSheet<Map<String, dynamic>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _TenorGifPicker(api: api, token: token),
);

class _TenorGifPicker extends StatefulWidget {
  const _TenorGifPicker({required this.api, this.token});

  final AuthApi api;
  final String? token;

  @override
  State<_TenorGifPicker> createState() => _TenorGifPickerState();
}

class _TenorGifPickerState extends State<_TenorGifPicker> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _gifs = [];
  bool _loading = false;
  Object? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final gifs = await widget.api.searchSocialGifs(
        query,
        token: widget.token,
      );
      if (mounted) setState(() => _gifs = gifs);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      16,
      12,
      16,
      16 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(
              child: AppText(
                'Search GIFs',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            hintText: 'Search Tenor',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              onPressed: _loading ? null : _search,
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          AppText('GIF search failed: $_error', localize: true),
        if (!_loading && _error == null && _gifs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: AppText('Search for a GIF to share.', localize: true),
          ),
        Flexible(
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: _gifs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final gif = _gifs[index];
              final url = gif['url'];
              if (url is! String) return const SizedBox.shrink();
              return InkWell(
                onTap: () => Navigator.pop(context, gif),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Center(child: Icon(Icons.broken_image_outlined)),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
