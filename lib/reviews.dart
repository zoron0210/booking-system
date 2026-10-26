import './app_design_system.dart';
import 'rating_widgets.dart';

import 'dart:convert';

import 'package:flutter/material.dart';

import 'skeleton_loader.dart';

import 'auth_api.dart';
import 'features/session/application/session_service.dart';
import 'guest_access.dart';
import 'app_preferences.dart';
import 'public_user_profile.dart';
import 'social_community_page.dart';

class ReviewsSheet extends StatefulWidget {
  const ReviewsSheet({
    super.key,
    required this.api,
    required this.businessId,
    required this.businessName,
    this.isEvent = false,
    this.onSubmitted,
  });

  final AuthApi api;
  final int businessId;
  final String businessName;
  final bool isEvent;
  final void Function(double average, int reviewCount, int ratedUsers)?
  onSubmitted;

  @override
  State<ReviewsSheet> createState() => _ReviewsSheetState();
}

class _ReviewsSheetState extends State<ReviewsSheet> {
  List<VenueReview> _reviews = const [];
  Object? _error;
  var _loading = true;
  var _rating = 5;
  var _submitting = false;
  var _hasAuthenticatedSession = false;
  var _canSubmitReview = false;
  var _eligibilityMessage =
      'Complete a booking at this venue before reviewing it.';
  final _comment = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final token = (await AppSessionService.instance.load()).apiToken;
      final hasAuthenticatedSession = token?.isNotEmpty == true;
      final reviews = await widget.api.venues.newsReviews(
        token: token,
        businessId: widget.businessId,
      );
      var canSubmit = false;
      var eligibilityMessage = 'Log in to review this venue after booking.';
      if (token != null && token.isNotEmpty) {
        final bookings = await widget.api.customerBookingModels(token);
        final venueBookings = bookings.where(
          (booking) => booking.venue.id == widget.businessId,
        );
        final finishedBooking = venueBookings.where(
          (booking) => booking.status == 'finished',
        );
        canSubmit = finishedBooking.any((booking) => booking.reviewId == null);
        eligibilityMessage = canSubmit
            ? ''
            : finishedBooking.isEmpty
            ? 'Only customers with a completed booking can submit a review.'
            : 'You already reviewed your completed booking.';
      }
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _hasAuthenticatedSession = hasAuthenticatedSession;
          _canSubmitReview = canSubmit;
          _eligibilityMessage = eligibilityMessage;
          _loading = false;
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _submitReview() async {
    final token = (await AppSessionService.instance.load()).apiToken;
    if (token == null || token.isEmpty) {
      _showError('Please sign in to submit a review.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.api.venues.createNewsReview(
        token: token,
        businessId: widget.businessId,
        rating: _rating,
        comment: _comment.text.trim(),
      );
      _comment.clear();
      await _loadReviews();
      final ratings = _ratingSummary;
      widget.onSubmitted?.call(
        ratings.average,
        _reviews.length,
        ratings.ratedUsers,
      );
    } on Exception catch (error) {
      _showError('$error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: AppText(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratedUsers = _reviews.length;
    final average = _reviews.isEmpty
        ? 0.0
        : _reviews
                  .map((review) => review.rating.toDouble())
                  .fold<double>(0, (total, value) => total + value) /
              _reviews.length;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7DCE4),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              AppText(
                widget.isEvent
                    ? '${widget.businessName} ratings & reviews'
                    : '${widget.businessName} reviews',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              if (_loading)
                Expanded(
                  child: ListView(
                    key: const ValueKey('reviews-loading-skeleton'),
                    padding: EdgeInsets.zero,
                    children: const [
                      SkeletonBlock(width: 90, height: 30),
                      SizedBox(height: 6),
                      SkeletonBlock(height: 12),
                      SizedBox(height: 6),
                      SkeletonBlock(height: 12, width: 210),
                      Divider(height: 28),
                      SkeletonBlock(height: 76, borderRadius: 14),
                      SizedBox(height: 6),
                      SkeletonBlock(height: 76, borderRadius: 14),
                      SizedBox(height: 6),
                      SkeletonBlock(height: 76, borderRadius: 14),
                    ],
                  ),
                )
              else if (_error != null)
                _errorState()
              else ...[
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    AppText(
                      _reviews.isEmpty
                          ? 'New venue'
                          : average.toStringAsFixed(1),
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    AppRatingStars(rating: average, size: 18, spacing: 1),
                    AppText(
                      '${_reviews.length} ${_reviews.length == 1 ? 'review' : 'reviews'} · $ratedUsers rated',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      localize: true,
                    ),
                  ],
                ),
                const Divider(height: 24),
                Expanded(child: _reviewList()),
                const Divider(height: 24),
                _reviewForm(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorState() => Expanded(
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppText('Could not load reviews.', localize: true),
          AppText('$_error', textAlign: TextAlign.center),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _loadReviews();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const AppText('Try again', localize: true),
          ),
        ],
      ),
    ),
  );

  ({double average, int ratedUsers}) get _ratingSummary {
    final ratings = _reviews.map((review) => review.rating.toDouble()).toList();
    final average = ratings.isEmpty
        ? 0.0
        : ratings.reduce((total, rating) => total + rating) / ratings.length;
    final ratedUsers = _reviews.length;
    return (average: average, ratedUsers: ratedUsers);
  }

