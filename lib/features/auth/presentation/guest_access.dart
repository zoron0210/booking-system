import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:myapp/core/app_text.dart';
import 'package:myapp/features/auth/application/auth_service.dart';
import 'package:myapp/features/auth/presentation/auth_dashboard.dart';
import 'package:myapp/features/notifications/data/booking_push_notifications.dart';
import 'package:myapp/features/session/application/session_service.dart';
import 'package:myapp/features/merchant_management/presentation/merchant_dashboard.dart';
import 'package:myapp/features/app_shell/presentation/news_feed.dart';
import 'package:myapp/features/app_shell/presentation/reserve_dashboard.dart';

Future<bool> requireCustomerLogin(BuildContext context) async {
  final session = await AppSessionService.instance.load();
  if (!context.mounted) return false;
  if (session.apiToken?.isNotEmpty == true) {
    if (session.role?.toLowerCase() == 'merchant') {
      _openMerchantDashboard(context);
      return false;
    }
    return true;
  }

  final shouldLogin = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.lock_outline_rounded),
      title: const AppText('Log in to continue', localize: true),
      content: const AppText(
        'You can browse as a guest. Log in first to reserve, chat with a merchant, follow people, or share experiences.',
        localize: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const AppText('Cancel', localize: true),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const AppText('Continue to log in', localize: true),
        ),
      ],
    ),
  );
  if (shouldLogin != true || !context.mounted) return false;

  return openCustomerLogin(context);
}

Future<bool> openCustomerLogin(
  BuildContext context, {
  AuthService? authService,
}) async {
  if (!context.mounted) return false;
  final authenticated = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => AuthDashboardPage(
        authService: authService,
        onCustomerOnboardingCompleted: () {
          Navigator.of(context).pushAndRemoveUntil<void>(
            MaterialPageRoute<void>(
              builder: (_) => CustomerHomePage(
                onLogout: _logoutCustomerSession,
                api: authService?.api,
              ),
            ),
            (_) => false,
          );
        },
      ),
    ),
  );
  if (!context.mounted || authenticated != true) return false;

  final session = await AppSessionService.instance.load();
  if (!context.mounted) return false;
  if (session.role?.toLowerCase() == 'merchant') {
    _openMerchantDashboard(context);
    return false;
  }
  return true;
}

void _openMerchantDashboard(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil<void>(
    MaterialPageRoute<void>(
      builder: (_) => MerchantDashboardPage(onLogout: _logoutMerchantSession),
    ),
    (route) => route.isFirst,
  );
}

Future<void> _logoutCustomerSession(BuildContext context) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final session = await AppSessionService.instance.load();
  await BookingPushNotifications.instance.unregister(session);
  await session.clearLastBookingType();
  final sessionRevoked = await revokeAndClearCurrentSession();
  await Future.wait<void>([
    FirebaseAuth.instance.signOut(),
    GoogleSignIn.instance.signOut(),
  ]);
  navigator.pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (_) => ReserveDashboardPage(onLogout: _logoutCustomerSession),
    ),
    (_) => false,
  );
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: AppText(
          sessionRevoked
              ? 'You’ve been signed out. You’re now browsing as a guest.'
              : 'You’re signed out on this device, but the server session could not be revoked. Connect to the internet and sign in again.',
          localize: true,
        ),
      ),
    );
}

Future<void> _logoutMerchantSession(BuildContext context) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  await BookingPushNotifications.instance.unregister(
    await AppSessionService.instance.load(),
  );
  final sessionRevoked = await revokeAndClearCurrentSession();
  await Future.wait<void>([
    FirebaseAuth.instance.signOut(),
    GoogleSignIn.instance.signOut(),
  ]);
  if (context.mounted) {
    navigator.popUntil((route) => route.isFirst);
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: AppText(
          sessionRevoked
              ? 'You’ve been signed out. You’re now browsing as a guest.'
              : 'You’re signed out on this device, but the server session could not be revoked. Connect to the internet and sign in again.',
          localize: true,
        ),
      ),
    );
}
