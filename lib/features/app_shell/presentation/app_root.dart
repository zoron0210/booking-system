import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:myapp/core/app_design_system.dart';
import 'package:myapp/core/app_preferences.dart';
import 'package:myapp/core/app_session.dart';
import 'package:myapp/core/user_facing_error.dart';
import 'package:myapp/features/app_shell/application/app_startup.dart';
import 'package:myapp/features/app_shell/presentation/customer_navigation_shell.dart';
import 'package:myapp/features/session/application/session_service.dart';
import 'package:myapp/core/app_theme.dart';
import 'package:myapp/features/auth/data/auth_api.dart';
import 'package:myapp/features/auth/application/auth_service.dart';
import 'package:myapp/features/notifications/data/booking_push_notifications.dart';
import 'package:myapp/features/bookings/presentation/customer_bookings_page.dart';
import 'package:myapp/features/bookings/presentation/matchmaking_lobby_list_page.dart';
import 'package:myapp/features/merchant_management/presentation/merchant_dashboard.dart';
import 'package:myapp/features/messaging/presentation/message_notification_host.dart';
import 'package:myapp/features/messaging/presentation/messages_dashboard.dart';
import 'package:myapp/features/app_shell/presentation/reserve_dashboard.dart';
import 'package:myapp/core/premium_motion.dart';

import 'first_launch_onboarding.dart';

part 'auth_page.dart';
part 'discovery_pages.dart';