  Widget _reviewList() {
    if (_reviews.isEmpty) {
      return Center(
        child: AppText(
          widget.isEvent
              ? 'No ratings yet. Complete an event booking to leave the first rating and review.'
              : 'No reviews yet. Be the first to rate this venue after a completed booking.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      itemCount: _reviews.length,
      separatorBuilder: (_, _) => const Divider(height: 20),
      itemBuilder: (_, index) {
        final review = _reviews[index];
        final name = [
          review.firstName?.trim() ?? '',
          review.lastName?.trim() ?? '',
        ].where((value) => value.isNotEmpty).join(' ');
        final avatarUrl = review.avatarUrl?.trim() ?? '';
        final avatar = _reviewAvatar(avatarUrl);
        final reviewImage = _reviewAvatar(review.imageData?.trim() ?? '');
        final rating = review.rating;
        final normalizedRating = rating.clamp(0, 5);
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: InkWell(
            key: ValueKey(
              'review-user-avatar-${review.customerId ?? review.id}',
            ),
            customBorder: const CircleBorder(),
            onTap: !socialProfileUiEnabled || review.customerId == null
                ? null
                : () async {
                    final token =
                        (await AppSessionService.instance.load()).apiToken;
              if (!mounted) return;
                    await showPublicUserProfileDialog(
                      context: context,
                      api: widget.api,
                      token: token,
                      userId: review.customerId!,
                      onViewProfile: () async {
                        if (!mounted) return;
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => SocialPersonPage(
                              api: widget.api,
                              token: token,
                              userId: review.customerId!,
                            ),
                          ),
                        );
                      },
                    );
                  },
            child: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.softOrange,
              child: avatar == null
                  ? _reviewInitial(name)
                  : ClipOval(
                      child: Image(
                        image: avatar,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _reviewInitial(name),
                      ),
                    ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: AppText(
                  name.isEmpty ? 'Customer' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              AppRatingStars(
                key: ValueKey('review-rating-stars-$index'),
                rating: normalizedRating.toDouble(),
                allowHalfStars: false,
                semanticLabel: '$normalizedRating out of 5 stars',
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (review.comment?.isNotEmpty == true) AppText(review.comment!),
              if (reviewImage != null) ...[
                if (review.comment?.isNotEmpty == true)
                  const SizedBox(height: 6),
                Semantics(
                  button: true,
                  label: appLanguageText(
                    'View review photo',
                    'Tingnan ang larawan ng review',
                  ),
                  child: InkWell(
                    key: ValueKey('review-photo-tap-$index'),
                    onTap: () => _showReviewPhoto(reviewImage),
                    borderRadius: BorderRadius.circular(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image(
                        key: ValueKey('review-photo-$index'),
                        image: reviewImage,
                        width: double.infinity,
                        height: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _showReviewPhoto(ImageProvider<Object> image) =>
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: appLanguageText(
          'Close review photo',
          'Isara ang larawan ng review',
        ),
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (dialogContext, animation, secondaryAnimation) => SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Image(
                      key: const ValueKey('review-photo-fullscreen'),
                      image: image,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  key: const ValueKey('review-photo-close'),
                  tooltip: appLanguageText(
                    'Close review photo',
                    'Isara ang larawan ng review',
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        transitionBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      );

  ImageProvider<Object>? _reviewAvatar(String value) {
    if (value.startsWith('data:image/')) {
      final separator = value.indexOf(',');
      if (separator < 0) return null;
      try {
        return MemoryImage(base64Decode(value.substring(separator + 1)));
      } on FormatException {
        return null;
      }
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      return null;
    }
    return NetworkImage(value);
  }

  Widget _reviewInitial(String name) => AppText(
    name.isEmpty ? 'U' : name[0].toUpperCase(),
    style: const TextStyle(fontWeight: FontWeight.w700),
  );

  Widget _reviewForm() {
    if (!_canSubmitReview) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.page,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline_rounded, color: AppColors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    _eligibilityMessage,
                    style: TextStyle(color: AppColors.muted, height: 1.35),
                  ),
                  if (!_hasAuthenticatedSession) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () async {
                        if (await requireCustomerLogin(context) && mounted) {
                          await _loadReviews();
                        }
                      },
                      child: const AppText(
                        'Log in to continue',
                        localize: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          widget.isEvent
              ? 'Rate this event venue after your completed booking'
              : 'Leave a review after your completed booking',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        AppRatingInput(
          rating: _rating,
          onChanged: (rating) => setState(() => _rating = rating),
          keyPrefix: 'review-rating-star-',
          tooltipForRating: (rating) => appLanguageText(
            'Rate $rating out of 5 stars',
            'Rate $rating out of 5 stars',
          ),
          enabled: !_submitting,
        ),
        TextField(
          controller: _comment,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: appLanguageText('Comment', 'Comment'),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : _submitReview,
            child: AppText(
              _submitting
                  ? 'Submitting...'
                  : widget.isEvent
                  ? 'Submit rating'
                  : 'Submit review',
            ),
          ),
        ),
      ],
    );
  }
}
