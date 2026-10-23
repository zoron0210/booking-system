import 'package:myapp/app_session.dart';

abstract interface class CustomerBookingsSession {
  String? get apiToken;

  bool bookingStatusBannerDismissed(String bookingKey);

  Future<void> dismissBookingStatusBanner(String bookingKey);
}

abstract interface class CustomerBookingsSessionProvider {
  Future<CustomerBookingsSession> load();
}

class AppCustomerBookingsSessionProvider
    implements CustomerBookingsSessionProvider {
  AppCustomerBookingsSessionProvider({
    Future<AppSession> Function()? loadSession,
  }) : _loadSession = loadSession ?? AppSession.load;

  final Future<AppSession> Function() _loadSession;

  @override
  Future<CustomerBookingsSession> load() async =>
      _AppCustomerBookingsSession(await _loadSession());
}

class _AppCustomerBookingsSession implements CustomerBookingsSession {
  const _AppCustomerBookingsSession(this._session);

  final AppSession _session;

  @override
  String? get apiToken => _session.apiToken;

  @override
  bool bookingStatusBannerDismissed(String bookingKey) =>
      _session.bookingStatusBannerDismissed(bookingKey);

  @override
  Future<void> dismissBookingStatusBanner(String bookingKey) =>
      _session.dismissBookingStatusBanner(bookingKey);
}
