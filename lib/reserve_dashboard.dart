// The booking-type picker remains in this file for the customer reservation flow.
// ignore_for_file: unused_element

import 'package:flutter/material.dart';

import 'event_dashboard.dart';
import 'fitness_dashboard.dart';
import 'features/session/application/session_service.dart';
import 'news_feed.dart';
import 'app_design_system.dart';

import 'app_preferences.dart';

Color get _background => AppColors.page;
Color get _surface => AppColors.surface;
Color get _surfaceLight => AppColors.softSurface;
Color get _text => AppColors.ink;
Color get _muted => AppColors.muted;
Color get _mint => AppColors.accentForeground;
Color get _gold => AppColors.accentForeground;
const _reserveCardRadius = 20.0;

class ReserveDashboardPage extends StatefulWidget {
  const ReserveDashboardPage({super.key, this.initialSelection, this.onLogout});

  final String? initialSelection;
  final Future<void> Function(BuildContext context)? onLogout;

  @override
  State<ReserveDashboardPage> createState() => _ReserveDashboardPageState();
}

class _ReserveDashboardPageState extends State<ReserveDashboardPage> {
  String _selected = 'Fitness & Wellness';
  bool _isContinuing = false;

  @override
  void initState() {
    super.initState();
    const choices = {'Sports', 'Event', 'Fitness & Wellness'};
    if (choices.contains(widget.initialSelection)) {
      _selected = widget.initialSelection!;
    }
  }

