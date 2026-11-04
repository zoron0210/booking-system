// The booking-type picker remains in this file for the customer reservation flow.
// ignore_for_file: unused_element

import 'package:flutter/material.dart';

import 'package:myapp/core/app_design_system.dart';
import 'package:myapp/core/app_preferences.dart';
import 'package:myapp/features/app_shell/presentation/event_dashboard.dart';
import 'package:myapp/features/session/application/session_service.dart';
import 'package:myapp/features/app_shell/presentation/fitness_dashboard.dart';
import 'package:myapp/features/app_shell/presentation/news_feed.dart';

Color get _background => AppColors.page;
Color get _surface => AppColors.surface;
Color get _surfaceLight => AppColors.softSurface;
Color get _text => AppColors.ink;
Color get _muted => AppColors.muted;
Color get _mint => AppColors.accentForeground;
Color get _gold => AppColors.accentForeground;
const _reserveCardRadius = 18.0;

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
      backgroundColor: _surface,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              titleSpacing: 18,
              toolbarHeight: 54,
              title: const _ReserveHeader(),
              backgroundColor: _surface,
              foregroundColor: _text,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
            ),
            SliverLayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = AppResponsive.contentMaxWidthFor(
                  constraints.crossAxisExtent,
                ).clamp(0.0, 760.0);
                final horizontalInset =
                    ((constraints.crossAxisExtent - contentWidth) / 2).clamp(
                      20.0,
                      double.infinity,
                    );
                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalInset,
                    18,
                    horizontalInset,
                    20,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      AppText(
                        'Choose Booking Type',
                        key: const ValueKey('reserve-heading'),
                        style: TextStyle(
                          color: _text,
                          fontSize: 34,
                          height: 1.08,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.9,
                        ),
                        localize: true,
                      ),
                      const SizedBox(height: 19),
                      _ExperienceCard(
                        key: const ValueKey('reserve-option-sports'),
                        imagePath: 'assets/overview/sports.png',
                        title: 'Sports & Courts',
                        description: 'Padel, Tennis, Football, Pickleball',
                        selected: _selected == 'Sports',
                        onTap: () => setState(() => _selected = 'Sports'),
                      ),
                      const SizedBox(height: 14),
                      _ExperienceCard(
                        key: const ValueKey('reserve-option-event'),
                        imagePath: 'assets/overview/events.png',
                        title: 'Events & Experiences',
                        description: 'Concerts, gatherings, and special events',
                        selected: _selected == 'Event',
                        onTap: () => setState(() => _selected = 'Event'),
                      ),
                      const SizedBox(height: 14),
                      _ExperienceCard(
                        key: const ValueKey('reserve-option-fitness'),
                        imagePath: 'assets/overview/fitness.png',
                        title: 'Studios & Fitness',
                        description:
                            'Pilates, gym sessions, wellness, and more',
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
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
                    shape: const StadiumBorder(),
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
              const SizedBox(height: 8),
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
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String imagePath;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accentForeground = AppColors.accentForeground;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title booking option',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_reserveCardRadius),
        child: AnimatedContainer(
          key: ValueKey('reserve-option-surface-$title'),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 154,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppPreferences.instance.darkMode
                ? AppColors.darkSurface
                : AppColors.surface,
            borderRadius: BorderRadius.circular(_reserveCardRadius),
            border: Border.all(
              color: selected ? accentForeground : AppColors.border,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(imagePath, fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x08000000),
                      Color(0x1A000000),
                      Color(0xE6000000),
                    ],
                    stops: [0, .35, 1],
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accentForeground,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: AppColors.onAccent,
                      size: 20,
                    ),
                  ),
                ),
              Positioned(
                left: 18,
                right: selected ? 56 : 18,
                bottom: 17,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppText(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: title.length > 19 ? 20 : 22,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    AppText(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xF2FFFFFF),
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
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
