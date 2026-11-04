import 'dart:async';
import 'dart:convert';

import 'package:myapp/core/api_http_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class LiveUpdatesClient {
  LiveUpdatesClient({String? baseUrl}) : _baseUrl = baseUrl ?? apiBaseUrl;

  static const _connectionTimeout = Duration(seconds: 5);

  final String _baseUrl;
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();
  final Completer<void> _closeSignal = Completer<void>();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  bool _closed = false;

  Stream<Map<String, dynamic>> get events => _events.stream;

  Future<void> connect(String token) async {
    if (token.isEmpty) throw ArgumentError.value(token, 'token');
    if (_closed) throw StateError('The live-update connection is closed.');

    final channel = WebSocketChannel.connect(_webSocketUri());
    _channel = channel;
    final authenticated = Completer<void>();
    var authenticationStarted = false;
    Object? authenticationError;
    StackTrace? authenticationStackTrace;

    void failAuthentication(Object error, StackTrace stackTrace) {
      if (authenticated.isCompleted) {
        _events.addError(error, stackTrace);
      } else if (authenticationStarted) {
        authenticated.completeError(error, stackTrace);
      } else {
        authenticationError = error;
        authenticationStackTrace = stackTrace;
      }
    }

    _subscription = channel.stream.listen(
      (data) {
        try {
          final decoded = jsonDecode(data as String);
          if (decoded is! Map<String, dynamic>) {
            throw const FormatException('Invalid live-update message.');
          }
          if (decoded['type'] == 'ready') {
            if (!authenticated.isCompleted) authenticated.complete();
          } else if (decoded['type'] == 'error') {
            failAuthentication(
              StateError('The live-update connection was rejected.'),
              StackTrace.current,
            );
          } else if (authenticated.isCompleted) {
            _events.add(decoded);
          }
        } on Object catch (error, stackTrace) {
          failAuthentication(error, stackTrace);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        failAuthentication(error, stackTrace);
      },
      onDone: () {
        if (!authenticated.isCompleted) {
          failAuthentication(
            StateError(
              'The live-update connection closed before authentication.',
            ),
            StackTrace.current,
          );
        } else if (!_closed) {
          _events.addError(
            StateError('The live-update connection was closed.'),
          );
        }
      },
    );

    try {
      await _waitForConnection(channel.ready);
      authenticationStarted = true;
      final error = authenticationError;
      if (error != null) {
        authenticated.completeError(
          error,
          authenticationStackTrace ?? StackTrace.current,
        );
      } else {
        channel.sink.add(jsonEncode({'type': 'authenticate', 'token': token}));
      }
      await _waitForConnection(authenticated.future);
    } on Object {
      await close();
      rethrow;
    }
  }

  Future<void> _waitForConnection(Future<void> pending) {
    final result = Completer<void>();
    final timeout = Timer(_connectionTimeout, () {
      if (result.isCompleted) return;
      result.completeError(
        TimeoutException(
          'The live-update connection timed out.',
          _connectionTimeout,
        ),
      );
    });

    pending.then<void>(
      (_) {
        if (result.isCompleted) return;
        timeout.cancel();
        result.complete();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (result.isCompleted) return;
        timeout.cancel();
        result.completeError(error, stackTrace);
      },
    );
    _closeSignal.future.then<void>((_) {
      if (result.isCompleted) return;
      timeout.cancel();
      result.completeError(
        StateError('The live-update connection was closed.'),
        StackTrace.current,
      );
    });

    return result.future;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _closeSignal.complete();
    await _subscription?.cancel();
    await _channel?.sink.close();
    await _events.close();
  }

  Uri _webSocketUri() {
    final baseUri = Uri.parse(_baseUrl);
    final path = '${baseUri.path.replaceFirst(RegExp(r'/+$'), '')}/api/live';
    return baseUri.replace(
      scheme: baseUri.scheme == 'https' ? 'wss' : 'ws',
      path: path,
      query: null,
      fragment: null,
    );
  }
}
