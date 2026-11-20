# SpotGo Engineering Action Plan & Copilot Task Registry

This document is the **living task registry** for GitHub Copilot in VS Code.
Whenever a task is completed, it is marked with `[x]`. Copilot is instructed to inspect files first and **never remake or duplicate any task marked with `[x]`**.

---

## Zero-Regression Safety Rules for Copilot
1. **Never weaken security**: Retain all backend `requireAuth`, `requireRole`, and HMAC signature verifications.
2. **Never break database transactions**: Preserve `SELECT ... FOR UPDATE`, `connection.beginTransaction()`, `connection.commit()`, and `connection.rollback()`.
3. **Inspect before modifying**: If code or tests for a task are already present in the workspace, do NOT overwrite or duplicate them.
4. **No cross-feature `part` coupling**: Use constructor dependency injection, not Dart `part` / `part of`.
5. **No `pushReplacement` tab switching**: Use `IndexedStack` (via `CustomerNavigationShell`).

---

## Task Progress & Execution Checklist

### Phase 1: Bug Fixes & Strong Typing
- [x] **Task 1.1**: Support top-level JSON arrays in API responses (`lib/core/api_http_client.dart`, verified by `test/api_http_client_test.dart`)
- [x] **Task 1.2**: Audit `flutter_map` & `latlong2` usage; retain both because map/geocoding features import them
- [x] **Task 1.3**: Normalize API Base URL Path Concatenation (`lib/core/api_http_client.dart`, verified by `test/api_http_client_test.dart`)
- [x] **Task 1.4**: Deprecate map-style `Booking` access and use typed fields in customer booking flows (`lib/features/bookings/domain/booking.dart`)

### Phase 2: Live Updates & Token Security
- [x] **Task 2.1**: Implement 15-Minute Access Tokens + 30-Day Refresh Tokens (`backend/src/routes/auth_routes.js`, verified by `test/auth_token_refresh_test.dart`)
- [x] **Task 2.2**: Cache Active User Status in `requireAuth` Middleware (`backend/src/server.js`)
- [x] **Task 2.3**: Replace HTTP Polling with WebSockets for Chat & Booking Alerts (`backend/src/websocket_hub.js`, `lib/core/live_updates_client.dart`)

### Phase 3: Navigation & Performance
- [x] **Task 3.1**: Persistent Bottom Navigation Shell with `IndexedStack` (`CustomerNavigationShell`, verified by `test/customer_navigation_shell_test.dart`)
- [x] **Task 3.2**: Disk Image Caching via `cached_network_image` (`pubspec.yaml`, `lib/features/app_shell/presentation/news_feed.dart`)
- [x] **Task 3.3**: Asynchronous Base64 Image Decoding (`lib/features/app_shell/presentation/news_feed.dart`)

### Phase 4: Decoupling & Architecture Cleanliness
- [x] **Task 4.1**: Decouple `AuthApi` Part Files into Standalone Feature Repositories (`lib/core/api_transport.dart`, `lib/features/*/data/`)
- [x] **Task 4.2**: Extract God Widgets into Modular Sub-Cards (`lib/features/merchant_management/presentation/merchant_payout_card.dart` created)
- [x] **Task 4.3**: Extract activity-log and saved-item route groups into sub-routers (`backend/src/routes/activity_log_routes.js`, `backend/src/routes/saved_items_routes.js`)
- [x] **Task 4.4**: Add Cursor-based Pagination (`before_id`, `limit`) to Social Feed (verified by `test/social_api_pagination_test.dart`)

### Phase 5: Sports Matchmaking & Player Queuing (Enhanced 2-Tier Approval Workflow)
- [x] **Task 5.1**: Matchmaking Database Schema & Booking Lifecycle Migration (`database/booking.sql`, `backend/src/routes/matchmaking_routes.js`)
- [x] **Task 5.2**: Strict Venue Conflict Checking & Host Creation (No immediate payment, slot availability validation)
- [x] **Task 5.3**: Merchant Approval Gate & Host 50% Downpayment Flow (`backend/src/server.js`, `lib/features/merchant_management/`)
- [x] **Task 5.4**: "Find Matches" Discovery Feed with Venue Assurance (Address, Photos, GPS Distance, Ratings)
- [x] **Task 5.5**: In-Chat Opponent Ticket (Accept / Decline Opponents & Auto-Chat Notification)

---

## Detailed Specifications: Phase 5 (Enhanced Matchmaking Workflow)

### [Task 5.1] Matchmaking Database Schema & Booking Lifecycle Migration
- **Target Files**:
  - `database/booking.sql`
  - `backend/src/schema_migrations.js`
  - `backend/src/routes/matchmaking_routes.js`
- **Specification**:
  1. Add column `allow_matchmaking TINYINT(1) NOT NULL DEFAULT 1` to `merchant_businesses`.
  2. Create table `matchmaking_lobbies`:
     - `id INT AUTO_INCREMENT PRIMARY KEY`
     - `host_user_id INT NOT NULL`
     - `venue_id INT NOT NULL`
     - `booking_id INT NOT NULL` -- Linked directly to the court booking record
     - `sport_type VARCHAR(100) NOT NULL`
     - `slot_number INT NOT NULL DEFAULT 1` -- Locked court number
     - `match_date DATE NOT NULL`
     - `start_time TIME NOT NULL`
     - `duration_hours DECIMAL(4,2) NOT NULL DEFAULT 1.00`
     - `total_price DECIMAL(10,2) NOT NULL`
     - `host_share_amount DECIMAL(10,2) NOT NULL` -- 50% downpayment
     - `opponent_share_amount DECIMAL(10,2) NOT NULL` -- Remaining 50%
     - `skill_level ENUM('beginner', 'intermediate', 'advanced', 'open') NOT NULL DEFAULT 'open'`
     - `opponent_criteria VARCHAR(255) NULL` -- What host is looking for
     - `status ENUM('pending_merchant_approval', 'awaiting_host_downpayment', 'open', 'matched', 'cancelled', 'expired', 'completed') NOT NULL DEFAULT 'pending_merchant_approval'`
     - `accepted_opponent_id INT NULL`
     - `created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP`
     - Foreign keys to `users(id)`, `merchant_businesses(id)`, `bookings(id)`.
  3. Create table `matchmaking_requests`:
     - `id INT AUTO_INCREMENT PRIMARY KEY`
     - `lobby_id INT NOT NULL`
     - `opponent_user_id INT NOT NULL`
     - `conversation_id INT NOT NULL`
     - `status ENUM('pending', 'accepted', 'declined', 'cancelled') NOT NULL DEFAULT 'pending'`
     - `created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP`
     - `UNIQUE KEY unique_lobby_opponent (lobby_id, opponent_user_id)`
- **Verification**: `cd backend && npm test test/matchmaking-routes.test.js`

---

### [Task 5.2] Strict Venue Conflict Checking & Host Creation (No Immediate Payment)
- **Target Files**:
  - `backend/src/routes/matchmaking_routes.js`
  - `lib/features/bookings/presentation/matchmaking_host_dialog.dart`
- **Specification**:
  1. When a Host creates a match (`POST /api/matchmaking/lobbies`):
     - **DO NOT CHARGE MONEY YET.**
     - Validate that the venue exists, `enabled = 1`, and `allow_matchmaking = 1`.
     - Validate that `sport_type` is valid for that venue.
     - Validate that `start_time` and `duration_hours` fall within venue `opening_hours`.
     - **Conflict Check**: Execute `SELECT id FROM bookings WHERE venue_id = ? AND booking_date = ? AND start_time = ? AND slot_number = ? AND status IN ('pending', 'approved', 'matchmaking_pending', 'matchmaking_open') FOR UPDATE`. If conflict exists, reject with 409 Conflict: `"This court slot is already booked for this date and time."`.
  2. Create a booking in `bookings` with `payment_status = 'unpaid'` and status `matchmaking_pending_merchant`.
  3. Create record in `matchmaking_lobbies` with status `pending_merchant_approval`.
  4. Trigger push notification & dashboard alert to the venue Merchant.
- **Verification**: `cd backend && npm test test/matchmaking-routes.test.js`

---

### [Task 5.3] Merchant Approval Gate & Host 50% Downpayment Flow
- **Target Files**:
  - `backend/src/routes/matchmaking_routes.js`
  - `backend/src/server.js`
  - `lib/features/merchant_management/presentation/merchant_dashboard.dart`
- **Specification**:
  1. Merchant views pending requests in Merchant Dashboard:
     - Matchmaking requests are highlighted with badge: `[🏸 Matchmaking Queue Request]`.
     - Shows Host name, Sport, Court slot, Date/Time, and Opponent criteria.
  2. If Merchant **Declines** (`POST /api/matchmaking/lobbies/:id/merchant-decline`):
     - Lobby status $\rightarrow$ `cancelled`, booking $\rightarrow$ `cancelled`.
     - Slot is immediately unlocked. Host receives notification: *"Venue could not accommodate your matchmaking request."*
  3. If Merchant **Approves** (`POST /api/matchmaking/lobbies/:id/merchant-approve`):
     - Lobby status $\rightarrow$ `awaiting_host_downpayment`.
     - Starts 15-minute payment deadline timer (`payment_due_at`).
     - Host receives push notification & in-app action: *"Your matchmaking request at [Venue] was approved! Pay 50% downpayment (₱X) within 15 mins to publish."*
  4. Host completes 50% payment:
     - Booking marked downpayment `paid`.
     - Lobby status $\rightarrow$ **`open`** (Published to the public "Find Matches" queue).
- **Verification**: `cd backend && npm test test/matchmaking-routes.test.js`

---

### [Task 5.4] "Find Matches" Discovery Feed with Venue Assurance
- **Target Files**:
  - `lib/features/bookings/presentation/matchmaking_lobby_list_page.dart`
  - `backend/src/routes/matchmaking_routes.js`
- **Specification**:
  1. `GET /api/matchmaking/lobbies` returns active lobbies with `status = 'open'`:
     - Includes complete venue assurance: Venue name, photos, full address, latitude/longitude, star rating, and review count.
     - Includes match details: Sport, Court #, Date, Start & End Time, Skill level pill.
     - Includes price breakdown: Total price, Host's 50% paid, Opponent share amount due.
     - Includes Host profile: First name, avatar, skill level, and opponent criteria note.
  2. In Flutter `matchmaking_lobby_list_page.dart`:
     - Displays real-time GPS distance (e.g. `📍 2.4 km away`).
     - "Request to Match" CTA button (disabled if already requested or if user is the Host).
     - Tap card to open full Venue details dialog for complete assurance.
- **Verification**: `flutter test test/matchmaking_lobby_test.dart`

---

### [Task 5.5] In-Chat Opponent Ticket (Accept / Decline & Auto-Notification)
- **Target Files**:
  - `backend/src/routes/matchmaking_routes.js`
  - `lib/features/bookings/presentation/widgets/matchmaking_ticket_card.dart`
  - `lib/features/messaging/presentation/messages_chat_view.dart`
- **Specification**:
  1. When Opponent taps "Request to Match" (`POST /api/matchmaking/lobbies/:id/join`):
     - Creates `matchmaking_requests` record.
     - Creates or opens 1-on-1 direct conversation between Host and Opponent.
     - Inserts an automated system message with attachment `{ type: 'matchmaking_ticket', lobbyId, requestId, status: 'pending' }`.
     - Sends push notification to Host.
  2. Host reviews the ticket in chat:
     - Displays Opponent name, avatar, skill level, and match details.
     - If status is `pending`, displays **`[ ❌ Decline ]`** and **`[ ✅ Accept ]`** buttons.
  3. If Host **Accepts** (`POST /api/matchmaking/lobbies/:id/requests/:requestId/accept`):
     - Uses row lock `SELECT ... FOR UPDATE` to ensure lobby is not already matched.
     - Lobby status $\rightarrow$ `matched`, request $\rightarrow$ `accepted`.
     - Opponent is prompted to pay their 50% share (Online PayMongo or Cash on Arrival).
     - Ticket updates to `Matched!`. Both players continue chatting in thread.
  4. If Host **Declines**:
     - Request $\rightarrow$ `declined`. Ticket updates to `Declined`. Lobby remains `open` for others.
- **Verification**: `flutter test test/matchmaking_lobby_test.dart`

---

## Ready-to-Run Copilot Prompts

### Step 1: Implement Backend Schema & 2-Tier Approval Flow (Task 5.1 & 5.2)
```text
@workspace Implement Task 5.1 and Task 5.2 from COPILOT_TASKS.md:
1. In database/booking.sql and backend/src/schema_migrations.js, update matchmaking_lobbies schema with 2-tier approval statuses ('pending_merchant_approval', 'awaiting_host_downpayment', 'open', 'matched').
2. In backend/src/routes/matchmaking_routes.js, implement POST /api/matchmaking/lobbies with strict venue conflict checking (FOR UPDATE) and NO immediate payment.
3. Add merchant approval/decline endpoints: POST /api/matchmaking/lobbies/:id/merchant-approve and POST /api/matchmaking/lobbies/:id/merchant-decline.
Verify with: cd backend && npm test
```

### Step 2: Implement Host 50% Downpayment & Publishing (Task 5.3)
```text
@workspace Implement Task 5.3 from COPILOT_TASKS.md:
1. Connect merchant approval to booking payment deadline (15 minutes).
2. When Host pays 50% downpayment, update lobby status to 'open' (published to public queue).
3. In lib/features/merchant_management/presentation/merchant_dashboard.dart, show matchmaking queue requests with Approve/Decline buttons.
```

