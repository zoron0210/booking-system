import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:myapp/app_design_system.dart';
import 'package:myapp/app_preferences.dart';
import 'package:myapp/app_session.dart';
import 'package:myapp/app_startup.dart';
import 'package:myapp/features/session/application/session_service.dart';
import 'package:myapp/app_theme.dart';
import 'package:myapp/booking_push_notifications.dart';
import 'package:myapp/guest_access.dart';
import 'package:myapp/merchant_dashboard.dart';
import 'package:myapp/message_notification_host.dart';
import 'package:myapp/messages_dashboard.dart';
import 'package:myapp/reserve_dashboard.dart';
import 'package:myapp/scroll_to_top_overlay.dart';

part 'overview_page.dart';
part 'auth_page.dart';
part 'discovery_pages.dart';

const _navy = AppColors.navy;
Color get _ink => AppColors.ink;
Color get _orange => AppColors.accent;
Color get _page => AppColors.page;
Color get _muted => AppColors.muted;
final _rootNavigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.session, this.dependencies});

  final AppSession? session;
  final AppDependencies? dependencies;

  AppDependencies get _dependencies =>
      dependencies ?? AppDependencies(preferences: AppPreferences.instance);

  AppPreferences get _preferences => _dependencies.preferences;

  static final _scrollToTopController = ScrollToTopOverlayController();
  static final ScrollToTopNavigatorObserver _scrollObserver =
      ScrollToTopNavigatorObserver(
        onNavigationChanged: _scrollToTopController.reset,
      );

  Widget get _initialHome {
    final currentSession = session;
    final isAuthenticatedMerchant =
        currentSession?.role == 'merchant' &&
        currentSession?.isAuthenticated == true &&
        currentSession?.apiToken?.isNotEmpty == true;
    if (!isAuthenticatedMerchant) {
      final lastBookingPage = bookingTypeDashboard(
        currentSession?.lastBookingType,
        onLogout: logoutToBookingPicker,
      );
      if (lastBookingPage != null) return lastBookingPage;
    }
    return const OverviewPage();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _preferences,
    builder: (context, _) {
      return MaterialApp(
        navigatorKey: _rootNavigatorKey,
        navigatorObservers: [_scrollObserver],
        title: 'SpotGo',
        debugShowCheckedModeBanner: false,
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
            child: ScrollToTopOverlay(
              controller: _scrollToTopController,
              child: MessageNotificationHost(
                child: child ?? const SizedBox.shrink(),
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
            ),
          );
        },
      );
    },
  );
}

Future<void> logoutToBookingPicker(BuildContext context) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  await AppPreferences.instance.load();
  final session = await AppSessionService.instance.load();
  await BookingPushNotifications.instance.unregister(session);
  await session.clearLastBookingType();
  await session.clear();
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => ReserveDashboardPage(onLogout: logoutToBookingPicker),
    ),
    (_) => false,
  );
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: AppText(
          'You’ve been signed out. You’re now browsing as a guest.',
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
