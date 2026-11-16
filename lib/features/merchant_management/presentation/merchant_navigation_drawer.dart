import 'package:flutter/material.dart';

import 'package:myapp/core/app_design_system.dart';
import 'package:myapp/core/app_text.dart';

class MerchantNavigationDrawer extends StatelessWidget {
  const MerchantNavigationDrawer({
    super.key,
    required this.owner,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onSettingsSelected,
    this.onLogout,
    this.onHelpCenterSelected,
    this.onTermsOfServiceSelected,
    this.profileImage,
    this.pendingBookingCount = 0,
  });

  final Map<String, dynamic> owner;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onSettingsSelected;
  final Future<void> Function(BuildContext context)? onLogout;
  final VoidCallback? onHelpCenterSelected;
  final VoidCallback? onTermsOfServiceSelected;
  final ImageProvider<Object>? profileImage;
  final int pendingBookingCount;

  @override
  Widget build(BuildContext context) {
    final name = '${owner['firstName'] ?? ''} ${owner['lastName'] ?? ''}'
        .trim();
    final business = '${owner['businessName'] ?? owner['email'] ?? ''}';
    return Drawer(
      key: const ValueKey('merchant-navigation-drawer'),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              margin: EdgeInsets.zero,
              decoration: BoxDecoration(color: AppColors.navy),
              currentAccountPicture: CircleAvatar(
                backgroundColor: AppColors.surface,
                backgroundImage: profileImage,
                child: profileImage == null
                    ? Icon(
                        Icons.storefront_rounded,
                        color: AppColors.accentForeground,
                      )
                    : null,
              ),
              accountName: Text(name.isEmpty ? 'Merchant account' : name),
              accountEmail: Text(
                business,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onHelpCenterSelected != null &&
                onTermsOfServiceSelected != null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: AppText(
                  'SUPPORT',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                  localize: true,
                ),
              ),
              ListTile(
                key: const ValueKey('merchant-drawer-help-center'),
                leading: const Icon(Icons.help_outline_rounded),
                title: const AppText('Help Center', localize: true),
                onTap: () {
                  Navigator.of(context).pop();
                  onHelpCenterSelected!();
                },
              ),
              ListTile(
                key: const ValueKey('merchant-drawer-terms-of-service'),
                leading: const Icon(Icons.description_outlined),
                title: const AppText('Terms of Service', localize: true),
                onTap: () {
                  Navigator.of(context).pop();
                  onTermsOfServiceSelected!();
                },
              ),
            ],
            _destination(
              context,
              index: 0,
              label: 'Dashboard',
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard_rounded,
            ),
            _destination(
              context,
              index: 1,
              label: 'Businesses',
              icon: Icons.storefront_outlined,
              selectedIcon: Icons.storefront_rounded,
            ),
            _destination(
              context,
              index: 2,
              label: 'Messages',
              icon: Icons.forum_outlined,
              selectedIcon: Icons.forum_rounded,
            ),
            _destination(
              context,
              index: 3,
              label: 'Bookings & payments',
              icon: Icons.pending_actions_outlined,
              selectedIcon: Icons.pending_actions_rounded,
              trailing: pendingBookingCount,
            ),
            _destination(
              context,
              index: 4,
              label: 'Profile',
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
            ),
            ListTile(
              key: const ValueKey('merchant-profile-settings'),
              leading: const Icon(Icons.settings_outlined),
              title: const AppText('Settings', localize: true),
              onTap: () {
                Navigator.of(context).pop();
                onSettingsSelected();
              },
            ),
            if (onLogout case final logout?)
              ListTile(
                key: const ValueKey('merchant-drawer-logout'),
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title: const AppText(
                  'Log out',
                  style: TextStyle(color: Colors.red),
                  localize: true,
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await logout(context);
                },
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: AppText(
                'Merchant workspace',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
                localize: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _destination(
    BuildContext context, {
    required int index,
    required String label,
    required IconData icon,
    required IconData selectedIcon,
    int trailing = 0,
  }) => ListTile(
    key: ValueKey(switch (index) {
      0 => 'merchant-dashboard-nav-dashboard',
      1 => 'merchant-dashboard-nav-add',
      2 => 'merchant-dashboard-nav-messages',
      3 => 'merchant-dashboard-nav-payouts',
      _ => 'merchant-dashboard-nav-profile',
    }),
    selected: selectedIndex == index,
    leading: Icon(selectedIndex == index ? selectedIcon : icon),
    title: AppText(label, localize: true),
    trailing: trailing > 0
        ? CircleAvatar(
            radius: 11,
            backgroundColor: AppColors.accent,
            child: Text(
              '$trailing',
              style: TextStyle(
                color: AppColors.onAccent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        : null,
    onTap: () {
      Navigator.of(context).pop();
      onDestinationSelected(index);
    },
  );
}
