import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/app_design_system.dart';
import 'package:myapp/core/app_preferences.dart';
import 'package:myapp/core/app_theme.dart';
import 'package:myapp/features/messaging/presentation/messages_chat_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the sent time under an image message', (tester) async {
    final composer = TextEditingController();
    addTearDown(composer.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesChatView(
            messages: [
              {
                'id': 1,
                'senderId': 7,
                'createdAt': '2026-10-08T14:05:00',
                'attachment': {'type': 'image', 'data': 'invalid'},
              },
            ],
            currentUserId: 7,
            blocked: false,
            composer: composer,
            pendingImageData: null,
            sending: false,
            onDeleteMessage: (_) {},
            onPickImage: () {},
            onRemovePendingImage: () {},
            onSend: () async {},
          ),
        ),
      ),
    );

    expect(find.text('2:05 PM'), findsOneWidget);
  });

  testWidgets('booking tickets align with the sender and receiver sides', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final composer = TextEditingController();
    addTearDown(composer.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesChatView(
            messages: [
              {
                'id': 701,
                'senderId': 8,
                'attachment': {
                  'type': 'booking_ticket',
                  'bookingId': 701,
                  'venueName': 'Incoming ticket',
                },
              },
              {
                'id': 702,
                'senderId': 7,
                'attachment': {
                  'type': 'booking_ticket',
                  'bookingId': 702,
                  'venueName': 'Sent ticket',
                },
              },
            ],
            currentUserId: 7,
            blocked: false,
            composer: composer,
            pendingImageData: null,
            sending: false,
            onDeleteMessage: (_) {},
            onPickImage: () {},
            onRemovePendingImage: () {},
            onSend: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final incoming = tester.getRect(
      find.byKey(const ValueKey('message-ticket-701')).last,
    );
    final sent = tester.getRect(
      find.byKey(const ValueKey('message-ticket-702')).last,
    );
    expect(incoming.left, lessThan(sent.left));
    expect(sent.right, closeTo(900 - 16, 1));
  });

  testWidgets('only merchants can decide incoming match booking tickets', (
    tester,
  ) async {
    final composer = TextEditingController();
    addTearDown(composer.dispose);
    Map<String, dynamic>? decidedTicket;
    bool? approved;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesChatView(
            messages: [
              {
                'id': 801,
                'senderId': 8,
                'attachment': {
                  'type': 'matchmaking_booking_request_ticket',
                  'bookingId': 52,
                  'lobbyId': 31,
                  'venueName': 'North Courts',
                  'sportType': 'Badminton',
                  'slotNumber': 2,
                  'matchDate': '2030-04-12',
                  'startTime': '18:30',
                  'totalPrice': 375,
                  'hostShareAmount': 187.5,
                  'status': 'pending_merchant_approval',
                },
              },
              {
                'id': 802,
                'senderId': 7,
                'attachment': {
                  'type': 'matchmaking_booking_request_ticket',
                  'bookingId': 53,
                  'status': 'pending_merchant_approval',
                },
              },
            ],
            currentUserId: 7,
            isMerchant: true,
            blocked: false,
            composer: composer,
            pendingImageData: null,
            sending: false,
            onDeleteMessage: (_) {},
            onMatchmakingMerchantDecision: (ticket, decision) async {
              decidedTicket = ticket;
              approved = decision;
            },
            onPickImage: () {},
            onRemovePendingImage: () {},
            onSend: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MATCH BOOKING REQUEST'), findsNWidgets(2));
    expect(find.widgetWithText(FilledButton, 'Approve'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();

    expect(decidedTicket?['lobbyId'], 31);
    expect(approved, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'starts at the latest message and scrolls back to older messages',
    (tester) async {
      final composer = TextEditingController();
      final scrollController = ScrollController();
      addTearDown(composer.dispose);
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagesChatView(
              messages: List.generate(
                30,
                (index) => {
                  'id': index + 1,
                  'senderId': 8,
                  'body': index == 0 ? 'Oldest message' : 'Message $index',
                },
              ),
              currentUserId: 7,
              blocked: false,
              composer: composer,
              pendingImageData: null,
              sending: false,
              onDeleteMessage: (_) {},
              onPickImage: () {},
              onRemovePendingImage: () {},
              onSend: () async {},
              scrollController: scrollController,
            ),
          ),
        ),
      );

      expect(find.text('Message 29'), findsOneWidget);
      expect(find.text('Oldest message'), findsNothing);
      expect(scrollController.offset, 0);

      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(find.text('Oldest message'), findsOneWidget);
    },
  );

  testWidgets('omits the sent time when a message timestamp is invalid', (
    tester,
  ) async {
    final composer = TextEditingController();
    addTearDown(composer.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesChatView(
            messages: [
              {'id': 1, 'senderId': 7, 'createdAt': 'not-a-date', 'body': 'Hi'},
            ],
            currentUserId: 7,
            blocked: false,
            composer: composer,
            pendingImageData: null,
            sending: false,
            onDeleteMessage: (_) {},
            onPickImage: () {},
            onRemovePendingImage: () {},
            onSend: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Hi'), findsOneWidget);
    expect(find.textContaining('AM'), findsNothing);
    expect(find.textContaining('PM'), findsNothing);
  });

  testWidgets('long-pressing an incoming message exposes it for removal', (
    tester,
  ) async {
    final composer = TextEditingController();
    addTearDown(composer.dispose);
    Map<String, dynamic>? selectedMessage;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesChatView(
            messages: [
              {'id': 2, 'senderId': 8, 'body': 'Incoming message'},
            ],
            currentUserId: 7,
            blocked: false,
            composer: composer,
            pendingImageData: null,
            sending: false,
            onDeleteMessage: (message) => selectedMessage = message,
            onPickImage: () {},
            onRemovePendingImage: () {},
            onSend: () async {},
          ),
        ),
      ),
    );

    await tester.longPress(find.byKey(const ValueKey('message-bubble-2')));

    expect(selectedMessage?['id'], 2);
  });

  testWidgets('renders a message removed for everyone as a named chat bubble', (
    tester,
  ) async {
    final composer = TextEditingController();
    addTearDown(composer.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesChatView(
            messages: [
              {
                'id': 3,
                'senderId': 8,
                'body': null,
                'removedAt': '2026-10-10T10:00:00',
                'removedByName': 'Franze User',
              },
            ],
            currentUserId: 7,
            blocked: false,
            composer: composer,
            pendingImageData: null,
            sending: false,
            onDeleteMessage: (_) {},
            onPickImage: () {},
            onRemovePendingImage: () {},
            onSend: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Franze User deleted a message'), findsOneWidget);
    expect(find.byKey(const ValueKey('message-bubble-3')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('message-bubble-3'))).dx,
      lessThan(100),
    );
  });

  testWidgets('shows own deleted-for-everyone message on the sender side', (
    tester,
  ) async {
    final composer = TextEditingController();
    addTearDown(composer.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesChatView(
            messages: [
              {
                'id': 4,
                'senderId': 7,
                'body': null,
                'removedAt': '2026-10-10T10:00:00',
                'removedByName': 'Customer One',
              },
            ],
            currentUserId: 7,
            blocked: false,
            composer: composer,
            pendingImageData: null,
            sending: false,
            onDeleteMessage: (_) {},
            onPickImage: () {},
            onRemovePendingImage: () {},
            onSend: () async {},
          ),
        ),
      ),
    );

    expect(find.text('You deleted a message'), findsOneWidget);
    expect(find.byKey(const ValueKey('message-bubble-4')), findsOneWidget);
    expect(
      tester.getTopRight(find.byKey(const ValueKey('message-bubble-4'))).dx,
      greaterThan(300),
    );
  });

  testWidgets('shows a reply preview and responds to a right swipe', (
    tester,
  ) async {
    final composer = TextEditingController();
    addTearDown(composer.dispose);
    Map<String, dynamic>? repliedTo;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesChatView(
            messages: [
              {'id': 12, 'senderId': 8, 'body': 'Original message'},
            ],
            currentUserId: 7,
            blocked: false,
            composer: composer,
            pendingImageData: null,
            sending: false,
            onDeleteMessage: (_) {},
            onPickImage: () {},
            onRemovePendingImage: () {},
            onPickDocument: () {},
            onRemovePendingDocument: () {},
            onSend: () async {},
            replyTarget: {
              'id': 12,
              'senderName': 'Mary',
              'body': 'Original message',
            },
            onReplyToMessage: (message) => repliedTo = message,
            onClearReply: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Replying to Mary'), findsOneWidget);
    expect(find.textContaining('Original message'), findsWidgets);

    await tester.fling(
      find.byKey(const ValueKey('message-bubble-12')),
      const Offset(250, 0),
      2000,
    );
    await tester.pumpAndSettle();

    expect(repliedTo?['id'], 12);
  });

  testWidgets('incoming message text remains readable in dark mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences.instance.update(
      darkMode: true,
      palette: AppPalette.orange,
    );
    addTearDown(
      () => AppPreferences.instance.update(
        darkMode: false,
        palette: AppPalette.orange,
      ),
    );
    final composer = TextEditingController();
    addTearDown(composer.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.configured(
          darkMode: true,
          accentColor: AppPalette.orange.color,
        ),
        home: Scaffold(
          body: MessagesChatView(
            messages: [
              {'id': 2, 'senderId': 8, 'body': 'Incoming message'},
            ],
            currentUserId: 7,
            blocked: false,
            composer: composer,
            pendingImageData: null,
            sending: false,
            onDeleteMessage: (_) {},
            onPickImage: () {},
            onRemovePendingImage: () {},
            onSend: () async {},
          ),
        ),
      ),
    );

    final bubble = tester.widget<Card>(
      find.byKey(const ValueKey('message-bubble-2')),
    );
    final message = tester.widget<Text>(
      find.byKey(const ValueKey('message-body-2')),
    );
    expect(bubble.color, AppColors.surfaceVariant);
    expect(message.style?.color, AppColors.darkInk);
  });
}
