import 'dart:convert';

import 'package:flutter/material.dart';

import 'app_design_system.dart';
import 'app_text.dart';
import 'auth_api.dart';

class SocialProfileSection extends StatefulWidget {
  const SocialProfileSection({
    super.key,
    required this.api,
    required this.token,
    required this.userId,
    this.refreshVersion = 0,
    required this.onOpenCommunity,
    this.onCreatePost,
    required this.onProfileLoaded,
  });

  final AuthApi api;
  final String token;
  final int userId;
  final int refreshVersion;
  final Future<void> Function() onOpenCommunity;
  final VoidCallback? onCreatePost;
  final ValueChanged<Map<String, dynamic>> onProfileLoaded;

  @override
  State<SocialProfileSection> createState() => _SocialProfileSectionState();
}

class _SocialProfileSectionState extends State<SocialProfileSection> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SocialProfileSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshVersion != widget.refreshVersion) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final profile = await widget.api.socialUserProfile(
        token: widget.token,
        userId: widget.userId,
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
        _error = null;
      });
      widget.onProfileLoaded(profile);
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load your social profile: $error';
        });
      }
    }
  }

  Future<void> _openCommunity() async {
    await widget.onOpenCommunity();
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final posts = (_profile?['posts'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final businesses = (_profile?['businesses'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: AppText(
                    'Your experiences',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            if (_loading)
              const LinearProgressIndicator()
            else if (_error != null)
              Row(
                children: [
                  Expanded(child: AppText(_error!, localize: true)),
                  TextButton(
                    onPressed: _load,
                    child: const AppText('Retry', localize: true),
                  ),
                ],
              )
            else ...[
              if (socialPostingEnabled)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton.filled(
                    key: const ValueKey('social-create-post'),
                    tooltip: 'Share an experience',
                    onPressed: widget.onCreatePost ?? _openCommunity,
                    icon: const Icon(Icons.add_a_photo_outlined),
                  ),
                ),
              const SizedBox(height: 10),
              if (posts.isEmpty && businesses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: AppText(
                      'Share a photo or a story from your sports experiences.',
                      textAlign: TextAlign.center,
                      localize: true,
                    ),
                  ),
                )
              else
                GridView.builder(
                  key: const ValueKey('social-profile-post-grid'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 5,
                    mainAxisSpacing: 5,
                  ),
                  itemCount: posts.length + businesses.length > 6
                      ? 6
                      : posts.length + businesses.length,
                  itemBuilder: (context, index) => index < posts.length
                      ? _PostThumbnail(post: posts[index])
                      : _BusinessThumbnail(
                          business: businesses[index - posts.length],
                        ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BusinessThumbnail extends StatelessWidget {
  const _BusinessThumbnail({required this.business});

  final Map<String, dynamic> business;

  @override
  Widget build(BuildContext context) {
    final id = business['businessId'] ?? business['id'] ?? 'venue';
    final imageUrl = _businessImageUrl(business);
    final name = '${business['businessName'] ?? business['name'] ?? 'Venue'}'
        .trim();
    return ClipRRect(
      key: ValueKey('social-profile-business-$id'),
      borderRadius: BorderRadius.circular(7),
      child: Stack(
        fit: StackFit.expand,
        children: [
          imageUrl.isEmpty
              ? ColoredBox(
                  color: AppColors.softSurface,
                  child: const Icon(Icons.storefront_outlined),
                )
              : socialExperienceImage(imageUrl),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              color: Colors.black.withValues(alpha: .58),
              child: AppText(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _businessImageUrl(Map<String, dynamic> business) {
  for (final key in ['imageUrl', 'image_url', 'imageUrls', 'image_urls']) {
    final value = business[key];
    if (value is List) {
      for (final image in value.whereType<String>()) {
        if (image.trim().isNotEmpty) return image.trim();
      }
      continue;
    }
    if (value is! String || value.trim().isEmpty) continue;
    final raw = value.trim();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final image in decoded.whereType<String>()) {
          if (image.trim().isNotEmpty) return image.trim();
        }
        continue;
      }
    } on FormatException {
      return raw;
    }
    return raw;
  }
  return '';
}

class _PostThumbnail extends StatelessWidget {
  const _PostThumbnail({required this.post});

  final Map<String, dynamic> post;

  @override
  Widget build(BuildContext context) {
    final images = (post['images'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();
    return ClipRRect(
      key: ValueKey('social-profile-post-${post['id'] ?? 'unknown'}'),
      borderRadius: BorderRadius.circular(7),
      child: Stack(
        fit: StackFit.expand,
        children: [
          images.isEmpty
              ? Container(
                  color: AppColors.softSurface,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.format_quote_rounded),
                )
              : socialExperienceImage(images.first, fit: BoxFit.cover),
          Positioned(
            right: 4,
            bottom: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .68),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 11,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      _engagementCount(post['likeCount']),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.mode_comment_rounded,
                      color: Colors.white,
                      size: 10,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      _engagementCount(post['commentCount']),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _engagementCount(Object? value) =>
    '${value is num ? value.toInt() : int.tryParse('$value') ?? 0}';

Widget socialExperienceImage(String value, {BoxFit fit = BoxFit.cover}) {
  final match = RegExp(
    r'^data:image/(jpeg|jpg|png|webp);base64,([A-Za-z0-9+/]+={0,2})$',
    caseSensitive: false,
  ).firstMatch(value);
  if (match != null) {
    try {
      return Image.memory(
        base64Decode(match.group(2)!),
        fit: fit,
        errorBuilder: (_, _, _) => const _BrokenSocialImage(),
      );
    } on FormatException {
      return const _BrokenSocialImage();
    }
  }
  return Image.network(
    value,
    fit: fit,
    errorBuilder: (_, _, _) => const _BrokenSocialImage(),
  );
}

class _BrokenSocialImage extends StatelessWidget {
  const _BrokenSocialImage();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.softSurface,
    child: const Center(child: Icon(Icons.broken_image_outlined)),
  );
}
