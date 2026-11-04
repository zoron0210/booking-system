import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:myapp/features/app_shell/presentation/news_feed.dart';
import 'package:myapp/features/auth/data/auth_api.dart';

class EventDashboardPage extends StatelessWidget {
  const EventDashboardPage({
    super.key,
    this.onLogout,
    this.api,
    this.initialUserPosition,
    this.hideBottomNavigation = false,
  });

  final Future<void> Function(BuildContext context)? onLogout;
  final AuthApi? api;
  final Position? initialUserPosition;
  final bool hideBottomNavigation;

  @override
  Widget build(BuildContext context) => NewsFeedPage(
    api: api,
    onLogout: onLogout,
    initialUserPosition: initialUserPosition,
    hideBottomNavigation: hideBottomNavigation,
    businessType: 'Event',
    pageTitle: 'Event Venues',
    savedItemType: 'event',
    categoryNoun: 'event types',
    venueNoun: 'event venues',
    searchHint: 'Search venues, event types, or areas...',
    highestRatedSectionTitle: 'Highest rated',
    allVenuesHeading: 'All listed event venues',
    categoryFilterLabel: 'Event type',
    facilityFilterLabel: 'Venue type',
  );
}