### Step 3: Implement Discovery Feed & In-Chat Action Ticket (Task 5.4 & 5.5)
```text
@workspace Implement Task 5.4 and Task 5.5 from COPILOT_TASKS.md:
1. In lib/features/bookings/presentation/matchmaking_lobby_list_page.dart, display venue assurance info (photos, GPS distance, rating, price split 50%/50%).
2. In lib/features/bookings/presentation/widgets/matchmaking_ticket_card.dart, implement the in-chat ticket with Accept and Decline buttons for the Host.
Verify with: flutter test
```

---

### Phase 6: Social Club Communities
- [x] **Task 6.1**: Create public sports clubs, free membership, and member-only club posts (`backend/src/routes/social_club_routes.js`, `lib/features/social/presentation/social_clubs_page.dart`)
- [x] **Task 6.2**: Add owner club settings, editing/deletion, and optional member-join approval (`backend/src/routes/social_club_routes.js`, `lib/features/social/presentation/social_clubs_page.dart`)

### Phase 7: Booking Journey Clarity & Matchmaking Feed Completion
- [x] **Task 7.1**: Clarify regular booking vs matchmaking, explain matchmaking states and costs, and expose all feed pages (`lib/features/bookings/presentation/sports_booking_page.dart`, `lib/features/bookings/presentation/matchmaking_host_page.dart`, `lib/features/bookings/presentation/matchmaking_lobby_list_page.dart`, `lib/features/bookings/data/matchmaking_api.dart`, `backend/src/routes/matchmaking_routes.js`)

---

### [Task 7.1] Clarify Booking Choices, Matchmaking Commitments, and Feed Pagination
- **Inspect first**: Review the current booking, matchmaking, payment, and lobby state flows, including existing tests. Tasks 5.1–5.5 are complete; preserve their behavior and extend the current implementation rather than recreating it.
- **Zero-regression requirements**:
  - Retain authentication and role checks.
  - Preserve database transactions, row locks, payment deadlines, booking conflict checks, and existing payment calculations.
  - Keep the regular booking and matchmaking payment policies distinct and accurately described.
- **Target Files**:
  - `lib/features/bookings/presentation/sports_booking_page.dart`
  - `lib/features/bookings/presentation/matchmaking_host_page.dart`
  - `lib/features/bookings/presentation/matchmaking_lobby_list_page.dart`
  - `lib/features/bookings/data/matchmaking_api.dart`
  - `backend/src/routes/matchmaking_routes.js` (only if the existing pagination response needs adjustment)
- **Specification**:
  1. Explain the two venue actions in plain language: regular booking reserves court time for the customer's group; matchmaking hosts or joins a game with another player. Do not imply that players are automatically paired.
  2. Before a host submits, clearly summarize the actual sequence: request venue approval, pay the host deposit after approval within the stated deadline, then publish the match. Clearly distinguish online payment from cash-on-arrival handling.
  3. In the discovery feed, explain that requesting to join does not reserve a place; the host must accept the request. Show the player's amount due and payment method/policy clearly before they send the request.
  4. Present useful, human-readable progress for matchmaking requests using the existing lifecycle states (venue approval, host payment, open for players, awaiting host decision, matched, and terminal/expired states). Reuse backend state and existing actions; do not invent new payment or booking states.
  5. Complete cursor pagination in the matchmaking feed. Consume `nextCursor`/`hasMore` from `GET /api/matchmaking/lobbies`, load additional results without duplicates, and provide a clear loading/end state. Preserve current venue, sport, and date filters across page requests and reset pagination when filters change or the feed is refreshed.
  6. Add/update focused tests for the booking-choice copy, matchmaking payment/status presentation, and paginated loading/filter reset. Keep existing tests passing.
- **Acceptance Criteria**:
  - A customer can tell the difference between regular booking and matchmaking before choosing either path.
  - Host and joining-player payment responsibilities and approval steps are visible before commitment.
  - Matchmaking copy does not promise automatic pairing or imply a join request is a confirmed match.
  - Users can reach lobbies beyond the first API page, and changing filters or refreshing does not mix results from different queries.
  - Existing booking, payment, security, and matchmaking lifecycle behavior remains intact.
- **Verification**: Run focused Flutter tests for booking/matchmaking screens and API behavior, plus `cd backend && npm test test/matchmaking-routes.test.js` if the backend route changes.
**Behavior**:
- Any signed-in active user can create a public club; the creator becomes its owner and first member.
- Anyone can browse clubs and club posts. Signed-in users can join or leave for free; club owners cannot leave their own club.
- Only club members can publish posts to a club. Club posts remain separate from the general social feed and profile timelines.
- Club creation requires a JPEG, PNG, or WebP logo; every club post requires at least one JPEG, PNG, or WebP photo.
- Home > Community shows clubs directly; the global header search supports people, posts, and clubs. The profile social feed remains available.
- Club owners can update club details/logo, delete their club, and require approval for new membership requests. Pending users cannot publish club posts until approved.

**Verification**: `cd backend && node --test test/social-club-routes.test.js test/social-routes.test.js test/schema-migrations.test.js`; `flutter test test/social_community_page_test.dart test/social_clubs_api_test.dart`

---

## Phase 8: Venue Detail Page Clarity & Trust
- [x] **Task 8.1**: Improve venue detail page information hierarchy, availability accuracy, sharing, and pricing clarity (`lib/features/bookings/presentation/sports_booking_page.dart`)

### [Task 8.1] Improve Venue Detail Page Clarity & Trust
- **Inspect first**: Read the venue detail page, its venue data mapping and booking flow, the all-venues presentation, the shared pricing helper, and any existing share utilities/dependencies and focused tests. In particular inspect `lib/features/bookings/presentation/sports_booking_page.dart`, `lib/features/venues/presentation/all_venues_page.dart`, and `lib/features/bookings/domain/booking_pricing.dart`. Extend existing behavior; do not duplicate existing helpers or overwrite unrelated work.
- **Zero-regression requirements**:
  - Preserve reservation, availability refresh, booking validation and submission, reviews, saved venues, merchant contact, matchmaking, event-page variants, localization, accessibility, and responsive layouts.
  - Do not change booking totals, rate selection, extra-player calculations, payment policy, or backend behavior as part of this presentation task.
  - Keep existing app design system patterns and any established project sharing utility/dependency.
- **Target Files**:
  - `lib/features/bookings/presentation/sports_booking_page.dart`
  - `lib/features/bookings/domain/booking_pricing.dart` (read for consistency; only edit if a strictly necessary presentation helper belongs there)
  - Existing focused venue/booking tests, if present and relevant
- **Specification**:
  1. Show an “Open now” status only when the current venue data reliably represents the venue's current open/closed state. A non-empty availability string alone is not proof. If current status cannot be determined, show the supplied hours or availability text without claiming the venue is open.
  2. Remove redundant address and price presentation while retaining the address where it best supports the venue summary and the persistent bottom price/action bar. Make price units clear (for example, per hour) and ensure summary pricing does not imply a different rate from the booking flow. Do not invent a single price if rates vary by sport or time.
  3. Make the hero share action work using an existing sharing mechanism and a useful venue link/details payload. If the project has no suitable share mechanism, remove or render the action as non-interactive rather than leaving an empty callback.
  4. Remove unsupported fixed claims such as “Verified venue manager” and “Fast responding.” Display such claims only if the app already supplies reliable verification/response data; otherwise use neutral merchant-contact wording.
  5. Improve scanning order and spacing so customers can quickly understand venue identity, rating, location/hours, pricing, and the primary Reserve action. Keep amenities and secondary information accessible without removing useful venue content.
  6. Keep extra-player fee information consistent with the existing booking calculation and clearly distinguish included players from the extra-player fee.
  7. Preserve accessibility semantics and localization conventions for changed controls and copy. Avoid introducing new dependencies unless an established project pattern cannot meet the share requirement.
- **Acceptance Criteria**:
  - The page never labels a venue “Open now” solely because an availability string is non-empty.
  - Venue address and price are not needlessly repeated, and any displayed rate includes enough context to avoid confusing it with a different booking rate.
  - The share control has a working action or is not presented as an active control.
  - Merchant verification/response claims are backed by existing data or replaced with neutral wording.
  - Regular booking and matchmaking behavior, calculations, event variants, and existing venue actions continue to work.
  - Focused tests are added or updated for any changed conditional status/share behavior where practical; existing relevant tests pass.
- **Verification**: Run focused Flutter tests for the changed venue detail behavior and analyze the modified Dart files. Report any share limitation if no suitable project dependency or utility exists.

---

## Phase 9: Automatic Match Publishing & Nearby Notifications
- [x] **Task 9.1**: Automatically show all published matches in Home > Find Match and notify users about new matches near them (`lib/features/app_shell/presentation/customer_home_page.dart`, `lib/features/bookings/presentation/matchmaking_lobby_list_page.dart`)

### [Task 9.1] Automatically Publish Matches to Home & Notify Nearby Users
- **Inspect first**: Read `lib/features/app_shell/presentation/customer_home_page.dart`, `lib/features/app_shell/presentation/customer_navigation_shell.dart`, `lib/features/bookings/presentation/matchmaking_lobby_list_page.dart`, `lib/features/bookings/data/matchmaking_api.dart`, `backend/src/routes/matchmaking_routes.js`, the existing push/in-app notification implementation, and relevant matchmaking/Home tests. Inspect the current lobby status lifecycle and location sources before editing. Extend the existing matchmaking publication and notification flows; do not create a parallel match feed or duplicate notification system.
- **Product intent**:
  - Home > Find Match is for discovering and browsing all currently published matches. It is not the match-creation flow.
  - A match that reaches the existing published/open state should automatically appear as a match card in this feed without a user manually reposting it.
  - When a new match is published, notify every user in the existing eligible notification audience. Use each user's available location to identify or prioritize the nearest venue/match and include distance only when it can be calculated reliably. Follow existing notification preferences and fallback behavior when a user's location is unavailable; do not silently narrow delivery to nearby users only or fabricate distances.
- **Zero-regression requirements**:
  - Preserve existing matchmaking approval, payment, conflict-checking, host/join request, and lobby lifecycle rules. Only matches already eligible for public discovery should appear as published feed content.
  - Keep match creation/hosting in its existing separate flow. Do not turn the Home Find Match tab into a create-match form or label its primary purpose as creating a match.
  - Preserve Latest, Following, Community, and Find Match navigation, bottom navigation, search, existing notification preferences/channels, authentication, and accessible loading/error/empty/retry states.
  - Reuse existing location and push/in-app notification services. Do not add a new dependency or broadcast duplicate notifications on refresh, repeated API fetches, or retries.
- **Target Files**:
  - `lib/features/app_shell/presentation/customer_home_page.dart`
  - `lib/features/bookings/presentation/matchmaking_lobby_list_page.dart`
  - `lib/features/bookings/data/matchmaking_api.dart`
  - `backend/src/routes/matchmaking_routes.js`
  - Existing push/in-app notification files and focused matchmaking/Home tests (identify exact files before editing)
- **Specification**:
  1. Make Home > Find Match a discovery feed of all active, publicly available matches returned by the existing matchmaking API. Newly published matches must flow into it automatically; users should not need to create a social post for a match to appear.
  2. Keep each match represented with accurate venue, sport, date/time, price/share, host, and join-request state using existing API data and lifecycle rules. Sort or prioritize nearby matches when user location is available, without hiding the rest of the active published matches.
  3. On transition into the existing public/open state, trigger the existing notification mechanism for every user in its eligible audience about the newly available match. Where location data is available, identify/prioritize how near the venue is for each user; include distance only when reliable. Include clear venue/match details and follow existing preferences and delivery channels. Ensure a lobby produces only the intended notification(s), including across retries or duplicate state updates.
  4. Keep Find Match focused on browsing and joining published matches. Any host/create-match action must remain a clearly separate existing route and must not replace or obscure the list of matches.
  5. Refresh and tab revisit should update the match list from the API without creating new posts or duplicate notifications. Provide clear loading, no-matches, error, retry, and refresh feedback.
  6. If the current backend does not have a reliable way to target nearby users or deduplicate publication notifications, inspect existing user location and notification models first, then implement the smallest compatible extension and document any product-relevant limitation rather than inventing a new lifecycle state.
- **Acceptance Criteria**:
  - Every active match in the existing public/open state is discoverable from Home > Find Match, including matches published after Home was first opened once the feed refreshes or reloads.
  - A newly published match appears automatically as a match card; manual social reposting is not required.
  - Every user in the existing eligible notification audience receives the configured notification for a newly published match; proximity is personalized or prioritized when reliable user location is available.
  - Duplicate requests, refreshes, retries, and repeated publication updates do not send duplicate notifications for the same match event.
  - The Home Find Match tab remains a match discovery/listing destination, while match creation stays in its separate flow.
  - Existing booking, matchmaking, notification, and Home navigation behavior remains intact; focused tests cover publication, nearby notification targeting/deduplication, and feed rendering.
- **Verification**: Run focused Flutter Home/matchmaking tests and backend matchmaking/notification tests, then analyze modified Dart files. Summarize how the audience for nearby notifications is determined and any limitation when location is unavailable.
- **Implementation note**: Public-match alerts have a separate opt-in from booking transaction alerts. Customer coordinates are not persisted, so opted-in users receive location-neutral match details; the feed uses device location for local nearby-first ordering when available.

---

## Phase 10: Booking Flow Clarity & Booking History
- [x] **Task 10.1**: Improve reservation time selection, price/payment clarity, and booking history labels (`lib/features/bookings/presentation/sports_booking_page.dart`, `lib/features/bookings/presentation/customer_bookings_page.dart`)

