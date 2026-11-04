import 'dart:async';

import 'package:myapp/core/live_updates_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineLiveUpdatesClient extends LiveUpdatesClient {
  @override
  Future<void> connect(String token) async {
    throw StateError('WebSocket unavailable in this test.');
  }
}

class ConnectedLiveUpdatesClient extends LiveUpdatesClient {
  final _events = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;

  @override
  Future<void> connect(String token) async {}

  void emit(Map<String, dynamic> event) => _events.add(event);

  @override
  Future<void> close() => _events.close();
}

void setMerchantDashboardSession({
  String role = 'merchant',
  String apiToken = 'merchant-token',
}) {
  SharedPreferences.setMockInitialValues({
    'session_api_token': apiToken,
    'session_role': role,
  });
  FlutterSecureStorage.setMockInitialValues({'session_api_token': apiToken});
}
