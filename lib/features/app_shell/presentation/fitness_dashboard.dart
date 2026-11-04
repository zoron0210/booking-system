import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:myapp/features/app_shell/presentation/news_feed.dart';
import 'package:myapp/features/auth/data/auth_api.dart';

class FitnessDashboardPage extends StatelessWidget {
  const FitnessDashboardPage({
    super.key,
    this.onLogout,
    this.api,
    this.initialUserPosition,
    this.savedOnly = false,
    this.hideBottomNavigation = false,
  });

  final Future<void> Function(BuildContext context)? onLogout;
  final AuthApi? api;
  final Position? initialUserPosition;
  final bool savedOnly;
  final bool hideBottomNavigation;

  @override
  Widget build(BuildContext context) => NewsFeedPage(
    onLogout: onLogout,
    api: api,
    initialUserPosition: initialUserPosition,
    savedOnly: savedOnly,
    hideBottomNavigation: hideBottomNavigation,
    businessType: 'Fitness',
    pageTitle: 'Fitness & Wellness',
    savedItemType: 'fitness',
    categoryNoun: 'fitness types',
    venueNoun: 'venues',
    searchHint: 'Search venues, fitness types, or areas...',
    highestRatedSectionTitle: 'Highest rated',
    allVenuesHeading: 'All venues',
    categoryFilterLabel: 'Fitness type',
    facilityFilterLabel: 'Facility type',
  );
}