### [Task 10.1] Improve Customer Booking Flow & Bookings Tab Clarity
- **Inspect first**: Read the reservation modal and submission/confirmation flow in `lib/features/bookings/presentation/sports_booking_page.dart`, `lib/features/bookings/presentation/customer_bookings_page.dart`, the booking schedule/availability repository and controller, the booking domain/pricing helpers, and relevant focused tests. Inspect how venue hours, available times, prices, payment choices, and booking statuses are represented before changing UI. Extend existing behavior; do not duplicate availability or pricing logic.
- **Zero-regression requirements**:
  - Preserve the availability refresh and submit-time recheck, schedule-conflict checks, idempotency key, booking validation, approval/payment deadlines, booking totals, payment policy, cancellation rules, and server-side enforcement.
  - Do not show a time as available unless the existing availability/conflict data supports it. If discrete time options cannot be produced reliably from existing data, improve the current time selection and availability guidance without inventing availability.
  - Preserve booking search, payment filters, status notifications, refresh, details, cancellation, payment, review, and matchmaking entry points.
  - Retain app design-system, localization, accessibility, and responsive-layout conventions.
- **Target Files**:
  - `lib/features/bookings/presentation/sports_booking_page.dart`
  - `lib/features/bookings/presentation/customer_bookings_page.dart`
  - Existing booking schedule/pricing helpers (inspect first; edit only when necessary)
  - Relevant existing booking widget/domain tests
- **Specification**:
  1. Make choosing a date and time easier by showing valid bookable start times for the selected date, duration, sport, and venue hours when existing data permits. Clearly indicate unavailable choices. If reliable discrete options are not supported, retain the time picker and make the relationship between the chosen time, venue hours, and slot availability clearer.
  2. Show the selected sport rate with its unit (for example, `₱X per hour`) wherever it appears. Make the total breakdown easy to understand: rate, duration, number of slots, extra-player charges, total, and amount due after venue approval.
  3. Make the cash-on-arrival choice state directly that its 50% downpayment is due at the venue after approval. Keep online payment timing clear and consistent with the existing approval/deadline flow. Do not change payment calculations or policy.
  4. Reduce the reservation modal's perceived length through clearer grouping or progressive disclosure while keeping availability status, final total, payment timing, cancellation information, and the booking request action easy to find.
  5. Give the help icon in the reservation modal a useful existing help action. If no help content or destination exists, remove/disable the control instead of retaining an empty callback.
  6. The Bookings tab currently groups `finished`, `done`, `completed`, `expired`, and `cancelled` statuses under “Completed.” Use a label that accurately covers historical bookings (such as “History”) or otherwise separate these states clearly. Continue to show the actual status on each booking card and preserve existing filters and actions.
- **Acceptance Criteria**:
  - Customers can identify valid times and understand why a chosen slot is unavailable; the UI never guarantees availability without reliable data.
  - Selected sport pricing is consistently labeled per hour, and the displayed total/due amount agrees with the existing calculation and approval/payment policy.
  - Cash downpayment timing is clear before submission; online payment timing remains accurate.
  - Customers can scan the booking form by section and still find the total, policy, and request action without hunting through repeated or ambiguous information.
  - No visible help control has an empty/no-op callback.
  - Cancelled and expired bookings are not presented as completed without clear history/status context.
  - Existing conflict, booking, payment, cancellation, and Bookings-tab behavior remains intact; focused tests cover changed time/pricing/payment copy and history labeling.
- **Verification**: Run focused Flutter booking-flow and customer-bookings tests, then analyze modified Dart files. Report any time-slot presentation limitation caused by missing or insufficient schedule data.
- **Implementation note**: Venue hours are freeform and availability data lists booked slots by date rather than reliable start-time options. The existing time picker remains; displayed availability reflects the selected date, time, duration, and slots, with submit-time rechecking preserved.

---

## Phase 11: Customer Settings Organization & Notification Clarity
- [x] **Task 11.1**: Organize customer settings, clarify notification controls, and improve unfinished/support states (`lib/features/profile/presentation/profile_dashboard.dart`, `lib/features/settings/presentation/app_settings_page.dart`)

### [Task 11.1] Improve Customer Settings Clarity & Usability
- **Inspect first**: Read `lib/features/profile/presentation/profile_dashboard.dart` (settings drawer and notification actions), `lib/features/settings/presentation/app_settings_page.dart`, `lib/features/notifications/presentation/notification_settings_page.dart`, `lib/features/notifications/presentation/booking_transaction_notification_settings.dart`, the match-notification implementation, `lib/core/app_preferences.dart`, and relevant settings/profile/notification tests. Confirm what each notification control actually enables and how preferences are stored before changing labels or navigation. Extend existing settings and persistence; do not create duplicate preference stores.
- **Zero-regression requirements**:
  - Preserve per-account appearance preference storage, dark mode, theme palette/custom accent, text scaling, language selection, notification registration and permissions, booking alerts, match/booking reminders, account/profile actions, and logout behavior.
  - Do not claim or expose a notification feature unless its backend/device behavior exists. Keep notification settings consistent with current delivery behavior and platform permissions.
  - Preserve guest/account-specific access rules and use existing localization, design-system, accessibility, and responsive-layout patterns.
- **Target Files**:
  - `lib/features/profile/presentation/profile_dashboard.dart`
  - `lib/features/settings/presentation/app_settings_page.dart`
  - `lib/features/notifications/presentation/notification_settings_page.dart`
  - `lib/features/notifications/presentation/booking_transaction_notification_settings.dart`
  - `lib/core/app_preferences.dart` (inspect; change only if needed to preserve current persistence semantics)
  - Relevant existing profile, preference, and notification tests
- **Specification**:
  1. Make settings easier to navigate by grouping related controls consistently. Reduce unnecessary hops between the profile Settings menu, Appearance & language, and Notification settings, while keeping the existing destinations and account actions reachable.
  2. Clarify notification controls with labels and short descriptions that match their actual effects. In particular, distinguish booking transaction push alerts from match start/end reminders. Do not label either as nearby/new-match alerts unless that behavior has actually been implemented; if nearby-match notifications are implemented separately, give them a distinct preference and explain the audience/location behavior accurately.
  3. Replace the current “coming soon” Help Center and Court Rules responses with existing useful content/routes if available. If there is no working destination, remove or clearly disable those actions instead of presenting them as complete features.
  4. Make theme palette choices identifiable without relying on color perception alone by providing visible names or equivalent text labels, while retaining the selected state and accessible semantics. Ensure custom accent colors preserve readable foreground contrast, or constrain/recommend colors so essential controls remain legible.
  5. Replace raw exception details in customer-facing save errors with plain-language, actionable messages. Keep useful diagnostic detail in an appropriate developer log if an established logging pattern exists. Preserve preference rollback when persistence fails.
  6. Keep text size and language choices understandable and ensure the settings UI itself remains usable at larger text scales and on narrow screens.
- **Acceptance Criteria**:
  - Customers can find appearance, notification, account, and support settings through a predictable structure without losing existing actions or guest restrictions.
  - Each notification preference clearly states what notifications it controls, and labels do not promise nearby-match notifications unless they are implemented.
  - Help and Court Rules either open useful working destinations or are not shown as active controls.
  - Color choices have non-color identification and remain readable when applied.
  - Save failures use customer-friendly messages and do not leave unsaved preference changes appearing successful.
  - Existing account-scoped preferences, notification permissions/registration, and profile actions remain intact; focused tests cover navigation, notification labels/access behavior, and preference save failure where practical.
- **Verification**: Run focused Flutter tests for settings, profile settings navigation, notification preferences, and app preference persistence, then analyze modified Dart files. Summarize any notification feature that lacks an implemented control or backend behavior.

---

## Phase 12: Codebase Maintainability & Deployment Readiness
- [x] **Task 12.1**: Incrementally split oversized Flutter presentation files without changing behavior
- [x] **Task 12.2**: Align the For You feed label with its actual chronological ordering
- [x] **Task 12.3**: Define and implement shared coordination before running multiple API instances

### [Task 12.1] Incrementally Refactor Oversized Flutter Screens
- **Inspect first**: Review the largest Flutter presentation files and their existing widget tests. Start with `lib/features/bookings/presentation/sports_booking_page.dart`, `lib/features/profile/presentation/profile_dashboard.dart`, `lib/features/merchant_management/presentation/merchant_add_business_form.dart`, and `lib/features/merchant_management/presentation/merchant_dashboard.dart`. Confirm existing extracted modules and current uncommitted work before editing. Choose one cohesive, low-risk section first; do not attempt a wholesale rewrite of every large file in one change.
- **Zero-regression requirements**:
  - Preserve user-visible behavior, navigation, data flow, error/loading states, permissions, and API contracts.
  - Use constructor parameters or injected collaborators for dependencies; do not introduce Dart `part`/`part of` coupling.
  - Keep state ownership explicit and avoid duplicating controllers, business rules, or calculations in extracted widgets.
- **Specification**:
  1. Extract one cohesive UI section or interaction flow into a focused widget/controller with a clear responsibility and existing design-system conventions.
  2. Keep the parent screen responsible for orchestration and pass only the state/actions the extracted component needs.
  3. Add or update focused tests for the extracted behavior and preserve current screen-level tests.
  4. Record the extraction boundary and remaining safe candidates in the task completion summary; do not continue broad refactors without a focused next task.
- **Acceptance Criteria**:
  - At least one selected screen has a cohesive section extracted into a separately testable component.
  - The extraction reduces coupling or file responsibility without changing the flow's behavior.
  - Focused tests pass and no unrelated files or UI behaviors are changed.
- **Verification**: Run focused tests for the selected screen/component and analyze the changed Dart files.
- **Implementation note**: Extracted the booking price/schedule breakdown into `SportsBookingPriceSummary`; the parent retains booking-total/downpayment calculations, payment selection, and submission. Potential follow-up candidates are separating the co-located sports venue-detail/dashboard pages and extracting profile-history or merchant-form sections after reviewing their focused tests. No other large screens were refactored in this task.

### [Task 12.2] Make Feed Ordering Clear to Customers
- **Inspect first**: Read the Home feed implementation in `lib/features/app_shell/presentation/customer_home_page.dart`, the social feed API/repository, backend feed query and ordering, and relevant Home/feed tests. Confirm actual ranking and pagination behavior before changing the label.
- **Specification**:
  1. The current For You feed is described as newest-first. Either rename its visible label and related accessibility/test strings to a chronological label such as “Latest,” or implement a real, explainable personalized ranking if the existing backend already has the required data and ranking can be tested.
  2. Do not imply personalization, popularity, or recommendations unless the ordering actually provides it.
  3. Keep Following, Community, and Find Match labels and behavior unchanged.
- **Acceptance Criteria**:
  - The visible feed label accurately describes its order and ranking.
  - Any changed localization/accessibility strings and tests agree with the chosen behavior.
- **Verification**: Run focused social feed and Home navigation tests; analyze modified Dart files.

### [Task 12.3] Prepare Backend Coordination for Multi-Instance Deployment
- **Inspect first**: Read `backend/src/rate_limit.js`, `backend/src/read_cache.js`, `backend/src/server.js` scheduled processors, `backend/src/websocket_hub.js`, deployment documentation, and existing tests. The current rate limiter and catalog cache are process-local; establish which scheduled jobs and live updates already have cross-instance safety before proposing changes.
- **Zero-regression requirements**:
  - Preserve current authentication, rate-limit policy, booking/payment deadlines, transactional locks, notification deduplication, and API response behavior.
  - Keep single-instance local development usable without requiring a new service unless explicitly configured for multi-instance mode.
  - Do not claim multi-instance safety for process-local caches, limits, timers, or WebSocket connections.
- **Specification**:
  1. Document each process-local runtime responsibility (rate limits, read cache, scheduled deadline processing, WebSocket delivery) and its failure/consistency behavior across multiple instances.
  2. For responsibilities that need shared coordination, use an existing supported infrastructure service if present. Otherwise define the smallest deployable shared-store/lock interface, configuration, migrations or setup, and failure behavior before adding a dependency or changing production defaults.
  3. Ensure deadline processors cannot double-apply state transitions and that notification delivery is safe under retries and multiple workers.
  4. Add focused multi-instance/coordination tests where the chosen implementation can be exercised deterministically, and update deployment documentation with required configuration and rollout steps.
- **Acceptance Criteria**:
  - Operators can tell which runtime features are single-instance only and what must be configured before horizontal scaling.
  - Shared rate limiting/cache/job coordination is implemented only where required by the selected deployment design, with clear failure behavior.
  - Concurrent workers cannot duplicate booking/payment deadline transitions or notifications.
  - Existing single-instance development and booking/security behavior remain intact.
- **Verification**: Run focused backend tests for modified coordination modules and lifecycle processors; run backend integration tests if database locking or schema changes are involved. Update backend deployment documentation.

---

## Phase 13: Profile Loading States & Section Navigation
- [x] **Task 13.1**: Make profile loading and failures clear, and improve section navigation usability

### [Task 13.1] Make Profile Loading and Navigation Clear
- **Inspect first**: Review `lib/features/profile/presentation/profile_dashboard.dart`, the profile/session provider and repositories it uses, embedded profile-section widgets, and relevant profile tests. Check the current behavior for signed-in users, guests, and each supported business type before editing.
- **Observed problems to address**: The page can briefly render guest, generic, or empty profile information while account and booking requests are still pending; a failed request should not look like a successful empty profile. The profile section navigation also has several cramped labels at phone widths.
- **Zero-regression requirements**:
  - Preserve guest access, account/business variants, social profile content, notifications, booking history, settings, navigation destinations, refresh behavior, and account actions.
  - Do not show “no bookings” or guest defaults as the result of an unresolved or failed signed-in request.
  - Keep the change focused; avoid rewriting the oversized dashboard or changing backend/API contracts.
