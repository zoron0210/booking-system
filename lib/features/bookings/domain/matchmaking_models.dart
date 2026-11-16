import 'dart:convert';

class MatchmakingLobby {
  const MatchmakingLobby({
    required this.id,
    required this.hostUserId,
    required this.venueId,
    required this.venueName,
    required this.venueAddress,
    this.venueLogoUrl,
    required this.venueImages,
    required this.venueRating,
    required this.venueReviewCount,
    required this.sportType,
    required this.slotNumber,
    required this.matchDate,
    required this.startTime,
    required this.durationHours,
    required this.totalPrice,
    required this.hostShareAmount,
    required this.hostBalanceAmount,
    required this.opponentShareAmount,
    required this.paymentMethod,
    required this.paymentPolicy,
    required this.skillLevel,
    required this.opponentCriteria,
    required this.status,
    required this.hostFirstName,
    required this.hostAvatarUrl,
    required this.requestStatus,
    required this.latitude,
    required this.longitude,
  });

  factory MatchmakingLobby.fromJson(Map<String, dynamic> json) {
    final id = _positiveInt(json['id']);
    final hostUserId = _positiveInt(json['hostUserId']);
    final venueId = _positiveInt(json['venueId']);
    final slotNumber = _positiveInt(json['slotNumber']);
    final durationHours = _doubleValue(json['durationHours']);
    final totalPrice = _doubleValue(json['totalPrice']);
    final hostShareAmount = _doubleValue(json['hostShareAmount']);
    final hostBalanceAmount = _doubleValue(json['hostBalanceAmount']) ?? 0;
    final opponentShareAmount = _doubleValue(json['opponentShareAmount']);
    final sportType = json['sportType'];
    final venueName = json['venueName'];
    final matchDate = json['matchDate'];
    final startTime = json['startTime'];
    final skillLevel = json['skillLevel'];
    final status = json['status'];
    final reviewCount = _nonNegativeInt(json['venueReviewCount']);
    if (id == null ||
        hostUserId == null ||
        venueId == null ||
        slotNumber == null ||
        sportType is! String ||
        venueName is! String ||
        matchDate is! String ||
        startTime is! String ||
        durationHours == null ||
        totalPrice == null ||
        hostShareAmount == null ||
        opponentShareAmount == null ||
        reviewCount == null ||
        skillLevel is! String ||
        status is! String) {
      throw const FormatException(
        'The server returned an invalid match lobby.',
      );
    }
    return MatchmakingLobby(
      id: id,
      hostUserId: hostUserId,
      venueId: venueId,
      venueName: venueName,
      venueAddress: _optionalString(json['venueAddress']),
      venueLogoUrl: _optionalString(json['venueLogoUrl']),
      venueImages: _stringList(json['venueImageUrls'], json['venueImageUrl']),
      venueRating: _doubleValue(json['venueRating']) ?? 0,
      venueReviewCount: reviewCount,
      sportType: sportType,
      slotNumber: slotNumber,
      matchDate: matchDate,
      startTime: startTime,
      durationHours: durationHours,
      totalPrice: totalPrice,
      hostShareAmount: hostShareAmount,
      hostBalanceAmount: hostBalanceAmount,
      opponentShareAmount: opponentShareAmount,
      paymentMethod: _optionalString(json['paymentMethod']) ?? 'online',
      paymentPolicy:
          _optionalString(json['paymentPolicy']) ?? 'split_remaining',
      skillLevel: skillLevel,
      opponentCriteria: _optionalString(json['opponentCriteria']),
      status: status,
      hostFirstName: _optionalString(json['hostFirstName']) ?? 'Player',
      hostAvatarUrl: _optionalString(json['hostAvatarUrl']),
      requestStatus: _optionalString(json['requestStatus']),
      latitude: _doubleValue(json['venueLatitude']),
      longitude: _doubleValue(json['venueLongitude']),
    );
  }

  final int id;
  final int hostUserId;
  final int venueId;
  final String venueName;
  final String? venueAddress;
  final String? venueLogoUrl;
  final List<String> venueImages;
  final double venueRating;
  final int venueReviewCount;
  final String sportType;
  final int slotNumber;
  final String matchDate;
  final String startTime;
  final double durationHours;
  final double totalPrice;
  final double hostShareAmount;
  final double hostBalanceAmount;
  final double opponentShareAmount;
  final String paymentMethod;
  final String paymentPolicy;
  final String skillLevel;
  final String? opponentCriteria;
  final String status;
  final String hostFirstName;
  final String? hostAvatarUrl;
  final String? requestStatus;
  final double? latitude;
  final double? longitude;
}

bool matchmakingLobbyMatchesSearch(MatchmakingLobby lobby, String query) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return true;
  final searchableText = [
    'match ${lobby.id}',
    lobby.id.toString(),
    lobby.venueName,
    lobby.venueAddress,
    lobby.sportType,
    lobby.hostFirstName,
    lobby.opponentCriteria,
    lobby.matchDate,
    lobby.startTime,
    lobby.skillLevel,
    'court ${lobby.slotNumber}',
  ].whereType<String>().join(' ').toLowerCase();
  return searchableText.contains(normalizedQuery);
}

