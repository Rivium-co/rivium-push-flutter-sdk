# Changelog

## [0.1.6] - 2026-05-13

### Fixed
- Android: custom notification sounds from `res/raw/` now play reliably across OEMs.

### Changed
- Bumped Android native SDK to 0.1.6

## [0.1.5] - 2026-05-12

### Fixed
- Notification action buttons now fire the `onNotificationAction` callback on Android and iOS.
- Android: notifications auto-dismiss after an action button tap.

### Changed
- Bumped Android native SDK to 0.1.5 and iOS native SDK to 0.1.5

## [0.1.4] - 2026-05-12

### Fixed
- Android: tapping a notification from the status bar now reliably brings the app to the foreground (previously the tap was silently dropped on Android 10+ when the app was in the background)

### Changed
- Bumped Android native SDK to 0.1.4

## [0.1.3] - 2026-04-30

### Changed
- Bumped Android native SDK to 0.1.3 and iOS native SDK to 0.1.4
- subscriptionId migration: backend-issued per-install UUID alongside deviceId
- userId now persists across app launches; `setUserId` only needs to be called after install or login

## [0.1.1] - 2026-04-24

### Fixed
- APNs registration no longer triggers when PushKit is in use, preventing duplicate token registration

### Added
- VoIP call UI support in example app via rivium_push_voip plugin

## [0.1.0] - 2026-04-22

### Added
- Push notifications for Android and iOS
- In-app messages (modal, banner, fullscreen)
- Inbox with read/archive/delete support
- A/B testing with variant assignment and tracking
- Topic subscriptions
- Silent messages
- Notification tap handling
- Analytics tracking with custom handler
- Auto-reconnection with exponential backoff
- Log level configuration
- User management (set/clear user ID)
- Badge management
- Network and app state callbacks