- **Specification**:
  1. Represent initial profile/account and booking loading explicitly. Show an appropriate loading treatment until the data needed for the visible profile state has resolved.
  2. On initial load failure, show a clear, recoverable error with a retry action. On refresh failure, keep valid previously loaded content visible and communicate the failure without replacing it with misleading defaults.
  3. Make the profile section navigation understandable and usable on narrow screens and with larger text. Use full, clear labels and an accessible layout such as horizontally scrollable tabs or another compact grouping while preserving each section’s destination and behavior.
  4. Prevent overlapping or stale requests from overwriting newer profile state; follow existing state-management patterns and add focused coverage for the resulting states.
- **Acceptance Criteria**:
  - A signed-in user never sees guest/generic defaults or an empty-bookings message presented as final content while the relevant request is pending or has failed.
  - Loading, initial error/retry, successful empty state, and refresh failure are distinguishable and behave consistently.
  - All existing profile sections remain reachable with clear labels at phone widths and remain usable with larger text/accessibility semantics.
  - Guest and supported business-type profile flows, navigation, refresh, and account actions continue to work.
- **Verification**: Run focused profile dashboard/session tests and analyze the modified Dart files. Summarize any untested profile variant or loading path.
- **Implementation note**: The profile now waits for session, account, and booking data before showing guest/account details; initial failures have an inline retry, and refresh failures keep existing content with retry feedback. Load generations prevent stale responses from replacing newer data. Section navigation uses horizontally scrollable, accessible full labels for Sports, Fitness, and Event profiles. Focused tests cover these states and variants.

---

## Phase 14: Merchant Dashboard Reliability & Action Clarity
- [x] **Task 14.1**: Make merchant dashboard data states reliable and help merchants prioritize actions

### [Task 14.1] Improve Merchant Dashboard Loading, Errors, and Priorities
- **Inspect first**: Review `lib/features/merchant_management/presentation/merchant_dashboard.dart`, its analytics and booking-management parts, `merchant_dashboard_business_cards.dart`, `merchant_navigation_drawer.dart`, the relevant session/data repositories, and merchant dashboard tests. Confirm the current behavior for first-time merchants, merchants with multiple business types, and returning merchants before editing.
- **Honest review findings**: The dashboard already has a loading skeleton, pull-to-refresh, first-business onboarding, and booking live updates with a polling fallback. However, initial profile, business, booking, and matchmaking requests are chained; several loaders catch errors internally and let the overall page leave loading with empty collections. This can make a network failure look like a real zero-data state, while transient error snackbars are easy to miss. The dashboard contains a large set of metrics and controls, so the most urgent work for a merchant can be difficult to identify at a glance.
- **Zero-regression requirements**:
  - Preserve booking approval/payment and check-in behavior, matchmaking handling, live-update and polling lifecycle, filters, business publishing/onboarding, navigation, and profile/settings actions.
  - Do not present unavailable or failed data as a successful zero count, empty business list, or first-time onboarding state.
  - Keep existing single-instance behavior and API contracts; do not add new dependencies or redesign the dashboard wholesale.
- **Specification**:
  1. Give profile, businesses, bookings, and matchmaking data explicit loading/success/error states where they are shown. Decide which requests can run concurrently without changing dependencies or behavior, and avoid making independent slow requests delay the initial dashboard unnecessarily.
  2. Provide an actionable retry for initial load failures. On refresh failure, retain the last successful content and show clear, recoverable feedback. Keep genuine successful empty states distinct from request failures.
  3. Make dashboard data freshness and unavailable sections apparent, and ensure partial failures do not suppress successful data from other sections.
  4. Review the dashboard’s above-the-fold hierarchy and surface the most time-sensitive merchant actions (such as pending bookings, payment follow-up, or unpublished business setup) with clear navigation into the existing flows. Avoid duplicating counts or adding notifications that are not supported by existing data.
  5. Keep the UI usable on narrow screens and larger text, following the existing design system. Extract a small cohesive component only if it makes the state or action hierarchy easier to maintain.
- **Acceptance Criteria**:
  - A failed initial request cannot be mistaken for a successfully loaded empty result or first-time setup state.
  - Each affected section communicates loading, successful empty/data, and error/retry states; retry and refresh preserve valid data and do not create overlapping or stale results.
  - Successful sections remain useful when another independent section fails.
  - Merchants can quickly identify and open the most urgent existing work without losing access to current dashboard sections or controls.
  - First-business onboarding, multiple business types, booking lifecycle actions, and live-update fallback behavior remain intact.
- **Verification**: Add or update focused merchant dashboard tests for partial initial failures, retry, refresh failure with retained content, and action navigation. Run those tests and analyze the modified Dart files; report any dashboard data path that still lacks coverage.
- **Implementation note**: Profile loading now gates the dashboard with a retryable error state, then loads businesses, bookings, and matchmaking concurrently with independent loading/error states. Initial failures no longer appear as empty data or onboarding, refresh failures retain the last successful data, and retries/refreshes coalesce in-flight reads while mutation follow-ups reload after active reads. The dashboard prioritizes pending approvals, cash downpayments to record, and businesses awaiting publication with links to their existing flows. Focused tests cover partial failures, retry, retained data, matchmaking recovery, action navigation, and existing booking/live-update behavior.

---

## Phase 15: Merchant Business Setup & Publishing Clarity
- [x] **Task 15.1**: Clarify the merchant add-business workflow and make news-card loading recoverable

### [Task 15.1] Improve Merchant Add-Page Setup and Publishing
- **Inspect first**: Review `lib/features/merchant_management/presentation/merchant_add_page.dart`, `merchant_add_business_form.dart`, `merchant_add_business_list.dart`, `merchant_add_news_management.dart`, related fitness form sections, the merchant API/session methods, and all `merchant_add_*` tests. Trace how business details, booking-card readiness, news-card drafts/publication, and filtering relate before changing the flow.
- **Honest review findings**: The page supports a capable Sports, Event, and Fitness setup, search/edit, and a pre-publish review. The business form is a long, conditional panel with many fields, which makes progress and validation guidance difficult to follow on a phone. Booking-card visibility depends on a complete published News Card (title, body, and image), but that dependency can be unclear to merchants. News-post loading also has no in-flight/stale-response guard, and session token lookup is outside the loader's error handler; failures can leave the page looking empty or give no in-page retry.
- **Zero-regression requirements**:
  - Preserve existing business and news-card API payloads, publishing rules, draft/edit/delete behavior, type-specific fields and validation, booking-card visibility, location/photo handling, and merchant dashboard navigation.
  - Do not weaken required business or news-card fields, silently publish drafts, or alter backend contracts to simplify the UI.
  - Keep the change focused. Prefer clearer sections/progress and a cohesive loader improvement over a wholesale rewrite of the multi-type form.
- **Specification**:
  1. Make the merchant publishing lifecycle clear in the interface: explain the relationship between business setup, a published News Card, and customer-visible Booking Card availability. Clearly distinguish incomplete, draft, published, and ready states wherever they are surfaced.
  2. Improve long-form setup navigation and validation feedback for phone widths and larger text. Use grouped sections or a step/progress pattern if it helps merchants understand what remains; preserve the existing review and guide users to the first invalid or incomplete field.
  3. Give News Cards an explicit loading, success/empty, and error/retry state. Catch session/token lookup failures as well as API errors, preserve last successful content on refresh failure, and prevent overlapping or stale requests from replacing newer results.
  4. Ensure business list filtering/search communicates when businesses are absent versus when none match a filter or are not yet eligible for a Booking Card. Keep each business discoverable in the appropriate setup state.
  5. Add focused coverage for lifecycle explanations/states, retry and request races, required-field guidance, and phone/large-text layouts across Sports, Event, and Fitness flows.
- **Acceptance Criteria**:
  - Merchants can tell what remains before customers can see a Booking Card and why an item is incomplete or unavailable.
  - The form makes progress and validation errors easy to find without losing type-specific data or the existing final review.
  - News-post loading/session/API failures are recoverable in context; refresh preserves valid data and older requests cannot overwrite newer results.
  - Empty lists, filter no-results, unpublished/incomplete states, and request failures are visibly distinct.
  - Existing create/edit/publish behavior, API payloads, and all three business-type setup flows remain intact.
- **Verification**: `flutter test test\merchant_add_task15_test.dart test\merchant_add_wizard_test.dart test\merchant_add_publish_test.dart test\merchant_add_form_layout_test.dart test\merchant_add_multi_sport_test.dart test\merchant_add_fitness_test.dart` and targeted `flutter analyze --no-pub` passed.
- **Implementation note**: Added a visible business → published News Card → customer-visible Booking Card explanation, distinct empty/filter/not-ready states, and recoverable News Card loading with session/API error handling, retry, retained data after refresh failure, and coalesced reads. The business form now has section jump shortcuts, manual validation scroll targets, and a review readiness check that includes type-specific required details. Focused tests cover session/API retry, stale-data retention, in-flight load coalescing, filter states, missing-field guidance, and 360 px / larger-text Sports, Event, and Fitness layouts. All three layout paths are covered; the full matrix of type-specific publish-field combinations was not exhaustively re-tested.

---

## Phase 16: Merchant Booking Workflow Clarity
- [x] **Task 16.1**: Make booking navigation, request actions, and filtered empty states easier to understand

### [Task 16.1] Improve Merchant Booking Management Usability
- **Inspect first**: Review `lib/features/merchant_management/presentation/merchant_dashboard.dart`, `merchant_dashboard_booking_management.dart`, `merchant_dashboard_payment_management.dart`, fitness membership management, booking repository/status handling, and `test/merchant_analytics_dashboard_test.dart`. Confirm all status transitions and which data is available for status counts before changing the UI.
- **Honest review findings**: The page already covers requests, active/completed bookings, arrivals/no-shows, payments, earnings/refunds, type/search filters, refresh, and booking data retry. Its three top-level sections each expose another tab group, and the Customer section changes to fitness membership management for Fitness businesses. Booking cards put approve/decline inside a details view. Empty-state copy can say there are no bookings even when active filters produced no matches.
- **Zero-regression requirements**:
  - Preserve booking status semantics and deadlines, matchmaking booking behavior, approval/decline confirmation, check-in and no-show handling, fitness membership flows, payment/refund states, and API behavior.
  - Counts and action priorities must derive from the currently loaded data and correctly respect booking type/status; never invent totals or imply a server-side result that was not loaded.
  - Keep the existing workflows accessible; do not remove confirmation from consequential booking or payment actions.
- **Specification**:
  1. Clarify the booking-management hierarchy and section names so merchants can tell where requests, arrivals, fitness memberships, and payment work live. Keep labels and semantics consistent when the selected business type changes.
  2. Show accurate counts or badges for Requests, Active, and Completed where useful, including accessibility labels. Define precisely which statuses belong in each count and update counts when filters apply.
  3. Make the next step for pending requests easier to spot on the card and avoid requiring merchants to search through a long details view to find its decision controls. Retain a clear review step and approval/decline confirmation.
  4. Distinguish genuinely empty status lists from no results caused by the current search or business-type filter. Offer a clear way to reset active filters without losing the selected workflow.
  5. Check narrow-screen and larger-text layouts for nested tabs, booking cards, and payment actions; make any compact layout preserve readable status, customer, schedule, and amount information.
- **Acceptance Criteria**:
  - Merchants can predict where each booking/customer/payment workflow is located, including for Fitness & Wellness businesses.
  - Status counts match the rendered booking set and follow the same type/search filters as the list.
  - Pending requests expose a clear path to review and act, and approvals/declines still use the existing confirmation and domain rules.
  - Empty data and filter no-results use distinct explanations and provide an obvious filter reset when applicable.
  - Existing booking lifecycle, payment/refund, check-in/no-show, and fitness membership behaviors remain unchanged.
- **Implemented**: Added workflow headings, filter-aware empty states and resets, filtered Requests/Active/Completed counts, and card-level pending actions that preserve review, confirmation, and existing domain rules. Made the bookings title and payment-card header responsive at narrow widths.
- **Verification**: `flutter test test/merchant_booking_management_usability_test.dart test/merchant_analytics_dashboard_test.dart test/merchant_dashboard_navigation_test.dart` and focused `flutter analyze` passed. Coverage includes 360px width at 1.25x text scaling.

---

## Phase 17: Merchant Profile Content & Metric Accuracy
- [x] **Task 17.1**: Make merchant profile content accurate, business-focused, and action-oriented

### [Task 17.1] Improve Merchant Profile Content and Performance Labels
- **Inspect first**: Review `lib/features/merchant_management/presentation/merchant_profile_dashboard.dart`, `merchant_profile_performance_card.dart`, `merchant_profile_performance.dart`, merchant business API fields (including `hasPublishedNewsCard`, `averageRating`, and `reviewCount`), and profile/performance tests. Confirm the meaning and availability of every field shown before presenting it as a status or metric.
- **Honest review findings**: The existing profile mixes account details, operational metrics, and shortcuts that duplicate the main dashboard. It labels every account �Verified Host� without checking a verification field, treats weekday availability as an open/closed venue status, calculates a completion score from an arbitrary checklist, and labels confirmed booking totals as revenue. Some shortcut labels also promise pricing or promotions while linking to the general venue-management section.
- **Zero-regression requirements**:
  - Preserve merchant profile editing, image updates, navigation, settings, booking/payment routes, review display, and refresh behavior.
  - Use only data the merchant profile/business/booking APIs actually provide. Do not claim verification, listing visibility, withdrawable balance, or business health without supporting fields.
  - Keep booking totals distinct from payments received; avoid implying that recorded payments are a withdrawable balance.