class MatchmakingHostRequest {
  const MatchmakingHostRequest({
    required this.lobbyId,
    required this.bookingId,
    required this.venueName,
    required this.sportType,
    required this.slotNumber,
    required this.matchDate,
    required this.startTime,
    required this.totalPrice,
    required this.hostShareAmount,
    required this.hostBalanceAmount,
    required this.opponentShareAmount,
    required this.paymentMethod,
    required this.paymentPolicy,
    required this.hostBalancePaymentStatus,
    required this.status,
    required this.paymentStatus,
    required this.paymentDueAt,
  });

  factory MatchmakingHostRequest.fromJson(Map<String, dynamic> json) {
    final lobbyId = _positiveInt(json['lobbyId']);
    final bookingId = _positiveInt(json['bookingId']);
    final slotNumber = _positiveInt(json['slotNumber']);
    final totalPrice = _doubleValue(json['totalPrice']);
    final hostShareAmount = _doubleValue(json['hostShareAmount']);
    final hostBalanceAmount = _doubleValue(json['hostBalanceAmount']) ?? 0;
    final opponentShareAmount = _doubleValue(json['opponentShareAmount']);
    if (lobbyId == null ||
        bookingId == null ||
        slotNumber == null ||
        totalPrice == null ||
        hostShareAmount == null ||
        opponentShareAmount == null) {
      throw const FormatException('The server returned an invalid host match.');
    }
    return MatchmakingHostRequest(
      lobbyId: lobbyId,
      bookingId: bookingId,
      venueName: _optionalString(json['venueName']) ?? 'Venue',
      sportType: _optionalString(json['sportType']) ?? 'Match',
      slotNumber: slotNumber,
      matchDate: _optionalString(json['matchDate']) ?? '',
      startTime: _optionalString(json['startTime']) ?? '',
      totalPrice: totalPrice,
      hostShareAmount: hostShareAmount,
      hostBalanceAmount: hostBalanceAmount,
      opponentShareAmount: opponentShareAmount,
      paymentMethod: _optionalString(json['paymentMethod']) ?? 'online',
      paymentPolicy:
          _optionalString(json['paymentPolicy']) ?? 'split_remaining',
      hostBalancePaymentStatus:
          _optionalString(json['hostBalancePaymentStatus']) ?? 'unpaid',
      status: _optionalString(json['status']) ?? 'pending_merchant_approval',
      paymentStatus: _optionalString(json['paymentStatus']) ?? 'unpaid',
      paymentDueAt: _optionalString(json['paymentDueAt']),
    );
  }

  final int lobbyId;
  final int bookingId;
  final String venueName;
  final String sportType;
  final int slotNumber;
  final String matchDate;
  final String startTime;
  final double totalPrice;
  final double hostShareAmount;
  final double hostBalanceAmount;
  final double opponentShareAmount;
  final String paymentMethod;
  final String paymentPolicy;
  final String hostBalancePaymentStatus;
  final String status;
  final String paymentStatus;
  final String? paymentDueAt;
}

class MatchmakingRequest {
  const MatchmakingRequest({
    required this.requestId,
    required this.conversationId,
    required this.status,
  });

  factory MatchmakingRequest.fromJson(Map<String, dynamic> json) {
    final requestId = _positiveInt(json['requestId']);
    final conversationId = _positiveInt(json['conversationId']);
    final status = json['status'];
    if (requestId == null ||
        conversationId == null ||
        (status != null && status is! String)) {
      throw const FormatException(
        'The server returned an invalid match request.',
      );
    }
    return MatchmakingRequest(
      requestId: requestId,
      conversationId: conversationId,
      status: status as String? ?? 'pending',
    );
  }

  final int requestId;
  final int conversationId;
  final String status;
}

int? _positiveInt(dynamic value) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  return parsed != null && parsed > 0 ? parsed : null;
}

int? _nonNegativeInt(dynamic value) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  return parsed != null && parsed >= 0 ? parsed : null;
}

double? _doubleValue(dynamic value) =>
    value == null ? null : double.tryParse('$value');

String? _optionalString(dynamic value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

List<String> _stringList(dynamic value, dynamic fallback) {
  dynamic parsed = value;
  if (parsed is String && parsed.trim().isNotEmpty) {
    try {
      parsed = jsonDecode(parsed);
    } on FormatException {
      parsed = null;
    }
  }
  final images = parsed is List
      ? parsed
            .whereType<String>()
            .map((image) => image.trim())
            .where((image) => image.isNotEmpty)
            .toList()
      : <String>[];
  if (images.isNotEmpty) return List.unmodifiable(images);
  final single = _optionalString(fallback);
  return single == null ? const [] : [single];
}
