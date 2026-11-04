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

---

## Audit Notes

- `flutter_map` and `latlong2` are not unused: `news_feed.dart`,
  `merchant_add_page.dart`, and `venue_address_geocoder.dart` import them.
  Keep both dependencies unless those map/geocoding features are intentionally
  removed.
- Disk image caching and off-thread base64 decoding were already implemented;
  verified in `news_feed.dart` with `CachedNetworkImageProvider` and `compute`.
- Backend route extraction is incremental. Activity logs, saved items,
  authentication, social, messaging, system, and merchant-news routes now live
  under `backend/src/routes/`; other legacy handlers remain in `server.js` for
  future, separately tested extractions.
