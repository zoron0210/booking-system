# SpotGo Sports

SpotGo Sports is a Flutter app for discovering sports venues and booking
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
`http://192.168.1.20:3000` for this LAN. This is a local developer address,
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

The Flutter client keeps shared HTTP/authentication behavior in
`lib/features/auth/data/auth_api.dart` and the `ApiTransport` contract in
`lib/core/api_transport.dart`. Booking, venue, messaging, social, and saved-item
operations are standalone repositories under their respective
`lib/features/*/data/` directories and are accessed through `AuthApi`'s
feature-specific properties. Flutter code imports canonical `lib/core/` and
`lib/features/` paths directly; moved modules no longer retain root-level
forwarding files. Venue/news operations use typed models from
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
`lib/features/settings/`. `lib/main.dart` is the startup entry point.
Shared preferences, session state, theming, design tokens, and motion utilities
are canonical under `lib/core/`. Customer booking screens and session access
are grouped under `lib/features/bookings/`; guest access and the shared
message-notification host are owned by their auth and messaging features. The
shared bottom navigation is owned by `lib/features/app_shell/`.
Sports, event, and fitness booking screens and pricing logic are owned by
`lib/features/bookings/`.
Fitness category and coach form inputs and cards are separated under
`lib/features/merchant_management/presentation/`, alongside the merchant
dashboard, profile, and add form. The add form's session access goes through an
injectable boundary under
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
Guests can browse public community posts and profiles; following people or
sharing experiences requires signing in. Customer Home is the first footer
destination and shows a newest-first **For You** feed of public experiences
alongside a **Following** feed containing posts by followed accounts. The
header add button opens the experience composer directly. Feed posts support
likes, comments, saved posts, and sharing through the device share menu.
Captions, comments, and chat messages support emoji; Tenor GIF search is
available in those composers and as post media. Configure `TENOR_API_KEY` in
the backend environment to enable GIF search. Posts are limited to five per
user in any rolling 24-hour period; each post can contain up to five media
items: JPEG, PNG, or WebP photos (10 MiB per photo maximum) or Tenor GIFs.
The Express API uses shared infrastructure and normalizers under
`backend/src/`; health and device-notification routes, authentication, social,
and merchant news routes are registered from dedicated modules under
`backend/src/routes/`. New social photos upload directly to the configured
private Firebase Storage bucket using short-lived signed URLs. Existing
base64 photos can be migrated with `npm run migrate:social-media` from
`backend` after configuring bucket credentials. The API server no longer runs
schema changes on startup: apply them explicitly with `npm run migrate` from
`backend` before starting or deploying the API. Applied schema migration
versions are recorded in MySQL, and DDL privileges should be kept separate
from the runtime API account where possible; see
[backend setup](backend/README.md).

Email/password credentials and password recovery are owned by the backend.
Firebase is used for Google identity sign-in and related profile integrations,
not as a parallel email/password store.

The dependency-scan GitHub Actions workflow runs Flutter analysis and the full
Flutter test suite, the backend test suite and dependency audit, and a MySQL
integration test against MySQL 8.4. Run the same checks locally with:

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
flutter test
cd backend
npm test
npm run test:integration
```

The Flutter commands above are useful focused checks; CI additionally runs the
complete Flutter suite with `flutter test`. The MySQL integration test needs a
dedicated test database configuration; see the backend README. Other backend
tests use isolated fakes and need no MySQL.

## UI styling

Use the shared colors, spacing, radii, and text styles in
`lib/core/app_design_system.dart`. The application-wide Material theme and card
styles live in `lib/core/app_theme.dart` and `lib/core/app_card_styles.dart`.

## Match notifications

On Android and iOS, open **Profile > Upcoming match** and turn on **Match
notifications**. The operating system asks for notification permission when the
user enables the switch; Android may also request exact-alarm permission. The
switch can be turned off at any time, which cancels pending match alerts.
Approved bookings are scheduled in the device's local time zone and
resynchronized when the profile loads. Notifications are scheduled by the
operating system, so they can appear while the app is on another page or in the
background.
