import 'package:http/http.dart' as http;

import 'package:myapp/core/api_http_client.dart';
import 'package:myapp/core/api_response.dart';
import 'package:myapp/core/api_transport.dart';
import 'package:myapp/features/session/application/session_service.dart';
import 'package:myapp/features/bookings/data/booking_api.dart';
import 'package:myapp/features/messaging/data/messaging_api.dart';
import 'package:myapp/features/saved_items/data/saved_items_api.dart';
import 'package:myapp/features/social/data/social_api.dart';
import 'package:myapp/features/venues/data/venue_api.dart';

export 'package:myapp/core/api_http_client.dart'
    show AuthApiException, apiBaseUrl;
export 'package:myapp/features/activity_log/domain/activity_log_entry.dart';
export 'package:myapp/features/bookings/data/booking_api.dart'
    show BookingApi, newBookingIdempotencyKey;
export 'package:myapp/features/messaging/data/messaging_api.dart'
    show MessagingApi;
export 'package:myapp/features/saved_items/data/saved_items_api.dart'
    show SavedItemsApi;
export 'package:myapp/features/social/data/social_api.dart'
    show
        SocialApi,
        SocialFeedPage,
        socialPostingEnabled,
        socialProfileUiEnabled;
export 'package:myapp/features/venues/data/venue_api.dart';
export 'package:myapp/features/venues/domain/venue_models.dart';

class AuthApi implements ApiTransport {
  AuthApi({http.Client? client}) : httpClient = ApiHttpClient(client: client);

  static Future<void>? _refreshInProgress;

  @override
  final ApiHttpClient httpClient;

  late final BookingApi bookings = BookingApi(this);
  late final VenueApi venues = VenueApi(this);
  late final MessagingApi messaging = MessagingApi(this);
  late final SavedItemsApi savedItems = SavedItemsApi(this);
  late final SocialApi social = SocialApi(this);

