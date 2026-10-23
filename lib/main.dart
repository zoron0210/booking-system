import 'package:flutter/material.dart';
import 'package:myapp/features/app_shell/presentation/app_root.dart';

import 'app_preferences.dart';
import 'app_startup.dart';

export 'app_root.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = AppDependencies(preferences: AppPreferences.instance);
  runApp(
    AppStartup(
      dependencies: dependencies,
      appBuilder: (session) =>
          MyApp(session: session, dependencies: dependencies),
    ),
  );
}
