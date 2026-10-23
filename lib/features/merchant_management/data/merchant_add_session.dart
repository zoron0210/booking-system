import 'package:myapp/app_session.dart';

abstract interface class MerchantAddSession {
  Future<String?> loadApiToken();

  Future<bool> bookingDeadlineReminderDismissed();

  Future<void> dismissBookingDeadlineReminder();
}

class AppMerchantAddSession implements MerchantAddSession {
  AppMerchantAddSession({Future<AppSession> Function()? loadSession})
    : _loadSession = loadSession ?? AppSession.load;

  final Future<AppSession> Function() _loadSession;

  @override
  Future<String?> loadApiToken() async => (await _loadSession()).apiToken;

  @override
  Future<bool> bookingDeadlineReminderDismissed() async =>
      (await _loadSession()).bookingDeadlineReminderDismissed();

  @override
  Future<void> dismissBookingDeadlineReminder() async =>
      (await _loadSession()).dismissBookingDeadlineReminder();
}
