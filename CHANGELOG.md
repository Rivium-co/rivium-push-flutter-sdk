# Changelog

## [0.1.16] - 2026-09-14

### Added
- `autoRefresh` on `RiviumPushConfig` (default `true`): keeps a registered device up to date on launch.
- The plugin reports itself as `flutter` with its version (`riviumPushSdkVersion`).
- iOS: delivery confirmation for foreground and silent notifications.

### Changed
- Requires `RiviumPushSDK ~> 0.1.12` (iOS) and `rivium-push-android:0.1.12`.

## [0.1.15] - 2026-09-09

### Changed
- Requires iOS `RiviumPushSDK ~> 0.1.11`, which fixes a launch crash (`Symbol not found: RiviumPush.shared`) for apps that also ship a Notification Service Extension. If you use delivery confirmation, your extension target now takes the separate `RiviumPushSDKExtension` pod instead of the `RiviumPushSDK/Extension` subspec — see the [iOS setup guide](https://rivium.co/cloud/rivium-push/docs/sdks-ios).

## [0.1.14] - 2026-09-08

### Fixed
- iOS: tapping a notification while the app was not running opened the app but never navigated. Apps using the UIScene lifecycle (the Flutter default) register plugins too late for iOS to deliver the launch tap, so it was discarded. The tap is now captured and returned by `getInitialMessage()`, matching Android.

### Added
- `appGroup` on `RiviumPushConfig` (iOS only) — enables delivery confirmation from a Notification Service Extension.

### Changed
- Requires `RiviumPushSDK ~> 0.1.9` (iOS) and `rivium-push-android:0.1.11`.

## [0.1.13] - 2026-08-23

### Added
- The app build number (Android `versionCode` / iOS `CFBundleVersion`) is now sent as a separate device attribute on every `register()` call. Filter on it in the dashboard's segment builder to target specific builds within the same release — useful for hotfix rollouts and staged releases.

## [0.1.12] - 2026-08-23

### Added
- Device attributes (app version, OS version, device model, language, country, timezone) are now sent automatically on every `register()` call. Use them as preset filters in the dashboard's segment builder to target specific app releases, OS versions, locales, or regions — no need to populate metadata yourself.

## [0.1.11] - 2026-08-23

### Changed
- `RiviumPush.register(metadata: ...)` now accepts `Map<String, Object?>` (was `Map<String, String>`). Values can be `String`, `int`, `double`, or `bool`. Native JSON types are preserved end-to-end so dashboard segments filter with real operators (`> 100` on `follower_count: 42`, `is true` on `is_pro`). Backward-compatible — existing `Map<String, String>` callers keep working.
- Bumped iOS SDK to 0.1.6 (matching type-preserving change on the native side).

### Fixed
- Numeric and boolean metadata previously arrived at the backend as JSON strings, so segment operator dropdowns only exposed `=` / `≠` / `contains`. Now they arrive with correct JSON types and `>`, `<`, `is`, `is not` become available.

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