- **Specification**:
  1. Present the profile as an account and business workspace: separate account-owner/contact details from venue/listing status, provide a clear edit-account action, and use shortcut labels that match their destinations.
  2. Remove unsupported verification claims and arbitrary completion percentages. Replace availability-derived open/closed claims with precise venue and published-News-Card counts using the existing API field; explain the customer-visibility relationship without implying that every business type has identical publication rules.
  3. If an aggregate venue rating is shown, weight venue averages by review counts and show the review total. Do not show a rating without supporting reviews.
  4. Clarify performance periods and separate selected-period booking value from today�s operational counts. Label recorded payments as payments, not revenue or a payout balance, and explain the distinction where needed.
  5. Keep the existing design system and make account details, business status, metrics, and shortcuts readable at phone widths and larger text sizes.
- **Acceptance Criteria**:
  - No unsupported �Verified Host� or arbitrary profile-completion claim is shown.
  - Venue listing/news-card status accurately reflects the API data; weekly availability is not presented as current open status.
  - Aggregate rating is correctly review-weighted and accompanied by its review count, or omitted when no review data exists.
  - Selected-period booking value, today�s operational metrics, and recorded payments are clearly distinguished.
  - Profile editing and all existing navigation destinations continue to work, and shortcut text accurately describes each destination.
- **Implemented**: Separated account details from the business overview, prioritized venue/listing status, used unfiltered account venue totals, and retained API-backed News Card status. Rating summaries are review-weighted and omitted when supporting rating data is incomplete. Performance distinguishes selected-period confirmed booking value, today's operations, and recorded payments.
- **Verification**: Focused `flutter test` passed for profile, performance, and dashboard navigation tests; focused `flutter analyze` passed. Tests cover weighted/missing ratings, listing fields, period and payment labels, and 360px layout at 1.5x text scaling.

---

## Phase 18: Whole-Project Product & Production Readiness
- [x] **Task 18.1**: Audit SpotGo end to end and produce a prioritized product, UX, reliability, and launch-readiness plan

### [Task 18.1] Complete the Whole-Project Readiness Review
- **Inspect first**: Read the root and backend READMEs, app navigation and customer/merchant entry flows, core booking and matchmaking journeys, payment routes and UI, notification delivery, social/media storage, database schema/migrations, backend runtime topology, CI workflows, and representative tests. Review the current git status/diff before drawing conclusions; this workspace may contain unrelated in-progress changes. Do not discard or overwrite existing work.
- **Review findings to investigate and carry into the plan**:
  - SpotGo has meaningful breadth (sports, event and fitness listings/bookings, merchant tools, social/community, messaging, and match discovery), but the primary customer journey and relationship between venue discovery, booking, and match discovery need to be immediately clear.
  - The customer Home is a social feed while venue booking is a separate destination. Validate that first-time customers can find venues, discover nearby matches, understand match notifications, and return to booking without confusing content feeds with the marketplace.
  - The app's prototype payment experience does not process real charges, even though PayMongo backend integration points exist. Clearly separate demo behavior from real payments and treat end-to-end real-money checkout, webhook truth, refunds, reconciliation, and merchant settlement as a production launch gate.
  - Booking-deadline notifications can be lost after a database commit if a process crashes or an external provider fails. Assess a durable outbox/retry approach and provider idempotency for critical email, SMS, and push events.
  - The backend documentation currently supports one API process: rate limits, caches, and WebSocket delivery are process-local. Assess realistic concurrency and database bottlenecks before recommending horizontal scaling; define the coordination work required before adding instances.
  - Several Flutter screens and backend routes remain very large. `part` files alone do not reduce coupling; identify incremental extraction boundaries that protect booking and payment behavior.
  - Review navigation, first-use guidance, empty/error states, location permission denial, localization, narrow-screen layouts, and large-text accessibility across both customer and merchant journeys.
  - Review third-party integration and deployment readiness for MySQL, Firebase/FCM/Storage, email, SMS, Tenor, and PayMongo, including secrets, migration/legacy-upload rollout, monitoring, and incident response.
- **Zero-regression requirements**:
  - Preserve all existing booking, matchmaking, merchant, social, messaging, authentication, and notification behavior while assessing it.
  - Do not enable prototype payment behavior in production, claim real settlement or guaranteed message delivery without implementation, or claim multi-instance safety for process-local state.
  - Do not perform a wholesale rewrite, change provider/backend defaults, run migrations, deploy, or remove user work as part of this audit.
  - Ground each finding in a specific code path, test, configuration, or documented limitation; label assumptions and unverified external-provider behavior.
- **Specification**:
  1. Map the primary customer and merchant journeys from sign-up/discovery through booking creation, merchant decision, payment obligation, arrival/completion, review, and support. Identify confusing handoffs and recommend one clear product hierarchy without conflating social posts, venue listings, and match discovery.
  2. Create a launch-readiness matrix that separates implemented, prototype, documented-only, and missing behavior for payments/settlement, notifications, storage migration, operations, security controls, and scaling. Identify explicit blockers before real-money launch and before multiple API instances.
  3. Review high-impact reliability and data-integrity boundaries: booking idempotency/status transitions, payment webhook truth, deadline processing, notification retries, media upload compatibility, database migrations, and recovery/observability. Recommend only the smallest next step for each risk.
  4. Assess screen/route maintainability hotspots and propose a staged extraction sequence with boundaries, regression tests, and measurable completion criteria; avoid refactoring unrelated modules.
  5. Perform a cross-role UX/accessibility review focused on first-use clarity, navigation labels, task prioritization, loading/error/empty states, location-denied behavior, phone widths, larger text, and localization consistency.
  6. Produce a concise prioritized backlog grouped into: **P0 before real payments**, **P1 before broader launch**, **P2 before horizontal scaling**, and **ongoing quality improvements**. For every item include impact, evidence/location, scope, dependencies, and an acceptance criterion. Keep this audit as a plan; create separate focused implementation tasks for workstreams too large for one safe change.
- **Acceptance Criteria**:
  - The customer and merchant journey maps identify the main task, navigation entry, key state transitions, and failure/recovery paths.
  - Payment/demo status, settlement gaps, notification delivery limits, storage migration state, and single-instance constraints are accurately classified from code and documentation.
  - Every P0/P1/P2 recommendation is evidence-based, actionable, and has a verifiable acceptance criterion; no unsupported production-readiness claim is made.
  - UX findings cover both customer and merchant flows, including location-denied, offline/error, narrow-screen, and accessibility considerations where relevant.
  - The report preserves current project work and separates large implementation areas into focused follow-up tasks rather than proposing a broad rewrite.
- **Delivered**: [PHASE_18_READINESS_REVIEW.md](PHASE_18_READINESS_REVIEW.md) contains the customer/merchant journey maps, launch-readiness matrix, evidence-based priorities, dependencies, and acceptance criteria. Separate focused follow-up tasks are listed below.
- **Verification**: Read-only review of the current status/diff, READMEs, source, configuration, CI, and representative test coverage. No tests were run. Real-device, provider-sandbox, deployment-security, load, and visual checks remain external validation items.

## Phase 19: Real-Money Payment Gates
- [ ] **Task 19.1**: Complete customer checkout with provider-confirmed PayMongo payment state (Phase 18 report P0-1)
- [ ] **Task 19.2**: Add idempotent checkout, recoverable refunds, settlement, and reconciliation (Phase 18 report P0-2)

## Phase 20: Broader-Launch Reliability and UX
- [ ] **Task 20.1**: Add a durable outbox and retry policy for critical booking notifications (Phase 18 report P1-3)
- [x] **Task 20.2**: Make venue booking and match discovery first-class customer Home actions (Phase 18 report P1-4)
- [ ] **Task 20.3**: Provide actionable support and clearly routed booking/match notifications (Phase 18 report P1-5)
- [ ] **Task 20.4**: Complete social-media storage migration with compatibility and rollback gates (Phase 18 report P1-6)
- [ ] **Task 20.5**: Establish production operations and provider configuration gates (Phase 18 report P1-7)
- [x] **Task 20.6**: Make permanently denied location permission recoverable (Phase 18 report P1-8)

## Phase 21: Horizontal-Scaling Readiness
- [ ] **Task 21.1**: Coordinate rate limits, caches, realtime updates, and deadline processing across instances (Phase 18 report P2-9)
- [ ] **Task 21.2**: Set database and service capacity from measured load (Phase 18 report P2-10)

## Phase 22: Ongoing Quality and Maintainability
- [ ] **Task 22.1**: Continue incremental screen and route extraction around tested boundaries (Phase 18 report item 11)
- [ ] **Task 22.2**: Extend journey-wide accessibility, localization, and device validation (Phase 18 report item                12)

---

## Phase 23: Booking-First Venue Card UX
- [x] **Task 23.1**: Improve venue cards so customers can compare venues and reach availability clearly

### [Task 23.1] Make Customer Venue Cards Booking-First
- **Inspect first**: Review `lib/features/app_shell/presentation/news_feed_posts.dart`, `news_feed_venue_cards.dart`, `news_feed_featured_cards.dart`, `news_feed.dart`, `lib/features/venues/presentation/all_venues_page.dart`, the sport/event/fitness booking detail entry points, and venue/feed responsive tests. Trace the cards shown in curated sections, the full venue list, and the booking flow before changing shared card behavior.
- **Current review findings**: The page has a polished visual base with venue imagery, sport/facility tags, location, price, ratings, reviews, save/heart actions, filters, and type-specific booking flows. In the supplied screenshots, the same venue is repeated between curated sections and the complete listing, the listing card does not make the next booking action obvious, and sample content shows a badminton label alongside a basketball-court photo. Hours/status labels also need to distinguish operating schedules from date-specific bookable slots.
- **Zero-regression requirements**:
  - Preserve existing sports, event, and fitness booking entry points, catalog filtering/sorting, map/location behavior, save/review/heart actions, merchant-disabled status, and navigation.
  - Use existing API-backed data only. Do not invent next-available slots or label weekly operating hours as live slot availability.
  - Do not remove a venue from the complete results list just to avoid a repeated curated recommendation; keep list completeness and section presentation distinct.
- **Specification**:
  1. Establish a consistent information hierarchy for compact and full venue cards: venue image and sport/facility, name, location/distance when available, rating with review count, price with its unit, accurate schedule/availability status, and one explicit primary action.
  2. Use a booking-oriented action label that matches the actual next screen (for example, “View venue & times” or “Check availability” when the customer still needs to choose a date/time). Provide type-appropriate language for sports, event reservations, and fitness sessions. Do not say “Book now” if the action only opens details.
  3. Show date-specific available slots only when the existing data is truly date-specific and current. Otherwise describe business hours/weekly schedule accurately and let the CTA lead to the availability flow.
  4. Reduce repeated venue cards in sparse catalogs. When there are too few unique venues to support curated rails, collapse or merge redundant rails so a customer does not see the same card repeated immediately before the complete list; retain every venue in the complete list.
  5. Keep heart/save actions available but visually secondary to booking. Make the card interaction and primary action understandable without relying on an invisible whole-card tap.
  6. Verify content consistency in fixtures and presentation: venue photos should match the displayed sport/category where possible, prices must show the correct unit, missing ratings must not appear as real scores, and result counts must use singular/plural correctly.
  7. Check phone widths, larger text, screen-reader semantics for nested card actions, and horizontal-carousel behavior when there is only one item versus multiple items.
- **Acceptance Criteria**:
  - Customers can identify the venue type, location, price basis, trust signal, and next booking step from the card without guessing.
  - Booking CTA copy accurately describes the destination for Sports, Event, and Fitness & Wellness flows.
  - Operating hours, “open today,” recurring schedules, and live bookable slots are not conflated.
  - Sparse catalogs do not repeat the same venue in adjacent curated sections and the full venue results remain complete.
  - Save/review/heart interactions, filters, unavailable states, and type-specific booking routes continue to work.
  - Venue cards remain readable and accessible at phone widths and larger text sizes.
- **Verification**: Add or update focused venue-card/feed tests for CTA destination/copy, status wording, sparse-catalog duplication, singular/plural counts, and phone/large-text layouts. Run focused venue/feed tests and analyze the modified Dart files; include Sports, Event, and Fitness coverage.

---

## Phase 24: Customer Home Feed Post Card UX
- [x] **Task 24.1**: Improve Home post image presentation and make bookable sports content identifiable

### [Task 24.1] Make Customer Home Feed Posts Clear and Sports-Relevant
- **Inspect first**: Review `lib/features/app_shell/presentation/customer_home_page.dart`, `lib/features/social/presentation/social_community_page.dart` (`SocialExperiencePostCard`), the Home feed tab/filter widgets, post and matchmaking API models, and existing social/Home feed tests. Trace how ordinary experience posts and match-related content are loaded and rendered before changing the card. Task 20.2 already establishes venue booking and match discovery as first-class Home actions; preserve it and do not duplicate that scope.
- **Current review findings**: The supplied Home screenshots show familiar post headers and interaction controls, but large media areas dominate each card. Portrait and landscape images appear within a fixed portrait frame using `BoxFit.contain`, leaving broad blank bands for landscape media and making the feed unnecessarily tall. The visible posts do not identify a sport, venue, location, or match context, so the content reads as a generic social feed rather than a sports-community feed. The horizontal Latest/Following/Community/Find Match tabs also appear clipped at the right edge in the screenshot.
- **Zero-regression requirements**:
  - Preserve post creation, captions, image galleries/fullscreen viewing, likes, comments, sharing, post moderation, profile navigation, pagination/refresh, and existing social/community behavior.
  - Preserve the `Find Match` Home tab and the existing automatic appearance of eligible match content in Home. Do not turn ordinary experience posts into matchmaking lobbies or remove the separate matchmaking discovery flow.
  - Use only metadata actually available for a post or linked match/venue. Never infer a sport, venue, location, schedule, match status, price, or availability from an image or caption.
  - Keep ordinary personal experience posts valid when no venue or match metadata is linked. Do not require every social post to contain a booking CTA.
