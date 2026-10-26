import 'package:flutter/material.dart';

import '../../../app_text.dart';

class SocialProfileStats extends StatelessWidget {
  const SocialProfileStats({
    super.key,
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.foregroundColor,
    required this.mutedColor,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  final Object? postsCount;
  final Object? followersCount;
  final Object? followingCount;
  final Color foregroundColor;
  final Color mutedColor;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _count(postsCount, 'Posts'),
      const SizedBox(width: 24),
      _count(followersCount, 'Followers', onTap: onFollowersTap),
      const SizedBox(width: 24),
      _count(followingCount, 'Following', onTap: onFollowingTap),
    ],
  );

  Widget _count(Object? value, String label, {VoidCallback? onTap}) => InkWell(
    key: ValueKey('profile-social-count-${label.toLowerCase()}'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            '${value is num ? value.toInt() : 0}',
            style: TextStyle(
              color: foregroundColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          AppText(
            label,
            style: TextStyle(color: mutedColor, fontSize: 11),
            localize: true,
          ),
        ],
      ),
    ),
  );
}