  Future<void> _continue() async {
    if (_isContinuing) return;
    setState(() => _isContinuing = true);
    try {
      final session = await AppSessionService.instance.load();
      await session.setLastBookingType(_selected);
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: AppText('Could not save your booking type: $error'),
              backgroundColor: _surfaceLight,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
      if (mounted) setState(() => _isContinuing = false);
      return;
    }
    if (!mounted) return;
    setState(() => _isContinuing = false);
    final dashboard = bookingTypeDashboard(
      _selected,
      onLogout: widget.onLogout,
    );
    if (dashboard == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: AppText(
              '$_selected dashboard is not available yet.',
              localize: true,
            ),
            backgroundColor: _surfaceLight,
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => dashboard));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: RefreshIndicator(
        onRefresh: () async {},
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              titleSpacing: 16,
              title: const _ReserveHeader(),
              backgroundColor: _background,
              foregroundColor: _text,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
            ),
            SliverLayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = AppResponsive.contentMaxWidthFor(
                  constraints.crossAxisExtent,
                );
                final horizontalInset =
                    ((constraints.crossAxisExtent - contentWidth) / 2).clamp(
                      18.0,
                      double.infinity,
                    );
                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalInset,
                    16,
                    horizontalInset,
                    12,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      AppText(
                        'INSTANTLY BOOKABLE',
                        style: TextStyle(
                          color: _mint,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                        localize: true,
                      ),
                      const SizedBox(height: 5),
                      AppText(
                        'Choose Booking Type',
                        key: const ValueKey('reserve-heading'),
                        style: TextStyle(
                          color: _text,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.4,
                        ),
                        localize: true,
                      ),
                      const SizedBox(height: 17),
                      _ExperienceCard(
                        key: const ValueKey('reserve-option-sports'),
                        imagePath: 'assets/overview/sports.png',
                        badge: 'SPORTS COURTS',
                        title: 'Sports & Courts',
                        description:
                            'Padel  •  Tennis  •  Football  •  Pickleball',
                        actionLabel: 'Browse Courts',
                        tags: const [
                          'Tennis',
                          'Padel',
                          'Basketball',
                          'Volleyball',
                          'Badminton',
                          'Pickleball',
                        ],
                        icon: Icons.sports_tennis_rounded,
                        accent: _mint,
                        selected: _selected == 'Sports',
                        onTap: () => setState(() => _selected = 'Sports'),
                      ),
                      const SizedBox(height: 14),
                      _ExperienceCard(
                        key: const ValueKey('reserve-option-event'),
                        imagePath: 'assets/overview/events.png',
                        badge: 'EVENTS & EXPERIENCES',
                        title: 'Events & Experiences',
                        description:
                            'Concerts  •  DJ sets  •  Gatherings  •  Tourneys',
                        actionLabel: 'Browse Events',
                        tags: const [
                          'Concerts',
                          'DJ Sets',
                          'Gatherings',
                          'Tournaments',
                        ],
                        icon: Icons.celebration_rounded,
                        accent: _gold,
                        selected: _selected == 'Event',
                        onTap: () => setState(() => _selected = 'Event'),
                      ),
                      const SizedBox(height: 14),
                      _ExperienceCard(
                        key: const ValueKey('reserve-option-fitness'),
                        imagePath: 'assets/overview/fitness.png',
                        badge: 'FITNESS & WELLNESS',
                        title: 'Studios & Fitness',
                        description: 'Reformer  •  Sauna  •  Boxing  •  Yoga',
                        actionLabel: 'Browse Sessions',
                        tags: const ['CrossFit', 'Pilates', 'Zumba', 'Boxing'],
                        icon: Icons.fitness_center_rounded,
                        accent: _mint,
                        selected: _selected == 'Fitness & Wellness',
                        onTap: () =>
                            setState(() => _selected = 'Fitness & Wellness'),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          key: const ValueKey('reserve-footer'),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
          decoration: BoxDecoration(
            color: _surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _isContinuing ? null : _continue,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: AppText(
                          'Continue to $_selected',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          localize: true,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              AppText(
                'Browsing is open to everyone',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                localize: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget? bookingTypeDashboard(
  String? type, {
  Future<void> Function(BuildContext context)? onLogout,
}) {
  return switch (type) {
    'Sports' => NewsFeedPage(onLogout: onLogout),
    'Event' => EventDashboardPage(onLogout: onLogout),
    'Fitness & Wellness' => FitnessDashboardPage(onLogout: onLogout),
    _ => null,
  };
}

class _ReserveHeader extends StatelessWidget {
  const _ReserveHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SpotGoLogo(size: 34),
        const SizedBox(width: 8),
        AppText.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Spot',
                style: TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextSpan(
                text: 'GO',
                style: TextStyle(
                  color: AppColors.accentForeground,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          localize: true,
        ),
      ],
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({
    required this.imagePath,
    required this.badge,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.tags,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String imagePath;
  final String badge;
  final String title;
  final String description;
  final String actionLabel;
  final List<String> tags;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accentForeground = AppColors.accentForeground;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final imageHeight = textScale > 1.2 ? 176.0 : 148.0;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title booking option',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_reserveCardRadius),
        child: AnimatedContainer(
          key: ValueKey('reserve-option-surface-$title'),
          duration: const Duration(milliseconds: 180),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(_reserveCardRadius),
            border: Border.all(
              color: selected ? accentForeground : AppColors.border,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: imageHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(imagePath, fit: BoxFit.cover),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: .08),
                            Colors.black.withValues(alpha: .78),
                          ],
                          stops: const [0.05, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accentForeground,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 13, color: AppColors.onAccent),
                            const SizedBox(width: 6),
                            AppText(
                              badge,
                              style: TextStyle(
                                color: AppColors.onAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .4,
                              ),
                              localize: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (selected)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: accentForeground,
                          size: 23,
                        ),
                      ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 11,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: title.length > 13 ? 19 : 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.25,
                            ),
                          ),
                          const SizedBox(height: 3),
                          AppText(
                            tags.take(4).join('  •  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xE6FFFFFF),
                              fontSize: 11,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 43,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppPreferences.instance.darkMode
                      ? AppColors.darkSurfaceHighest
                      : AppColors.surfaceVariant,
                  border: Border(
                    top: BorderSide(
                      color: AppColors.border.withValues(alpha: .7),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.check_rounded : Icons.touch_app_rounded,
                      size: 15,
                      color: selected ? AppColors.success : accentForeground,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: AppText(
                        selected ? 'Selected' : description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? AppColors.success : _muted,
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                        localize: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: AppText(
                        actionLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accentForeground,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                        localize: true,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 17,
                      color: accentForeground,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