const _navy = AppColors.navy;
Color get _ink => AppColors.ink;
Color get _orange => AppColors.accent;
Color get _page => AppColors.page;
Color get _muted => AppColors.muted;
final _rootNavigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.session,
    this.dependencies,
    this.homeApi,
    this.initialPage,
  });

  final AppSession? session;
  final AppDependencies? dependencies;
  final AuthApi? homeApi;
  final Widget? initialPage;

  AppDependencies get _dependencies =>
      dependencies ?? AppDependencies(preferences: AppPreferences.instance);

  AppPreferences get _preferences => _dependencies.preferences;

  Future<void> _switchMerchantPortal(BuildContext context, String mode) async {
    try {
      final session = await AppSessionService.instance.load();
      final token = session.apiToken;
      if (token == null || token.isEmpty) {
        throw const FormatException('Sign in again to switch portals.');
      }
      final response = await (homeApi ?? AuthApi()).switchMerchantPortalMode(
        token: token,
        mode: mode,
      );
      final nextToken = response['token'];
      if (nextToken is! String ||
          nextToken.isEmpty ||
          response['mode'] != mode) {
        throw const FormatException(
          'The server returned an invalid portal session.',
        );
      }
      await session.setApiToken(nextToken);
      await session.setRole(mode);
      if (!context.mounted) return;

      final navigator = _rootNavigatorKey.currentState;
      if (navigator == null) {
        throw const FormatException('Could not open the selected portal.');
      }
      navigator.pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(
          builder: (_) => mode == 'customer'
              ? CustomerNavigationShell(
                  api: homeApi,
                  onLogout: logoutToBookingPicker,
                  businessType: session.lastBookingType,
                  onSwitchToMerchantPortal: (context) =>
                      _switchMerchantPortal(context, 'merchant'),
                )
              : MerchantDashboardPage(
                  onLogout: logoutToBookingPicker,
                  onSwitchToCustomerPortal: (context) =>
                      _switchMerchantPortal(context, 'customer'),
                ),
        ),
        (_) => false,
      );
    } on Exception catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFacingErrorMessage(error)),
          ),
        );
      }
    }
  }

  Widget get _initialHome {
    if (initialPage != null) return initialPage!;
    final currentSession = session ?? AppSessionService.instance.currentSession;
    final isAuthenticatedMerchant =
        currentSession?.role == 'merchant' &&
        currentSession?.isAuthenticated == true &&
        currentSession?.apiToken?.isNotEmpty == true;
    final Widget destination;
    if (!isAuthenticatedMerchant) {
      destination = CustomerNavigationShell(
        api: homeApi,
        onLogout: logoutToBookingPicker,
        businessType: currentSession?.lastBookingType,
        onSwitchToMerchantPortal: (context) =>
            _switchMerchantPortal(context, 'merchant'),
      );
    } else {
      destination = MerchantDashboardPage(
        onLogout: logoutToBookingPicker,
        onSwitchToCustomerPortal: (context) =>
            _switchMerchantPortal(context, 'customer'),
      );
    }
    return FirstLaunchOnboardingGate(
      session: currentSession,
      child: destination,
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: session ?? AppSessionService.instance,
    builder: (context, _) => AnimatedBuilder(
      animation: _preferences,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _rootNavigatorKey,
          title: 'SpotGo',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const PremiumScrollBehavior(),
          theme: AppTheme.configured(
            darkMode: _preferences.darkMode,
            accentColor: _preferences.accentColor,
          ),
          locale: AppLanguage.fromCode(_preferences.languageCode).locale,
          supportedLocales: AppLanguage.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: _initialHome,
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: _PreferenceTextScaler(
                  media.textScaler,
                  _preferences.textScale,
                ),
              ),
              child: MessageNotificationHost(
                child: child ?? const SizedBox.shrink(),
                onOpenBookingNotification: (destination) {
                  final navigator = _rootNavigatorKey.currentState;
                  if (navigator == null) return;
                  if (destination.bookingId case final bookingId?) {
                    navigator.push(
                      MaterialPageRoute<void>(
                        builder: (_) => CustomerBookingsPage(
                          api: homeApi,
                          initialBookingId: bookingId,
                        ),
                      ),
                    );
                  } else if (destination.matchmakingLobbyId
                      case final lobbyId?) {
                    navigator.push(
                      MaterialPageRoute<void>(
                        builder: (_) => MatchmakingLobbyListPage(
                          api: homeApi ?? AuthApi(),
                          initialLobbyId: lobbyId,
                        ),
                      ),
                    );
                  }
                },
                onOpenConversation: (conversationId) {
                  _rootNavigatorKey.currentState?.push(
                    MaterialPageRoute<void>(
                      builder: (_) => MessagesDashboardPage(
                        initialConversationId: conversationId,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    ),
  );
}

Future<void> logoutToBookingPicker(BuildContext context) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  await AppPreferences.instance.load();
  final session = await AppSessionService.instance.load();
  await BookingPushNotifications.instance.unregister(session);
  await session.clearLastBookingType();
  final sessionRevoked = await revokeAndClearCurrentSession();
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => ReserveDashboardPage(onLogout: logoutToBookingPicker),
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
  unawaited(
    Future.wait<void>([
      Future<void>(() => FirebaseAuth.instance.signOut()),
      Future<void>(() => GoogleSignIn.instance.signOut()),
    ]).then<void>((_) {}, onError: (_, _) {}),
  );
}

class _PreferenceTextScaler extends TextScaler {
  const _PreferenceTextScaler(this.platformScaler, this.preferenceScale);

  final TextScaler platformScaler;
  final double preferenceScale;

  @override
  double scale(double fontSize) =>
      platformScaler.scale(fontSize * preferenceScale);

  @override
  double get textScaleFactor => platformScaler.scale(1) * preferenceScale;

  @override
  TextScaler clamp({
    double minScaleFactor = 0,
    double maxScaleFactor = double.infinity,
  }) => _PreferenceTextScaler(
    platformScaler.clamp(
      minScaleFactor: minScaleFactor / preferenceScale,
      maxScaleFactor: maxScaleFactor / preferenceScale,
    ),
    preferenceScale,
  );

  @override
  bool operator ==(Object other) =>
      other is _PreferenceTextScaler &&
      other.platformScaler == platformScaler &&
      other.preferenceScale == preferenceScale;

  @override
  int get hashCode => Object.hash(platformScaler, preferenceScale);
}

class PrototypePaymentDialog extends StatelessWidget {
  const PrototypePaymentDialog({super.key, required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            'Payment',
            style: TextStyle(
              color: _ink,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
            localize: true,
          ),
          const SizedBox(height: 6),
          AppText(
            'Pay $amount',
            style: TextStyle(
              color: _orange,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
            localize: true,
          ),
          const SizedBox(height: 6),
          ElevatedButton(
            onPressed: () => debugPrint('Payment successful'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: const AppText('Pay now'),
          ),
        ],
      ),
    );
  }
}