  @override
  Map<String, String> authHeadersForToken(
    String? token, {
    Map<String, String>? extra,
  }) => _authHeaders(token, extra: extra);

  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) => _request(method, path, body: body, headers: headers);

  @override
  Future<List<dynamic>> requestList(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final value = await _requestJson(
      method,
      path,
      body: body,
      headers: headers,
    );
    if (value is List) return value;
    throw AuthApiException(
      'The server returned an invalid list response.',
      502,
      value is Map<String, dynamic> ? value : const {},
    );
  }

  Map<String, String> _authHeaders(
    String? token, {
    Map<String, String>? extra,
  }) {
    final headers = <String, String>{};
    if (extra != null) headers.addAll(extra);
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String role,
  }) => _post('/api/auth/register', {
    'email': email,
    'password': password,
    'role': role,
  });

  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String code,
  }) => _post('/api/auth/verify-email', {'email': email, 'code': code});

  Future<Map<String, dynamic>> resendVerification(String email) =>
      _post('/api/auth/resend-verification', {'email': email});

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) => _post('/api/auth/login', {'email': email, 'password': password});

  Future<Map<String, dynamic>> switchMerchantPortalMode({
    required String token,
    required String mode,
  }) => _request(
    'POST',
    '/api/auth/portal-mode',
    body: {'mode': mode},
    headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
  );

  Future<Map<String, dynamic>> merchantProfile(String token) =>
      _request('GET', '/api/merchant/profile', headers: _authHeaders(token));

  Future<void> registerNotificationDevice({
    required String token,
    required String fcmToken,
    required String sound,
  }) async {
    await _request(
      'PUT',
      '/api/notifications/device',
      body: {'fcmToken': fcmToken, 'sound': sound},
      headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
    );
  }

  Future<void> unregisterNotificationDevice({
    required String token,
    required String fcmToken,
  }) async {
    await _request(
      'DELETE',
      '/api/notifications/device',
      body: {'fcmToken': fcmToken},
      headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
    );
  }

  Future<Map<String, dynamic>> merchantBookingDeadlines(String token) =>
      _request(
        'GET',
        '/api/merchant/booking-deadlines',
        headers: _authHeaders(token),
      );

  Future<Map<String, dynamic>> saveMerchantBookingDeadlines({
    required String token,
    required int approvalTimeoutMinutes,
    required int paymentTimeoutMinutes,
  }) => _request(
    'PUT',
    '/api/merchant/booking-deadlines',
    body: {
      'approvalTimeoutMinutes': approvalTimeoutMinutes,
      'paymentTimeoutMinutes': paymentTimeoutMinutes,
    },
    headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
  );

  Future<Map<String, dynamic>> updateCustomerProfile({
    required String token,
    required String firstName,
    required String lastName,
    required String phone,
    required String address,
    required String hobby,
    String? avatarUrl,
  }) => _request(
    'PUT',
    '/api/auth/profile',
    body: {
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'address': address,
      'hobby': hobby,
      'avatarUrl': avatarUrl,
    },
    headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
  );

  Future<Map<String, dynamic>> completeCustomerOnboarding({
    required String token,
    required String gender,
    String? playerType,
    required String hobby,
  }) => _request(
    'PUT',
    '/api/auth/onboarding',
    body: {'gender': gender, 'playerType': playerType, 'hobby': hobby},
    headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
  );

  Future<Map<String, dynamic>> saveMerchantProfile({
    required String token,
    required Map<String, dynamic> profile,
  }) => _request(
    'PUT',
    '/api/merchant/profile',
    body: profile,
    headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
  );

  Future<List<Map<String, dynamic>>> merchantBusinesses(String token) async {
    final response = await _request(
      'GET',
      '/api/merchant/businesses',
      headers: _authHeaders(token),
    );
    return asMapList(response['businesses'] ?? response['data']);
  }

  Future<void> createMerchantBusiness({
    required String token,
    required Map<String, dynamic> business,
  }) async {
    await _request(
      'POST',
      '/api/merchant/businesses',
      body: business,
      headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
    );
  }

  Future<void> updateMerchantBusiness({
    required String token,
    required int id,
    required Map<String, dynamic> business,
  }) async {
    await _request(
      'PUT',
      '/api/merchant/businesses/$id',
      body: business,
      headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
    );
  }

  Future<void> setMerchantBusinessEnabled({
    required String token,
    required int id,
    required bool enabled,
  }) async {
    await _request(
      'PUT',
      '/api/merchant/businesses/$id/status',
      body: {'enabled': enabled},
      headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
    );
  }

  Future<void> updateMerchantBusinessImages({
    required String token,
    required int id,
    required List<String> imageUrls,
  }) async {
    await _request(
      'PUT',
      '/api/merchant/businesses/$id/images',
      body: {'imageUrls': imageUrls},
      headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
    );
  }

  Future<void> deleteMerchantBusiness({
    required String token,
    required int id,
  }) async {
    await _request(
      'DELETE',
      '/api/merchant/businesses/$id',
      headers: _authHeaders(token),
    );
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) =>
      _post('/api/auth/forgot-password', {'email': email});

  Future<Map<String, dynamic>> verifyPasswordResetCode({
    required String email,
    required String code,
  }) => _post('/api/auth/verify-password-reset-code', {
    'email': email,
    'code': code,
  });

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String password,
  }) => _post('/api/auth/reset-password', {
    'email': email,
    'code': code,
    'password': password,
  });

  Future<Map<String, dynamic>> loginWithGoogle(String idToken, {String? role}) {
    final payload = <String, dynamic>{'idToken': idToken};
    if (role != null && role.isNotEmpty) {
      payload['role'] = role;
    }
    return _post('/api/auth/oauth/google', payload);
  }

  Future<Map<String, dynamic>> me(String token) =>
      _request('GET', '/api/auth/me', headers: _authHeaders(token));

  Future<void> logout(String? refreshToken) async {
    if (refreshToken == null || refreshToken.isEmpty) return;
    await httpClient.request(
      'POST',
      '/api/auth/logout',
      body: {'refreshToken': refreshToken},
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<List<Map<String, dynamic>>> activityLogs(String token) async {
    final response = await _request(
      'GET',
      '/api/activity-logs',
      headers: _authHeaders(token),
    );
    return (response['activities'] as List<dynamic>? ??
            response['data'] as List<dynamic>? ??
            [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) =>
      _request(
        'POST',
        path,
        body: body,
        headers: {'Content-Type': 'application/json'},
      );

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final value = await _requestJson(
      method,
      path,
      body: body,
      headers: headers,
    );
    if (value is Map<String, dynamic>) return value;
    if (value is List) return {'data': value};
    throw const AuthApiException(
      'The server returned an invalid response.',
      502,
    );
  }

  Future<Object?> _requestJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    try {
      return await httpClient.requestJson(
        method,
        path,
        body: body,
        headers: headers,
      );
    } on AuthApiException catch (error) {
      final requestToken = _tokenFromHeaders(headers);
      if (error.statusCode != 401 ||
          requestToken == null ||
          path == '/api/auth/refresh') {
        rethrow;
      }

      final sessionService = AppSessionService.instance;
      final session = await sessionService.load();
      if (session.apiToken == requestToken) {
        if (session.refreshToken == null || session.refreshToken!.isEmpty) {
          rethrow;
        }
        try {
          await _refreshSession(sessionService);
        } on AuthApiException catch (refreshError) {
          if (refreshError.statusCode == 401 ||
              refreshError.statusCode == 403) {
            await sessionService.clearCurrentSession();
          }
          rethrow;
        }
      }

      final currentToken = session.apiToken;
      if (currentToken == null || currentToken.isEmpty) rethrow;
      return httpClient.requestJson(
        method,
        path,
        body: body,
        headers: _headersWithToken(headers, currentToken),
      );
    }
  }

  Future<void> _refreshSession(AppSessionService sessionService) async {
    final inProgress = _refreshInProgress;
    if (inProgress != null) {
      await inProgress;
      return;
    }

    final refresh = _performRefresh(sessionService);
    _refreshInProgress = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_refreshInProgress, refresh)) {
        _refreshInProgress = null;
      }
    }
  }

  Future<void> _performRefresh(AppSessionService sessionService) async {
    final session = await sessionService.load();
    final refreshToken = session.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const AuthApiException('The refresh session is unavailable.', 401);
    }
    final response = await httpClient.request(
      'POST',
      '/api/auth/refresh',
      body: {'refreshToken': refreshToken},
      headers: {'Content-Type': 'application/json'},
    );
    final token = response['token'];
    final nextRefreshToken = response['refreshToken'];
    if (token is! String ||
        token.isEmpty ||
        nextRefreshToken is! String ||
        nextRefreshToken.isEmpty) {
      throw const AuthApiException(
        'The server returned an incomplete refresh response.',
        502,
      );
    }
    await sessionService.updateSessionTokens(
      token: token,
      refreshToken: nextRefreshToken,
    );
  }

  String? _tokenFromHeaders(Map<String, String>? headers) {
    final authorization = headers?['Authorization'];
    if (authorization == null || !authorization.startsWith('Bearer ')) {
      return null;
    }
    return authorization.substring('Bearer '.length);
  }

  Map<String, String>? _headersWithToken(
    Map<String, String>? headers,
    String token,
  ) {
    if (headers == null) return _authHeaders(token);
    return {...headers, 'Authorization': 'Bearer $token'};
  }
}
