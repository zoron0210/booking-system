part of 'merchant_dashboard.dart';

extension _MerchantDashboardMatchmaking on _MerchantDashboardPageState {
  Future<void> _loadMatchmakingRequests({bool force = false}) async {
    final activeRequest = _matchmakingRequest;
    if (activeRequest != null) {
      await activeRequest;
      if (force) await _loadMatchmakingRequests();
      return;
    }

    late final Future<void> request;
    request = _fetchMatchmakingRequests().whenComplete(() {
      if (identical(_matchmakingRequest, request)) _matchmakingRequest = null;
    });
    _matchmakingRequest = request;
    await request;
  }

  Future<void> _fetchMatchmakingRequests() async {
    if (mounted) {
      _setAnalyticsState(() {
        _matchmakingLoading = true;
        _matchmakingLoadError = null;
      });
    }
    try {
      final session = await _sessionProvider.load();
      final token = session.apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Your session has expired.', 401);
      }
      final response = await _api.request(
        'GET',
        '/api/merchant/matchmaking/lobbies',
        headers: _api.authHeadersForToken(token),
      );
      final rawRequests = response['lobbies'];
      if (rawRequests is! List) {
        throw const FormatException(
          'The server returned invalid matchmaking requests.',
        );
      }
      final requests = rawRequests
          .map((request) {
            if (request is! Map) {
              throw const FormatException(
                'The server returned an invalid matchmaking request.',
              );
            }
            return Map<String, dynamic>.from(request);
          })
          .toList(growable: false);
      if (mounted) {
        _setAnalyticsState(() {
          _matchmakingRequests = requests;
          _matchmakingLoaded = true;
          _matchmakingLoading = false;
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        _setAnalyticsState(() {
          _matchmakingLoading = false;
          _matchmakingLoadError = _merchantLoadFailureMessage(
            'matchmaking requests',
            error,
          );
        });
      }
    }
  }

  Widget _matchmakingQueueCard() => Card(
    key: const ValueKey('merchant-matchmaking-queue'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText(
            'Matchmaking requests',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 10),
          if (_matchmakingRequests.isEmpty)
            const AppText('No matchmaking requests need review.')
          else
            for (final request in _matchmakingRequests) ...[
              Container(
                key: ValueKey('merchant-matchmaking-${request['lobbyId']}'),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Host: ${request['hostName'] ?? 'Player'}'),
                    Text(
                      '${request['sportType'] ?? 'Sport'} · '
                      'Court ${request['slotNumber'] ?? '—'} · '
                      '${request['matchDate'] ?? ''} ${request['startTime'] ?? ''}',
                    ),
                    Text(
                      'Opponent criteria: '
                      '${request['opponentCriteria'] ?? 'Open to all players'}',
                    ),
                    Text(
                      'Venue: ${request['venueName'] ?? 'Your venue'} · '
                      'Host downpayment ₱${_money(request['hostShareAmount'])}',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed:
                              _decidingMatchmakingRequests.contains(
                                _asPositiveId(request['lobbyId']),
                              )
                              ? null
                              : () => _decideMatchmakingRequest(request, false),
                          child: const AppText('Decline'),
                        ),
                        FilledButton(
                          onPressed:
                              _decidingMatchmakingRequests.contains(
                                _asPositiveId(request['lobbyId']),
                              )
                              ? null
                              : () => _decideMatchmakingRequest(request, true),
                          child: const AppText('Approve'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    ),
  );

  Future<void> _decideMatchmakingRequest(
    Map<String, dynamic> request,
    bool approve,
  ) async {
    final lobbyId = _asPositiveId(request['lobbyId']);
    if (lobbyId == null || _decidingMatchmakingRequests.contains(lobbyId)) {
      return;
    }
    _setAnalyticsState(() => _decidingMatchmakingRequests.add(lobbyId));
    try {
      final session = await _sessionProvider.load();
      final token = session.apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Log in to review this request.', 401);
      }
      await _api.request(
        'POST',
        '/api/matchmaking/lobbies/$lobbyId/merchant-${approve ? 'approve' : 'decline'}',
        headers: _api.authHeadersForToken(token),
      );
      await _loadMatchmakingRequests(force: true);
      if (mounted) {
        _showMessage(
          approve
              ? 'Approved. The host has 15 minutes to pay the downpayment.'
              : 'Declined. The court slot is now available.',
        );
      }
    } on Exception catch (error) {
      if (mounted) {
        _showMessage('Could not update matchmaking request: $error');
      }
    } finally {
      if (mounted) {
        _setAnalyticsState(() => _decidingMatchmakingRequests.remove(lobbyId));
      }
    }
  }

  int? _asPositiveId(dynamic value) {
    final id = value is num ? value.toInt() : int.tryParse('$value');
    return id != null && id > 0 ? id : null;
  }

  String _money(dynamic value) {
    final amount = double.tryParse('$value');
    return amount == null ? '0.00' : amount.toStringAsFixed(2);
  }
}
