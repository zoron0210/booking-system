import 'dart:async';

import 'package:myapp/core/api_http_client.dart';

String userFacingErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is AuthApiException) return error.userMessage;
  if (error is TimeoutException) {
    return 'The request took too long. Please try again.';
  }
  if (error is FormatException) {
    final customMessage = error.message.trim();
    return customMessage.isNotEmpty ? customMessage : fallback;
  }

  final raw = error.toString().trim();
  if (raw.isEmpty) return fallback;

  final match = RegExp(
    r'^(?:[A-Za-z0-9_]+Exception|Exception|FormatException|TimeoutException|SocketException|HttpException)\s*:\s*(.*)$',
  ).firstMatch(raw);
  final cleaned = (match?.group(1) ?? raw).trim();

  if (cleaned.isEmpty ||
      cleaned == 'Instance of' ||
      cleaned.startsWith('Instance of ') ||
      cleaned.contains('StackTrace') ||
      cleaned.contains('dart:') ||
      cleaned.contains('package:')) {
    return fallback;
  }

  return cleaned;
}
