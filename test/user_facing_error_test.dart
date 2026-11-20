import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/api_http_client.dart';
import 'package:myapp/core/user_facing_error.dart';

void main() {
  group('userFacingErrorMessage', () {
    test('uses safe AuthApiException user message', () {
      final error = const AuthApiException(
        'Database unavailable',
        503,
      );

      expect(userFacingErrorMessage(error), 'Something went wrong on our end. Please try again.');
    });

    test('strips raw exception wrappers but keeps a useful phrase', () {
      expect(
        userFacingErrorMessage(Exception('The session expired')),
        'The session expired',
      );
      expect(
        userFacingErrorMessage(FormatException('Bad response body')),
        'Bad response body',
      );
    });

    test('falls back for internal implementation details', () {
      expect(
        userFacingErrorMessage(Exception('Instance of _InternalLinkedHashMap<String, dynamic>')),
        'Something went wrong. Please try again.',
      );
      expect(
        userFacingErrorMessage(
          TimeoutException('not used'),
          fallback: 'Please try again.',
        ),
        'The request took too long. Please try again.',
      );
    });
  });
}