- **Specification**:
  1. Replace the single fixed portrait media treatment with a responsive image presentation that handles portrait, square, and landscape uploads without large blank bands or severe cropping. Preserve tap-to-open fullscreen viewing and multi-image paging. Choose a bounded display height so very tall images do not overwhelm the feed; retain sufficient image detail and provide accessible semantics.
  2. For posts that have real linked sports, venue, booking, or matchmaking data, show a compact, clearly labeled context block using available fields only (for example sport, venue, area, date/time, match status, and player count). Make the relevant next action explicit and route it to the actual venue or match detail/join flow. Do not show a join/book CTA for an ordinary post or a closed/unavailable match.
  3. Visually distinguish linked match/venue posts from ordinary experience posts without making the whole feed look promotional. Keep author, timestamp, caption, and social actions readable and secondary to the media/context hierarchy.
  4. Improve the horizontal Home tab row so all destinations, especially `Find Match`, are discoverable on supported phone widths. Support horizontal scrolling without clipped labels, provide clear selected-state semantics, and avoid shrinking labels below readable sizes.
  5. Check card spacing and content density on narrow phones and larger text sizes. Keep existing localization conventions and screen-reader labels; make nested action targets independently operable.
- **Acceptance Criteria**:
  - Portrait, square, and landscape post images display without the excessive blank side/top/bottom areas shown in the supplied screenshots, while retaining a deliberate consistent card treatment and fullscreen gallery behavior.
  - Linked sports/venue/match posts display accurate available context and the correct detail/action destination; missing metadata is omitted rather than fabricated.
  - Ordinary experience posts continue to render without booking or matchmaking fields and retain caption, profile, likes, comments, sharing, and moderation behavior.
  - Match content remains distinct from ordinary social posts, and Home's `Find Match` destination and existing match-discovery behavior remain available.
  - All four Home tabs can be reached and understood on narrow phone widths and at larger text sizes, with accessible selected state and independently operable actions.
- **Verification**: Add or update focused widget tests for portrait/square/landscape media, linked and unlinked post context, correct action routing/availability, gallery and social interactions, and narrow-width/large-text tab discoverability. Run the focused Home/social tests and analyze modified Dart files; do not run the full suite unless focused failures require broader diagnosis.

---

## Phase 25: Customer Venue Discovery and Trust Signals
- [x] **Task 25.1**: Make popular, top-rated, most-visited, and nearby venues obvious to customers

### [Task 25.1] Add Visible Venue Rankings and Automatic Nearby Discovery
- **Inspect first**: Review `lib/features/app_shell/presentation/news_feed.dart`, `news_feed_venue_cards.dart`, `news_feed_mini_venue_cards.dart`, `news_feed_featured_cards.dart`, `lib/features/venues/presentation/all_venues_page.dart`, `backend/src/routes/customer_venue_routes.js`, `backend/src/routes/merchant_news_routes.js`, and the related venue/feed tests. Trace the customer venue data from database query through the API response to each card and curated section. Some implementation may already exist in the workspace; validate and refine it instead of duplicating it.
- **Current screenshot findings**: The Sports venues screen shows a recommended venue list with one card displaying `Review 5.0`, `1 review`, and one heart. It does not clearly label any venue as popular, top rated, or most visited, and it does not show a distance or automatically surface nearby venues. A numeric rating or heart count alone does not explain the venue's rank to customers.
- **Goal**: Make the four discovery signals unmistakable on the customer venue page: **Most popular**, **Highest rated**, **Most visited**, and **Near you**. Customers should see why a venue is featured, its supporting count/rating/distance, and how to check availability.
- **Zero-regression requirements**:
  - Preserve venue discovery, search and filters, booking navigation, location sorting, save/heart/review actions, unavailable states, and the existing Sports, Event, and Fitness & Wellness flows.
  - Use real API-backed metrics. Do not fabricate visit counts or infer visits from hearts, page views, or clicks.
  - Keep venues with missing ratings or zero visits eligible for normal browsing; do not present missing ratings as a score or zero-visit venues as popular.
  - Preserve full venue results even when a venue also appears in a curated ranking section.
  - Request device location only through the platform permission flow. Handle denied, permanently denied, disabled, timed-out, and unavailable location states without blocking venue browsing or repeatedly prompting the customer.
- **Specification**:
  1. Add distinct, visible sections or filterable ranking chips named **Most popular**, **Highest rated**, **Most visited**, and **Near you** on the customer venue discovery screen. Do not rely on a generic `Recommended` sort label or expect users to infer a rank from a star or heart count.
  2. Define and show the evidence for each ranking: popularity uses venue hearts and shows the heart count; highest rated uses average review rating and shows the review count; most visited uses a real visit metric and shows its count. If visits are derived from bookings, count only completed/finished bookings and label the metric accurately. Return the metric consistently from the customer venue API without breaking existing response consumers.
  3. Automatically request location permission when entering the venue discovery experience if permission has not been handled, then obtain the customer's current position and surface a **Near you** section without requiring them to open filters or tap a location sort first. Show distance for each nearby venue and sort nearest first. Use valid venue coordinates and the existing location service where possible.
  4. Do not use a blocking popup to interrupt browsing. Surface nearby results prominently in the page. If permission is denied, location services are off, or location cannot be obtained, keep the rest of the venue page usable and provide a clear `Use my location` action and the existing area/manual sorting fallback. Do not keep re-prompting after denial.
  5. Define a sensible nearby radius or proximity rule in one place. If no venues meet it, either show a clearly labeled nearest venues fallback with their distances or explain that no nearby venues were found; never claim a distant venue is nearby without a distance or clear range.
  6. Organize venue cards with a clear visual hierarchy: strong venue photo and name, category/facility and location/distance, explicit ranking badge where relevant, rating plus review count, popularity/visit counts, price and its unit, and an obvious booking action. Keep spacing, typography, badges, and interactive controls readable and visually balanced.
  7. Sort each curated section by its own metric, with stable tie-breaking. Exclude venues without reviews from highest-rated rankings and venues without qualifying visits from most-visited rankings. Keep all venues in the complete results and preserve search, filters, and manual sorting.
  8. Make metric and location labels understandable at phone widths and accessible to screen readers. Avoid cramped rows, clipped counts, and controls that trigger the parent card action.
  9. Apply consistently across Sports, Event, and Fitness & Wellness pages, including compact cards, full listing cards, and applicable category-specific venue cards.
- **Acceptance Criteria**:
  - Customers see clearly labeled Popular, Highest rated, Most visited, and Near you discovery options without having to guess what the current rating, heart count, or `Recommended` order means.
  - Ranking order matches each metric and supporting counts are visible. Missing metrics are never presented as real values.
  - After location permission is granted, nearby venues appear automatically, are ordered by distance, and show that distance. Denied or unavailable location does not block browsing and offers a usable fallback.
  - Venue cards have a scannable, attractive layout and remain usable on narrow phones and at larger text sizes.
  - Existing venue booking routes, filters, reviews, hearts, saved venues, location behavior, and full-list completeness continue to work.
- **Verification**: Add or update focused API and widget tests for metric serialization, ranking order and tie cases, missing/zero metrics, automatic nearby discovery after permission, denied/unavailable location fallback, distance sorting and labels, all three business types, narrow card layouts, and existing booking/filter/action behavior. Run the focused venue/feed tests and analyze modified Dart files; do not run the full suite unless focused failures require broader diagnosis.

---

## Phase 26: Clear and User-Friendly Error Messages
- [x] **Task 26.1**: Replace raw technical errors shown in customer and merchant UI with clear, actionable, localized messages

### [Task 26.1] Make User-Facing Errors Understandable and Safe
- **Inspect first**: Search all Flutter customer and merchant presentation code for exceptions, API response details, and dynamic error strings rendered in snackbars, dialogs, forms, and error screens. Trace existing `AuthApiException.userMessage`, domain exceptions, localization helpers, retry actions, and representative widget tests. Start with the known examples in `matchmaking_lobby_list_page.dart`, `merchant_profile_dashboard.dart`, `reserve_dashboard.dart`, `news_feed_posts.dart`, and `first_launch_onboarding.dart`; determine which other occurrences are genuinely user-visible before changing them. Some flows may already handle errors appropriately; preserve those rather than applying a broad replacement.
- **Goal**: Give customers and merchants a short explanation of what happened and a useful next step, without exposing raw exception text or implementation details. Keep technical diagnostics available to developers through the existing logging approach.
- **Zero-regression requirements**:
  - Preserve API/domain-provided user messages when they are intentionally written for end users; do not replace useful booking, validation, permission, or authorization explanations with a generic failure.
  - Preserve retry, refresh, sign-in, cancel, and other recovery actions and their current behavior.
  - Do not claim a cause such as a network problem unless the error type confirms it. Do not tell users an operation failed if its result may be uncertain (for example, a request may have reached the server); explain how to safely check or retry in those cases.
  - Do not expose stack traces, raw server responses, internal exception class names, SQL/provider details, tokens, or other diagnostic data in customer/merchant UI.
  - Follow existing English/Filipino localization conventions for fixed user-facing strings. Avoid interpolating arbitrary exception text into a translated sentence.
- **Specification**:
  1. Inventory user-visible error rendering across customer and merchant journeys, including onboarding, authentication, venue discovery, booking, matchmaking, social actions, messaging, profile/settings, and merchant management. Record whether each message is a user-safe domain message, a validation message, or an internal/transport error.
  2. Replace raw technical errors with concise messages matched to the user action and, where known, the failure category. Include a practical next step when one is available (retry, refresh, sign in again, check details, or contact support only if a working support route exists).
  3. Keep diagnostic details out of UI and send them to the existing debug/logging path where appropriate. Do not add a logging dependency or log credentials, personal data, or payment details.
  4. Localize new or revised fixed messages using the existing localization system. Ensure message interpolation does not prevent English/Filipino translation.
  5. Make form validation specific and immediate: state what field/value needs correction, retain entered data where safe, and avoid clearing unrelated fields after validation or recoverable submission errors.
  6. Keep error screens and snackbars consistent with the available recovery action. Verify loading/submitting indicators are cleared after failure and prevent duplicate submissions while a request is in progress.
- **Acceptance Criteria**:
  - No customer- or merchant-facing error surface prints an arbitrary raw exception or server diagnostic; intentional end-user domain messages remain informative.
  - The known raw-error examples and every additional confirmed user-visible instance found during the inventory are handled with clear, context-specific messages.
  - Revised fixed messages follow existing English/Filipino localization conventions.
  - Errors explain a safe next step where possible, and existing retry/recovery behavior remains available and functional.
  - Validation and recoverable submission failures preserve relevant user input and do not leave controls stuck in a loading state.
- **Verification**: Add or update focused widget/controller tests for representative customer and merchant failures, including onboarding retry, matchmaking join failure, merchant profile refresh failure, social save failure, localized fixed copy, and preservation of existing validation/recovery behavior. Run focused tests and analyze modified Dart files; do not run the full suite unless focused failures require broader diagnosis.

---

## Phase 27: Prevent Double-Approval of Overlapping Sports Bookings
- [x] **Task 27.1**: Recheck and serialize sports-slot availability when a merchant approves a regular booking request

### [Task 27.1] Prevent Conflicting Booking Approvals
- **Inspect first**: Trace regular booking creation in `backend/src/routes/booking_routes.js`, matchmaking booking creation and merchant approval in `backend/src/routes/matchmaking_routes.js`, and regular booking approval in `backend/src/routes/booking_routes.js`. Inspect booking status/slot fields and indexes in `backend/src/schema_migrations.js`, related route test fakes and fixtures in `backend/test/lifecycle-routes.test.js` and `backend/test/matchmaking-routes.test.js`, and existing MySQL integration coverage. Confirm current transaction isolation and lock order before implementing; both regular and matchmaking creation already lock the venue row and compare overlapping time intervals and occupied court slots.
- **Confirmed issue**: Sports booking creation intentionally permits multiple regular requests for the same slot to remain `pending` (`backend/test/lifecycle-routes.test.js`, test `sports booking requests do not block pending requests for the same slot`). The merchant approval endpoint currently changes a pending booking to `approved` without rechecking whether another booking now occupies that interval. A merchant can therefore approve two requests that conflict.
- **Goal**: Allow multiple customers to request a slot if that is the current product policy, but ensure only a request that still has available venue/court capacity can become approved. Apply the same availability rules across regular sports and matchmaking reservations.
- **Zero-regression requirements**:
  - Preserve the current product behavior that ordinary regular sports requests may coexist as pending; do not silently make every pending request reserve the slot unless a change is necessary and explicitly justified in the task implementation notes.
  - Preserve status and time-overlap semantics, slot-number JSON handling, multi-slot and full-studio conflicts, merchant ownership checks, approval deadlines, payment obligations, ticket issuance, notifications, and transaction boundaries.
  - Treat approved bookings and active matchmaking reservations (`matchmaking_pending_merchant`, `matchmaking_open`) as occupying capacity, and exclude the booking being approved from its own conflict query.
  - Serialize approval against other approvals and regular/matchmaking booking creation for the same venue using a consistent venue/booking lock order. Avoid check-then-update races and retain rollback behavior on conflicts or failures.
  - On a conflict, do not issue a ticket, start a payment deadline, notify the customer that the booking is approved, or change the booking to `approved`. Return a clear conflict response that lets the merchant understand the slot is no longer available; keep the request in its existing pending state so the merchant can decide whether to decline it or let it expire.
  - Do not alter event and fitness approval behavior unless the existing resource model requires it; explain and test any necessary extension.
