import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_design_system.dart';
import 'app_preferences.dart';
import 'app_session.dart';
import 'app_theme.dart';
import 'booking_push_notifications.dart';
import 'features/session/application/session_service.dart';
import 'firebase_options.dart';

class AppDependencies {
  AppDependencies({AppPreferences? preferences})
    : preferences = preferences ?? AppPreferences.instance;

  final AppPreferences preferences;
}

class AppStartup extends StatefulWidget {
  const AppStartup({
    super.key,
    required this.appBuilder,
    this.initialize,
    this.dependencies,
  });

  final Widget Function(AppSession?) appBuilder;
  final Future<AppSession> Function()? initialize;
  final AppDependencies? dependencies;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  late Future<AppSession> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<AppSession> _initialize() async {
    late final AppSession session;
    var firebaseInitialized = false;
    if (widget.initialize != null) {
      session = await widget.initialize!();
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      firebaseInitialized = true;
      session = await AppSessionService.instance.load();
    }
    await _preferences.load(
      accountEmail: session.isAuthenticated ? session.accountEmail : null,
    );
    if (firebaseInitialized && session.isAuthenticated) {
      unawaited(BookingPushNotifications.instance.initialize(session));
    }
    return session;
  }

  void _retry() {
    setState(() {
      _initialization = _initialize();
    });
  }

  AppDependencies get _dependencies => widget.dependencies ?? AppDependencies();

  AppPreferences get _preferences => _dependencies.preferences;

  ThemeData _theme() => AppTheme.configured(
    darkMode: _preferences.darkMode,
    accentColor: _preferences.accentColor,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<AppSession>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return MaterialApp(
          title: 'SpotGo',
          debugShowCheckedModeBanner: false,
          theme: _theme(),
          home: const _StartupLoadingScreen(),
        );
      }
      if (snapshot.hasError) {
        return MaterialApp(
          title: 'SpotGo',
          debugShowCheckedModeBanner: false,
          theme: _theme(),
          home: _StartupError(error: snapshot.error!, onRetry: _retry),
        );
      }
      if (snapshot.hasData) return widget.appBuilder(snapshot.data);
      return MaterialApp(
        title: 'SpotGo',
        debugShowCheckedModeBanner: false,
        theme: _theme(),
        home: const _StartupLoadingScreen(),
      );
    },
  );
}

class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.page,
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 132,
                height: 132,
                padding: const EdgeInsets.all(AppSpacing.large),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const SpotGoLogo(size: 96),
              ),
              const SizedBox(height: 6),
              AppText(
                'SpotGo',
                style: const TextStyle(
                  color: AppColors.blue,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.8,
                ),
                localize: true,
              ),
              const SizedBox(height: 6),
              AppText(
                'Sports, events, and local experiences',
                textAlign: TextAlign.center,
                style: AppTypography.supporting,
                localize: true,
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 6),
              AppText(
                'Getting your courts ready...',
                style: AppTypography.supporting,
                localize: true,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.page,
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.accent,
                size: 44,
              ),
              const SizedBox(height: 6),
              AppText(
                'SpotGo could not start',
                textAlign: TextAlign.center,
                style: AppTypography.pageTitle,
                localize: true,
              ),
              const SizedBox(height: 6),
              AppText(
                '$error',
                textAlign: TextAlign.center,
                style: AppTypography.supporting,
                localize: true,
              ),
              const SizedBox(height: 6),
              FilledButton(
                onPressed: onRetry,
                child: const AppText('Try again', localize: true),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
