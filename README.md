# TinkerPro Sports

TinkerPro Sports is a Flutter app for discovering sports venues and booking
facilities. Customers can manage bookings, saved venues, reviews, and messages;
merchants can manage their business profiles, venues, bookings, and news posts.
The app uses Firebase for sign-in integrations and a Node.js/Express API backed
by MySQL for application data.

## Run locally

Prerequisites: Flutter and Dart versions compatible with `pubspec.yaml`, Node.js
20 or newer, and MySQL 8 or newer. Set up the API, database, and backend
environment variables using [backend/README.md](backend/README.md) first.

From the project root, fetch Flutter packages and start the app:

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<host-reachable-from-device>:3000
```

The API listens on port 3000 by default. The development API URL defaults to
`http://192.168.1.45:3000` for this LAN. This is a local developer address,
not a public/live server. If the computer's LAN address changes, override it
with `API_BASE_URL` as above. For the Android emulator, the host machine is
usually reachable at `10.0.2.2`, so use `http://10.0.2.2:3000`. A physical
device needs the computer's reachable LAN address, and both devices must be
connected to the same Wi-Fi/LAN and able to reach each other. Restart/rebuild
the Flutter app after changing `API_BASE_URL`, since it is a compile-time
setting.

Firebase platform options are included in `lib/firebase_options.dart`. Google
sign-in also depends on the matching Firebase/OAuth configuration and backend
client ID; see the backend setup instructions.

## Architecture and quality checks

The Flutter client keeps its shared HTTP/authentication primitives in
`lib/auth_api.dart` and groups booking, venue, messaging, and saved-item API
operations in `lib/features/*/data/`. Venue/news operations are exposed through
`AuthApi.venues` and use typed models from
`lib/features/venues/domain/venue_models.dart`; venue catalog selection and
disabled-event behavior live in `VenueCatalogRepository`, not the shared HTTP
client. Venue API calls validate inputs against backend contracts, normalize
response collections, and expose typed `VenueApiException` failures while
remaining compatible with `AuthApiException` handling. Legacy map-oriented
widgets receive explicit view-data adapters from the typed venue models.
Authentication UI and session
orchestration live under `lib/features/auth/`, and startup injects the app
builder rather than importing the app shell back into the bootstrap module.
The app composition, overview, auth, and discovery screens are grouped under
`lib/features/app_shell/`; appearance and language settings live under
`lib/features/settings/`. `lib/main.dart` is only the startup entry point, and
root-level exports remain as compatibility facades during gradual migration.
Fitness category and coach form inputs and cards are separated under
`lib/features/merchant_management/presentation/`; the larger merchant add form
remains in its legacy screen while it is migrated incrementally. Its session
access now goes through an injectable merchant-add session boundary under
`lib/features/merchant_management/data/`, and focused merchant form tests run in
CI. Messaging session reads are isolated behind an injectable provider in
`lib/features/messaging/data/` and covered by controller tests.
Customer booking session reads use a separate injectable provider in
`lib/features/bookings/data/`, including booking-status banner preferences.
Customer profile session reads and writes are isolated behind an injectable
provider in `lib/features/profile/data/`.
Merchant profile and dashboard session access share an injectable provider in
`lib/features/merchant_management/data/`, with tests for session persistence.
Successful sign-in and sign-out transitions show localized confirmation; the
sign-out confirmation makes clear that the app has returned to guest browsing.
The social community is available from customer and merchant profiles. It
supports following active accounts, a following feed, and experience posts with
captions and photos. Posts are limited to five per user in any rolling 24-hour
period; each post can contain up to five JPEG, PNG, or WebP photos (10 MiB per
photo maximum).
The Express API uses shared infrastructure and normalizers under
`backend/src/`; authentication and merchant news routes are registered from
dedicated modules under `backend/src/routes/`. The API server no longer runs
schema changes on startup: apply them explicitly with `npm run migrate` from
`backend` before starting or deploying the API. Applied schema migration
versions are recorded in MySQL, and DDL privileges should be kept separate
from the runtime API account where possible; see
[backend setup](backend/README.md).

Email/password credentials and password recovery are owned by the backend.
Firebase is used for Google identity sign-in and related profile integrations,
not as a parallel email/password store.

The dependency-scan GitHub Actions workflow checks Flutter analysis and the
focused Flutter API contract tests, the backend test suite and dependency
audit, and a MySQL integration test against MySQL 8.4. Run the same checks
locally with:

```sh
flutter analyze
flutter test test/auth_service_test.dart test/app_startup_test.dart test/messages_api_auth_test.dart test/news_feed_navigation_test.dart
flutter test test/auth_success_feedback_test.dart
flutter test test/logout_feedback_test.dart
flutter test test/app_settings_dependency_test.dart test/booking_pricing_test.dart test/booking_status_analyzer_test.dart test/booking_schedule_conflict_test.dart
flutter test test/messages_controller_test.dart
flutter test test/customer_bookings_session_test.dart
flutter test test/profile_session_provider_test.dart
flutter test test/merchant_session_provider_test.dart test/merchant_profile_dashboard_test.dart test/merchant_dashboard_navigation_test.dart test/merchant_dashboard_polling_test.dart
flutter test test/merchant_add_wizard_test.dart test/merchant_add_publish_test.dart test/merchant_add_multi_sport_test.dart test/merchant_add_fitness_test.dart test/merchant_add_form_layout_test.dart test/merchant_add_price_display_test.dart test/merchant_fitness_form_sections_test.dart
cd backend
npm test
npm run test:integration
```

Run the complete Flutter test suite locally with `flutter test`. CI gates
analysis and focused authentication, startup, API, and news-feed interaction
tests. The MySQL integration test needs a dedicated test database
configuration; see the backend README. Other backend tests use isolated fakes
and need no MySQL.

## UI styling

Use the shared colors, spacing, radii, and text styles in
`lib/app_design_system.dart`. The application-wide Material theme is defined in
`lib/app_theme.dart`; reusable card and filter styles live in
`lib/app_card_styles.dart` and `lib/filter_panel_style.dart`.

## Match notifications

On Android and iOS, open **Profile > Upcoming match** and turn on **Match
notifications**. The operating system asks for notification permission when the
user enables the switch; Android may also request exact-alarm permission. The
switch can be turned off at any time, which cancels pending match alerts.
Approved bookings are scheduled in the device's local time zone and
resynchronized when the profile loads. Notifications are scheduled by the
operating system, so they can appear while the app is on another page or in the
background.