- **Specification**:
  1. Before updating a regular pending booking to `approved`, load and lock the venue and booking using a lock order compatible with booking and matchmaking creation. Revalidate merchant ownership, pending status, and approval deadline under the transaction.
  2. For sports bookings, check the requested date and interval against other occupying bookings at that venue. Apply the same slot/full-studio overlap rules used at creation: same physical slot or multi-slot overlap conflicts; any full-studio reservation conflicts; non-overlapping times and independent court slots remain approvable.
  3. Ensure two concurrent approvals for different pending requests on the same slot cannot both pass the availability check. Also ensure an approval cannot race with a new regular booking or matchmaking reservation creation.
  4. Return a deterministic conflict status/message when capacity was taken after the request was submitted. Do not confuse a slot conflict with an expired request or missing booking.
  5. Keep all success-side ticket, payment deadline, activity, and notification effects behind the successful conditional approval and transaction commit.
- **Acceptance Criteria**:
  - Given two overlapping regular pending sports requests for the same slot, approving the first succeeds and approving the second returns a conflict without changing its status, issuing a ticket, or creating a payment deadline.
  - A regular booking approval conflicts with an overlapping active matchmaking reservation, and matchmaking creation/approval cannot race through the same venue capacity.
  - Different slots at the same time can both be approved when neither reservation occupies the full studio; a full-studio reservation conflicts with every overlapping slot.
  - Non-overlapping time intervals remain approvable, including intervals that only touch at an endpoint if current booking rules treat those as non-overlapping.
  - Expired, declined, cancelled, and otherwise non-occupying records do not block approval; existing ownership, deadline, payment, ticket, and notification behavior remains correct.
  - Transactional/concurrency coverage demonstrates that conflicting approvals cannot both succeed; add MySQL integration coverage if route fakes cannot establish row-lock behavior.
- **Verification**: Add or update focused backend route and integration tests for same-slot double approval, separate slots, full-studio conflicts, overlapping matchmaking reservations, adjacent/non-overlapping times, expired requests, and competing approval/create transactions. Run focused backend tests and the relevant MySQL integration test where available; report any concurrency guarantees that cannot be verified locally.

---

## Phase 28: Theme-Aware Venue Cards
- [x] **Task 28.1**: Align Near You and All Listed Courts card buttons and content across user-selected themes

### [Task 28.1] Make Venue Card Styling Follow User Theme Preferences
- **Inspect first**: Review the compact cards in `lib/features/app_shell/presentation/news_feed_mini_venue_cards.dart`, full listed cards in `news_feed_venue_cards.dart` (`_listedVenueCard`), larger featured cards in `news_feed_featured_cards.dart`, and their presentation in `news_feed.dart`. Trace theme selection through `lib/features/settings/presentation/app_settings_page.dart`, `lib/core/app_preferences.dart`, and `lib/core/app_theme.dart`. Check current widget tests for the Near you section and All listed courts page. Confirm which cards hardcode colors and which inherit theme colors before editing.
- **Confirmed finding**: The compact Near you CTA explicitly uses the hardcoded `#5752E8` venue purple, while the All listed courts CTA inherits `FilledButtonThemeData`. The app theme updates filled buttons for the user's selected palette or custom accent, so these cards can show different CTA colors and the compact card can ignore the selected accent. Their content density differs by size, but rating wording and the visibility/order of price, location/distance, availability, and social metrics should remain understandable and consistent.
- **Goal**: Make the small Near you card and large All listed courts card feel like two sizes of the same venue-card system. Keep each size's appropriate information density while making button roles, labels, and theme behavior consistent.
- **Zero-regression requirements**:
  - Respect all supported preset accent palettes, custom accent colors, light mode, and dark mode. Do not introduce a fixed button color that bypasses `AppPreferences`/`AppTheme` or breaks accessible foreground contrast.
  - Preserve booking destinations, unavailable/disabled behavior, venue discovery ordering, distance display, ratings/review counts, price units, venue availability data, and heart/save/review actions.
  - Keep the compact card scannable and prioritize its Near you distance. The full card may show more detail; do not force identical layouts or duplicate content solely for visual uniformity.
  - Use only real venue data. Do not imply live slot availability from opening hours or invent missing ratings, prices, visits, or distance.
- **Specification**:
  1. Make the primary booking CTA in the compact Near you card and full All listed courts card use the active app theme's accent/button style, including its foreground contrast and disabled colors. Preserve size-appropriate height, padding, and shape while matching the same visual role.
  2. Review the larger featured-card CTA and related venue-card actions for the same hardcoded-accent issue; align them where they represent the same primary booking action, without recoloring unrelated status badges or semantic colors.
  3. Align content meaning and label wording across compact and full cards: venue name/category, rating with review count, price with unit, location and distance when available, accurate availability status, and the primary booking action. Keep distance prominent in Near you; allow the full listing to present its richer details.
  4. Replace ambiguous rating wording such as `Review 5.0` with an understandable rating label and review count, and ensure missing ratings are not rendered as scores.
  5. Check long names, labels, large text, unavailable venues, and color contrast in each palette and both brightness modes. Keep heart/save controls and booking CTA independently operable and accessible.
- **Acceptance Criteria**:
  - Near you, All listed courts, and any matching featured booking CTA use the user's selected accent color in all preset palettes and custom accent mode; none retains an unintended hardcoded purple or reverts to an unrelated theme default.
  - CTA foreground and disabled states remain legible in light and dark modes, including supported custom accent colors.
  - Compact and full cards communicate rating/review count, price unit, location/distance, availability, and booking action consistently, with Near you prioritizing distance and full cards retaining their richer layout.
  - Unavailable state, booking route, rating/review navigation, heart/save actions, and real availability wording remain correct.
  - Cards remain readable and their actions operable at narrow widths and larger text scales.
- **Verification**: Add or update focused widget tests for Near you and All listed courts CTAs under multiple preset palettes, a custom accent, light/dark mode, disabled state, and content labels/availability. Run the focused venue-card/settings tests and analyze modified Dart files; do not run the full suite unless focused failures require broader diagnosis.

---

## Phase 29: Rich Messaging and Replies
- [x] **Task 29.1**: Add swipe-to-reply, camera capture, and private phone/cloud file attachments to chat

### [Task 29.1] Improve Chat Replies and Media Sharing
- **Inspect first**: Trace the chat composer, message bubbles, attachment rendering, current image/GIF flow, realtime refresh, and delete/block behavior in `lib/features/messaging/presentation/messages_dashboard.dart`, `messages_chat_view.dart`, `messages_ui.dart`, `lib/features/messaging/data/`, and `backend/src/routes/messaging_routes.js`. Inspect `messages` schema/migrations, available private object storage and signed upload/read patterns, platform camera/file-picker configuration, and focused messaging tests before choosing implementation details. The existing chat supports gallery images and Tenor GIFs; `_pickImage` uses `ImageSource.gallery`, and the backend currently accepts image/GIF attachment JSON.
- **Build issue found during verification**: The current workspace reports compile errors in `messages_dashboard.dart` `_pickDocument()`. It depends on `file_picker: ^13.3.3`; fix this against the API actually resolved by `pubspec.lock` before considering the task complete. Version 13.3.3 exposes static `FilePicker.pickFile()` for one file (returns `PlatformFile?`) and `FilePicker.pickFiles()` for a list; it does not expose `FilePicker.platform`, and the v13 API removed `allowMultiple`, `withData`, and `PlatformFile.bytes`. Read selected data with `PlatformFile.readAsBytes()`. Avoid dynamic inference in extension/MIME mapping; use the typed `PlatformFile.name`/`extension` and explicit `if/else` or exhaustive typed switches. The screenshot's switch exhaustiveness errors may be cascading from the unresolved picker invocation; rerun analysis after fixing the API usage and resolve any remaining diagnostics.
- **Goal**: Let a user reply to a specific message with a familiar right-swipe gesture, capture a photo from the camera, or attach one supported file from the system picker. The system picker should expose phone storage and any cloud/file providers already connected to the device (such as Google Drive) without requiring a separate in-app Drive OAuth integration.
- **Zero-regression requirements**:
  - Preserve plain text, gallery images, Tenor GIFs, current image size/format rules, booking and matchmaking ticket cards, realtime message updates, blocked-conversation restrictions, and per-user message deletion behavior.
  - Keep one attachment per message for this task; allow accompanying text if the current composer supports it. Do not change ordinary text-send behavior.
  - Do not upload documents as base64 inside MySQL message JSON. Use authenticated private storage and short-lived, conversation-authorized access consistent with the existing storage architecture; never expose permanent public file URLs.
  - Validate allowed MIME types, file size, filename, conversation membership, and reply target on the server; do not trust client-provided metadata or a client-supplied storage path.
  - Preserve the draft and selected attachment after a recoverable send/upload failure; do not show a sent message until the server confirms it.
  - Keep the gesture directional and limited to an individual message so it does not break vertical chat scrolling, message selection/deletion, or system back navigation.
- **Specification**:
  1. Add a right-swipe gesture on eligible message bubbles to select that exact message as the reply target. Show a dismissible quoted-message preview above the composer and a compact reply reference in the sent/received bubble, including sender and a safely truncated text or attachment label. Handle replies to deleted or unavailable messages gracefully.
  2. Persist the reply relationship with a stable message ID (using an appropriate migration and server-side same-conversation validation). Ensure loading older messages, realtime updates, and message deletion do not render a stale or cross-conversation quoted message.
  3. Provide clear camera and gallery choices using the existing image flow where suitable. Camera capture should use the platform picker/API already available or add a supported dependency only if needed; show the captured image preview with remove/cancel before sending and retain the current image limits.
  4. Add a system document picker for one file per message. Support common image and document formats: JPEG/PNG/WebP images and PDF, DOC/DOCX, XLS/XLSX, and PPT/PPTX documents. Enforce the existing 5 MiB image limit and a 10 MiB document limit with clear user feedback before upload.
  5. Store attachments privately with validated metadata (display filename, MIME type, size, and storage identifier). Authorize download/read access through conversation membership and existing deletion rules. Reuse existing storage only if its security and lifecycle model fits messaging; otherwise add a dedicated, clearly scoped messaging storage path and document its configuration/cleanup needs.
  6. Render image previews and document rows in chat with file type/name/size and an explicit open/download action. Handle expired access URLs, missing files, unsupported previews, and download/open failures with a retryable user-friendly state; do not attempt to render office documents inline unless the app already supports it.
  7. Keep composer controls operable with screen readers, larger text, narrow screens, and both themes. Prevent duplicate uploads/sends and clean up abandoned staged uploads where supported.
- **Acceptance Criteria**:
  - Swiping right on a message selects the correct reply target; cancelling clears it; sending persists and displays the reply reference for both participants. Vertical scrolling and existing message actions continue to work.
  - Reply targets must belong to the same conversation and unauthorized or deleted targets cannot leak content.
  - Camera capture and gallery selection both produce a preview that can be removed before sending; permissions/cancellation/failure are handled without losing the draft.
  - The system picker can select supported local files and device-connected cloud-provider files when those providers are available. Unsupported types and files over their respective limits are rejected with clear feedback.
  - Supported attachments upload to private storage, are readable only by authorized conversation participants, survive app/API restart, and do not place file bytes in MySQL JSON.
  - Existing text, image, GIF, booking-ticket, matchmaking-ticket, block, realtime, and per-user deletion behavior remains intact.
  - Focused UI/API tests cover swipe reply, reply rendering and validation, camera/gallery preview handling, file type/size validation, upload/read authorization, failed-send draft preservation, and regressions to existing chat attachments.
- **Verification**: Add or update focused Flutter messaging tests and backend messaging/storage tests, plus a schema migration test if reply persistence requires a migration. Run the focused messaging/backend tests and analyze modified Dart files. Report camera/device-picker and connected-provider checks that require physical-device validation; do not claim Drive-provider behavior on devices where no provider is installed or connected.

---

## Phase 31: Realistic Prototype Checkout
- [x] **Task 31.1**: Expand prototype payments into a realistic, provider-ready simulated checkout

