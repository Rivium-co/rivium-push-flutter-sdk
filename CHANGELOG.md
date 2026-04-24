# Changelog

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
