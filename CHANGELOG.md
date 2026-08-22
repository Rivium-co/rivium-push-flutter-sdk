# Changelog

## [0.1.10] - 2026-08-23

### Added
- `RiviumPushInAppOverlay` widget renders in-app messages out of the box (modal, banner, fullscreen, card). Wrap your app once — no per-app renderer needed.
- `RiviumPushInAppTheme` for styling knobs (colors, border radius, elevation, max width, animation duration).
- `RiviumPushInAppBuilders` to fully replace any renderer with your own widget.
- `RiviumPush.recordInAppButtonClick(messageId, buttonId)` and `RiviumPush.recordInAppDismissed(messageId)` — used internally by the overlay to record impressions on Flutter-rendered UI.

### Fixed
- In-app messages no longer silently drop when no manual `onInAppMessageReady` handler is set. The native SDK skips its own UI when the plugin sets a callback; the new overlay now renders it.

## [0.1.9] - 2026-08-18

### Fixed
- Android <14: crash on start (0.1.8 regression). Bumped native SDK to 0.1.8.

## [0.1.8] - 2026-08-17

### Fixed
- Android 15+: app crashed at boot (`ForegroundServiceStartNotAllowedException`). Switched foreground service to `specialUse`.

### Changed
- Bumped Android native SDK to 0.1.7.

## [0.1.7] - 2026-05-26

### Fixed
- iOS: `onNotificationTapped` now fires when tapping a foreground notification.

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