### [Task 31.1] Build a Realistic, Provider-Ready Prototype Checkout Flow
- **Inspect first**: Review `lib/features/bookings/presentation/prototype_payment_dialog.dart`, payment actions and status display in `lib/features/bookings/presentation/customer_bookings_page.dart`, `lib/features/bookings/data/booking_api.dart`, the prototype and PayMongo routes in `backend/src/routes/payment_routes.js`, booking payment fields and migrations, and existing payment lifecycle/UI/backend tests. Trace regular bookings, cash-on-arrival downpayments, and matchmaking payment paths so this task changes only the existing prototype checkout scope and does not duplicate provider integration work.
- **Goal**: Let customers exercise a realistic simulated payment lifecycle during development, including processing, verification, success, decline, cancellation, timeout, and retry where eligible. Keep the simulator behind a small payment boundary with normalized intent/status data so a future approved provider adapter can replace the simulator without rewriting booking UI and lifecycle handling. This task is for development/testing only; real payment processing is intentionally not being implemented now.
- **Zero-regression requirements**:
  - Preserve unmistakable prototype/demo labeling and the existing production prohibition on recording prototype payments. Never enable live charges, contact a payment provider, add provider credentials, or change `PAYMONGO_LIVE_ENABLED` as part of this task.
  - Never collect, transmit, log, or persist real card numbers, CVC/security codes, wallet PINs/passwords, or real one-time passcodes. Use clearly identified synthetic demo inputs or deterministic simulator scenarios; do not present the prototype as PCI-compliant or as a real provider checkout.
  - Keep payment state authoritative on the backend. A client-side success screen or callback alone must not mark a booking paid; validate booking ownership, amount, currency, eligible status, and payment deadline on the server before applying a simulated outcome.
  - Preserve existing booking approval gates, downpayment/balance calculations, expiry rules, transaction boundaries, ticket updates, and notification behavior. A failed, cancelled, or timed-out attempt must not be reported as paid or erase a prior valid payment.
  - Make duplicate submissions and retries safe. A retry must not create duplicate successful payment records or charge-like effects for the same simulated intent; only eligible unpaid obligations may be retried.
  - Keep simulator-specific behavior behind a replaceable boundary and use a normalized payment intent/result contract. Avoid speculative abstractions that require real provider accounts, secrets, SDKs, webhooks, or network calls in this task.
- **Specification**:
  1. Replace the single-step prototype confirmation with a clear checkout sequence that shows the obligation and amount, a processing state, and a simulated verification step where applicable. Provide explicit demo scenarios for success, decline, user cancellation, and timeout so the lifecycle can be tested without real credentials or nondeterministic delays.
  2. Create or adapt a small simulator/payment boundary with normalized intent identifiers, provider type (`prototype`), amount/currency, status, timestamps, and safe user-facing result data. Keep presentation code independent of simulator-specific backend response shapes.
  3. Have the backend create/resolve simulated payment attempts and enforce allowed state transitions. Persist only synthetic payment metadata needed for booking history and support; never accept sensitive payment form fields at these endpoints. Ensure repeat requests are idempotent and status polling/reload returns the same authoritative result.
  4. Map success to the existing booking payment lifecycle only after server-side validation. Map decline/cancel/timeout to recoverable unpaid states with clear next steps; enforce the existing deadline and do not allow a retry after the obligation expires or is already fully paid.
  5. Show a safe receipt/confirmation for successful prototype payments with a clearly synthetic reference and method label. Show distinct, accessible recovery messages for declined, cancelled, timed-out, expired, and retryable network/error states; preserve booking context when the user returns to the booking screen.
  6. Keep the real PayMongo route and configuration behavior unchanged. Document the seam for a future provider adapter and state explicitly that provider checkout sessions, signed webhook processing, refunds, reconciliation, and real-money launch approval are separate future work.
- **Acceptance Criteria**:
  - A development user can simulate processing, verification, success, decline, cancellation, and timeout; each outcome displays the right state and recovery action.
  - Reloading the booking or repeating a request returns the backend-authoritative payment result; duplicate/replayed attempts cannot record duplicate successful payments.
  - Only the owner of an eligible booking can create or resolve its simulated payment; wrong amount/currency, expired obligations, ineligible booking states, and unauthorized users are rejected without changing payment state.
  - Declined, cancelled, timed-out, and recoverable failed attempts remain unpaid and can be retried only while the obligation remains eligible. Successful payments update the existing booking/ticket lifecycle once.
  - No real sensitive payment credentials are required, sent, logged, or stored. Prototype requests and UI remain clearly labeled, and production continues to reject prototype payment recording.
  - Existing sports, event, fitness, cash-on-arrival, and matchmaking booking/payment behavior remains covered and unchanged except where the existing prototype flow is explicitly extended.
  - Focused Flutter and backend tests cover every simulator outcome, server validation, state transitions, idempotent retries/replays, production rejection, and existing payment lifecycle regressions.
- **Verification**: Add/update focused tests for prototype dialog/controller, payment API contract, backend payment routes, and relevant booking/ticket status flows. Run focused Flutter and backend tests and analysis for modified Dart files. Report any provider or physical-device behavior as unverified; do not claim real payment readiness.

---

## Phase 32: Customer Booking Status Banner Reliability and Dark Mode
- [x] **Task 32.1**: Keep dismissed booking status banners hidden and make banner text readable in dark mode

### [Task 32.1] Fix Customer Booking Banner Dismissal and Theme Contrast
- **Inspect first**: Trace banner selection, refresh, dismissal, and persistence in `lib/features/bookings/presentation/customer_bookings_page.dart`, `booking_status_banner.dart`, `customer_booking_controller.dart`, `lib/features/bookings/data/customer_bookings_session_provider.dart`, and `lib/core/app_session.dart`. Review `BookingStatusAnalyzer.bannerKey`, the customer booking banner tests in `test/customer_bookings_banner_test.dart`, and how light/dark colors are selected in `lib/core/app_design_system.dart` and `lib/core/app_theme.dart`. Reproduce the banner reappearing after refresh, dismissal, and reopening the Bookings page before changing code; identify whether the cause is key identity, account-scoped preference persistence, selection state, or refresh ordering.
- **Confirmed user report**: A customer reports that a booking status notification banner appears again whenever the Bookings page opens, even after using Refresh or Dismiss. The banner wording and reference text are also difficult to read with dark mode enabled. The existing page already attempts to persist dismissal and uses some theme-aware foreground colors, so verify the actual state and contrast behavior instead of assuming the existing tests cover the user's case.
- **Goal**: A customer can refresh booking data or dismiss a status banner without the same unchanged booking/status notification reopening on the next refresh or page visit. New booking status changes must still be eligible to notify. All banner content and actions must remain legible in both light and dark modes.
- **Zero-regression requirements**:
  - Preserve account-scoped dismissal; one customer's dismissal must not hide another customer's banner.
  - Keep notification identity stable for the same booking and status, but allow a materially changed status or payment obligation to produce a new notification.
  - Do not let periodic/background refresh reopen a notification the customer has dismissed. Refresh must still fetch and display current booking data and must not discard a newly changed status.
  - Preserve selection/priority when multiple booking notifications are eligible, unread booking counts, payment deadline messaging, booking references, and refresh/dismiss actions.
  - Respect the selected palette and dark mode. Use accessible foreground/background combinations for status text, references, icons, and action labels; retain semantic status meaning without relying on color alone.
  - Keep fixed user-facing strings within the existing English/Filipino localization conventions.
- **Specification**:
  1. Reproduce the reported behavior with focused tests using the real app session persistence boundary or a stateful test double. Cover refresh, explicit dismiss, page disposal/reopen, repeated refresh, and a subsequent booking status change.
  2. Correct the dismissal lifecycle at its source. Persist successful dismissals reliably and apply them consistently before selecting the active banner; ensure asynchronous refresh completion cannot overwrite a newer dismissed state. Do not merely collapse the widget while leaving the same notification eligible to reopen.
  3. Keep Refresh and Dismiss semantics clear and consistent. Refresh the server state while keeping the current unchanged notification hidden after the action; show a new notification if its booking status/payment identity changed.
  4. Update banner palette behavior for light and dark modes, including status-specific backgrounds, primary wording, transaction/booking reference labels and values, leading icon, and Refresh/Dismiss actions. Use existing design-system colors or a documented theme-aware mapping with adequate contrast.
  5. Add regression coverage for account isolation, multiple notifications, and a status transition after dismissal. Verify the banner's rendered foreground/background contrast in both brightness modes and at least one non-default accent palette.
- **Acceptance Criteria**:
  - Refreshing or dismissing a notification hides that same booking/status banner and it remains hidden after reload, periodic refresh, and reopening the Bookings page.
  - A changed booking status or changed payment obligation can generate a new banner without reviving the dismissed old state.
  - Dismissal for one account does not affect another account; eligible notifications for other bookings remain available according to existing priority rules.
  - Refresh still retrieves current bookings, updates unread counts, and exposes newly relevant status changes.
  - Banner message, transaction ID, booking reference, icon, and action labels are readable with sufficient contrast in light and dark modes, including a non-default accent palette.
  - Existing booking banner, payment deadline, unread count, and navigation tests continue to pass.
- **Verification**: Add/update focused Flutter tests in `test/customer_bookings_banner_test.dart` and relevant session/provider tests. Run the focused customer booking banner/session tests and Flutter analysis for modified Dart files; do not run the full suite unless focused failures require broader diagnosis.

---

## Phase 33: First-Time Customer Booking Confidence
- [x] **Task 33.1**: Make the first customer booking journey clear, recoverable, and safe to try

### [Task 33.1] Improve End-to-End Customer Booking Clarity
- **Inspect first**: Trace one complete customer journey from venue discovery and venue detail through selecting a date/time, submitting a booking request, merchant decision, payment obligation, and the resulting booking details/status. Review the current implementations and acceptance criteria of completed Tasks 8.1, 10.1, 18.1, 23.1, 25.1, 26.1, 31.1, and 32.1, plus their related screens, repositories, backend booking/payment routes, and focused tests. Treat completed items as existing behavior to verify, not as permission to redo them. Review current `git status` and diffs first; preserve unrelated workspace changes.
- **User feedback to address**: A first-time customer needs to know whether a slot is available, what the booking will cost, whether the booking is only requested or fully confirmed, when payment is due, and what to do if the merchant declines or payment expires. The prototype checkout currently resembles a real financial form by asking for card/mobile details even though it is demo-only; make the simulation clearly safe to try without asking for financial credentials.
- **Goal**: A new customer can understand and complete the booking journey without guessing about availability, total cost, booking state, payment timing, or the next action. Demo payment can be exercised safely without entering or transmitting real payment details.
- **Zero-regression requirements**:
  - Preserve existing booking availability checks, submit-time revalidation, booking idempotency, merchant approval, payment deadlines, downpayment/balance rules, cancellation/refund rules, and backend-authoritative payment state.
  - Never claim that a request is confirmed or a payment succeeded before the authoritative backend state says so. If a request times out after submission, provide a safe way to refresh/check its status before retrying.
  - Keep venue availability, ratings, price, ranking, and trust claims grounded in actual data; do not invent open slots, fees, venue verification, or merchant response guarantees.
  - Keep prototype/demo checkout clearly labeled and unavailable for production payment recording. Do not ask for, send, log, or store real card numbers, security codes, wallet PINs/passwords, mobile-wallet credentials, or one-time passcodes.
  - Preserve existing customer and merchant booking behavior, localization conventions, accessibility, responsive layouts, and account/session boundaries.
  - Do not duplicate work already satisfying completed-task acceptance criteria; make the smallest focused changes to demonstrated gaps in the integrated journey.
- **Specification**:
  1. Walk the current UI as a first-time customer and map the visible information and state changes at each step. Record any unmet requirement from this task with its screen/code path before implementation; do not expand scope into unrelated social, messaging, or merchant-dashboard redesign.
  2. Before the customer submits a booking, make the selected venue, date/time, duration/slots, price rate/unit, total amount, amount due, payment timing, and relevant cancellation/payment policy understandable together. Show availability as subject to the existing authoritative checks and explain when a slot is no longer available.
  3. Make each post-submit state distinguishable: request submitted and awaiting merchant action; approved with payment due; paid/confirmed; declined/cancelled; or expired. For each state, show the next safe action using the existing booking details and recovery routes.
  4. Replace prototype checkout's card/mobile/verification data entry with clearly labeled deterministic demo outcome choices (at minimum success, decline, cancel, and timeout) that require no payment credentials. Keep the amount and obligation visible. The backend must validate and apply only the selected simulated outcome; failed/cancelled/timed-out attempts remain unpaid and eligible only for safe retry while the obligation remains active. Keep simulator behavior isolated from live PayMongo checkout.
  5. Review retry and error paths across availability refresh, booking submission, merchant decision, payment, and booking reload. Preserve customer input where safe, prevent duplicate submissions, use clear actionable messages, and direct uncertain outcomes to a status refresh instead of implying success or failure.
  6. Ensure the journey remains understandable at narrow phone widths, larger text scales, screen-reader navigation, and both light and dark themes. Keep fixed copy within current English/Filipino localization conventions and avoid relying on color alone to distinguish booking/payment states.
  7. Add focused regression tests for the integrated customer journey, including unavailable slot/revalidation, visible total and payment timing, awaiting-approval versus confirmed state, each demo payment outcome, safe retry/timeout recovery, and preservation of existing booking policy behavior.
- **Acceptance Criteria**:
  - A first-time customer can identify the chosen venue/time, total cost, amount due, and payment deadline before submitting; displayed values match existing booking/pricing rules.
  - The UI never describes a pending merchant request as a confirmed reservation, and every resulting booking/payment state has a clear next action.
  - A newly unavailable slot or uncertain submission result is handled safely without duplicate booking requests or false confirmation.
  - Demo checkout supports success, decline, cancel, and timeout outcomes without requesting or transmitting financial credentials; only a server-validated successful simulation updates payment state.
  - Prototype behavior remains unmistakably demo-only and production continues to reject prototype payment recording; the real PayMongo flow remains separate and unchanged.
  - Existing availability, merchant approval, payment deadline/downpayment, cancellation, refund, notification, and booking-history behavior remains intact.
  - Focused tests cover the journey and its recovery paths, and changed UI remains accessible and readable across supported layouts, themes, and languages.
- **Verification**: Add or update focused Flutter customer booking/payment tests and backend prototype-payment route tests for each simulated outcome and eligibility boundary. Run those focused tests and Flutter analysis for modified Dart files. Report visual, device, provider-sandbox, and production payment checks that were not exercised; do not claim real-money readiness.
