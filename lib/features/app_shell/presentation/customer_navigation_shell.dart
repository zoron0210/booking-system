import 'package:flutter/material.dart';
import 'package:myapp/features/app_shell/presentation/app_bottom_navigation.dart';
import 'package:myapp/features/app_shell/presentation/customer_navigation_scope.dart';
import 'package:myapp/features/app_shell/presentation/event_dashboard.dart';
import 'package:myapp/features/app_shell/presentation/fitness_dashboard.dart';
import 'package:myapp/features/app_shell/presentation/news_feed.dart';
import 'package:myapp/features/auth/data/auth_api.dart';
import 'package:myapp/features/bookings/presentation/customer_bookings_page.dart';
import 'package:myapp/features/messaging/presentation/messages_dashboard.dart';
import 'package:myapp/features/profile/presentation/profile_dashboard.dart';

class CustomerNavigationShell extends StatefulWidget {
  const CustomerNavigationShell({
    super.key,
    this.api,
    this.onLogout,
    this.businessType,
  });

  final AuthApi? api;
  final Future<void> Function(BuildContext context)? onLogout;
  final String? businessType;

  @override
  State<CustomerNavigationShell> createState() =>
      _CustomerNavigationShellState();
}

class _CustomerNavigationShellState extends State<CustomerNavigationShell> {
  static const _destinations = [5, 0, 2, 3, 4];

  late int _selectedIndex;
  late final Set<int> _visited = {_selectedIndex};
  int _unreadBookingCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.businessType?.trim().isNotEmpty == true ? 0 : 5;
  }

  void _selectDestination(int index) {
    if (!_destinations.contains(index)) return;
    setState(() {
      _selectedIndex = index;
      _visited.add(index);
    });
  }

  void _setUnreadBookingCount(int count) {
    if (_unreadBookingCount == count) return;
    setState(() => _unreadBookingCount = count);
  }

  Widget _pageFor(int destination) {
    final key = ValueKey('customer-navigation-tab-$destination');
    return switch (destination) {
      5 => CustomerHomePage(
        key: key,
        api: widget.api,
        onLogout: widget.onLogout,
        businessType: widget.businessType,
        hideBottomNavigation: true,
      ),
      0 => switch (widget.businessType?.toLowerCase()) {
        'event' => EventDashboardPage(
          key: key,
          api: widget.api,
          onLogout: widget.onLogout,
          hideBottomNavigation: true,
        ),
        'fitness' => FitnessDashboardPage(
          key: key,
          api: widget.api,
          onLogout: widget.onLogout,
          hideBottomNavigation: true,
        ),
        _ => NewsFeedPage(
          key: key,
          api: widget.api,
          onLogout: widget.onLogout,
          businessType: widget.businessType ?? 'Sports',
          hideBottomNavigation: true,
        ),
      },
      2 => MessagesDashboardPage(
        key: key,
        api: widget.api,
        businessType: widget.businessType,
        hideBottomNavigation: true,
      ),
      3 => CustomerBookingsPage(
        key: key,
        api: widget.api,
        businessType: widget.businessType,
        onLogout: widget.onLogout,
        hideBottomNavigation: true,
      ),
      4 => ProfileDashboardPage(
        key: key,
        api: widget.api,
        businessType: widget.businessType,
        onLogout: widget.onLogout,
        hideBottomNavigation: true,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) => CustomerNavigationScope(
    onDestinationSelected: _selectDestination,
    onUnreadBookingCountChanged: _setUnreadBookingCount,
    child: Scaffold(
      body: IndexedStack(
        index: _destinations.indexOf(_selectedIndex),
        children: [
          for (final destination in _destinations)
            _visited.contains(destination)
                ? _pageFor(destination)
                : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: _selectedIndex,
        unreadBookingCount: _unreadBookingCount,
        hideSavedDestination: true,
        showHomeDestination: true,
        onDestinationSelected: _selectDestination,
      ),
    ),
  );
}
