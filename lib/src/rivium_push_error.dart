/// Standardized error codes for RiviumPush SDK.
/// These codes help developers identify and handle specific error scenarios.
enum RiviumPushErrorCode {
  // Connection errors (1000-1099)
  connectionFailed(1000, 'Failed to connect to MQTT broker'),
  connectionTimeout(1001, 'Connection timed out'),
  connectionLost(1002, 'Connection to server was lost'),
  connectionRefused(1003, 'Connection was refused by server'),
  authenticationFailed(1004, 'Authentication failed - invalid credentials'),
  sslError(1005, 'SSL/TLS handshake failed'),
  brokerUnavailable(1006, 'MQTT broker is unavailable'),

  // Subscription errors (1100-1199)
  subscriptionFailed(1100, 'Failed to subscribe to topic'),
  unsubscriptionFailed(1101, 'Failed to unsubscribe from topic'),
  invalidTopic(1102, 'Invalid topic format'),

  // Message errors (1200-1299)
  messageDeliveryFailed(1200, 'Failed to deliver message'),
  messageParseError(1201, 'Failed to parse message payload'),
  messageTimeout(1202, 'Message delivery timed out'),

  // Configuration errors (1300-1399)
  invalidConfig(1300, 'Invalid configuration'),
  missingApiKey(1301, 'API key is missing'),
  missingServerUrl(1302, 'Server URL is missing'),
  invalidCredentials(1303, 'Invalid MQTT credentials'),
  configurationFailed(1304, 'Failed to fetch configuration from server'),

  // Registration errors (1400-1499)
  registrationFailed(1400, 'Device registration failed'),
  deviceIdGenerationFailed(1401, 'Failed to generate device ID'),
  serverError(1402, 'Server returned an error'),
  networkError(1403, 'Network request failed'),

  // State errors (1500-1599)
  notInitialized(1500, 'SDK is not initialized'),
  notConnected(1501, 'Not connected to server'),
  alreadyConnected(1502, 'Already connected to server'),
  serviceNotRunning(1503, 'Background service is not running'),

  // Unknown error
  unknownError(9999, 'An unknown error occurred');

  final int code;
  final String message;

  const RiviumPushErrorCode(this.code, this.message);

  /// Get error code from int value
  static RiviumPushErrorCode fromCode(int code) {
    return RiviumPushErrorCode.values.firstWhere(
      (e) => e.code == code,
      orElse: () => RiviumPushErrorCode.unknownError,
    );
  }
}

/// Represents a RiviumPush error with code and additional details.
class RiviumPushError {
  /// The error code
  final RiviumPushErrorCode errorCode;

  /// Additional details about the error
  final String? details;

  /// Get the numeric error code
  int get code => errorCode.code;

  /// Get the error message
  String get message => errorCode.message;

  RiviumPushError({
    required this.errorCode,
    this.details,
  });

  /// Create a RiviumPushError from a map (from native code)
  factory RiviumPushError.fromMap(Map<dynamic, dynamic> map) {
    final code = map['code'] as int? ?? 9999;
    return RiviumPushError(
      errorCode: RiviumPushErrorCode.fromCode(code),
      details: map['details'] as String?,
    );
  }

  /// Convert to map
  Map<String, dynamic> toMap() => {
        'code': code,
        'message': message,
        'details': details,
      };

  @override
  String toString() =>
      'RiviumPushError(code: $code, message: $message, details: $details)';
}

/// Represents the reconnection state during automatic retry
class ReconnectionState {
  /// Current retry attempt number (0-based)
  final int retryAttempt;

  /// Time in milliseconds until next retry
  final int nextRetryMs;

  ReconnectionState({
    required this.retryAttempt,
    required this.nextRetryMs,
  });

  /// Create from map (from native code)
  factory ReconnectionState.fromMap(Map<dynamic, dynamic> map) {
    return ReconnectionState(
      retryAttempt: map['retryAttempt'] as int? ?? 0,
      nextRetryMs: (map['nextRetryMs'] as num?)?.toInt() ?? 0,
    );
  }

  /// Get next retry time as Duration
  Duration get nextRetryDuration => Duration(milliseconds: nextRetryMs);

  @override
  String toString() =>
      'ReconnectionState(attempt: $retryAttempt, nextRetry: ${nextRetryMs}ms)';
}

/// Network type enumeration
enum NetworkType {
  wifi,
  cellular,
  ethernet,
  vpn,
  none,
  unknown;

  static NetworkType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'wifi':
        return NetworkType.wifi;
      case 'cellular':
        return NetworkType.cellular;
      case 'ethernet':
        return NetworkType.ethernet;
      case 'vpn':
        return NetworkType.vpn;
      case 'none':
        return NetworkType.none;
      default:
        return NetworkType.unknown;
    }
  }
}

/// Represents the current network state
class NetworkState {
  /// Whether network is currently available
  final bool isAvailable;

  /// The type of network connection
  final NetworkType networkType;

  NetworkState({
    required this.isAvailable,
    required this.networkType,
  });

  /// Create from map (from native code)
  factory NetworkState.fromMap(Map<dynamic, dynamic> map) {
    return NetworkState(
      isAvailable: map['isAvailable'] as bool? ?? false,
      networkType: NetworkType.fromString(map['networkType'] as String? ?? 'unknown'),
    );
  }

  /// Check if connected via WiFi
  bool get isWifi => networkType == NetworkType.wifi;

  /// Check if connected via cellular
  bool get isCellular => networkType == NetworkType.cellular;

  @override
  String toString() =>
      'NetworkState(available: $isAvailable, type: ${networkType.name})';
}

/// Represents the app's foreground/background state
class AppState {
  /// Whether the app is currently in the foreground
  final bool isInForeground;

  AppState({required this.isInForeground});

  /// Create from map (from native code)
  factory AppState.fromMap(Map<dynamic, dynamic> map) {
    return AppState(
      isInForeground: map['isInForeground'] as bool? ?? false,
    );
  }

  @override
  String toString() => 'AppState(isInForeground: $isInForeground)';
}

/// Represents an app update event
/// Sent when the SDK detects the app was updated and re-registration may be needed
class AppUpdateInfo {
  /// The previous app version before the update
  final String previousVersion;

  /// The current app version after the update
  final String currentVersion;

  /// Whether re-registration is recommended
  /// When true, the app should call RiviumPush.register() to ensure the device token is valid
  final bool needsReregistration;

  AppUpdateInfo({
    required this.previousVersion,
    required this.currentVersion,
    required this.needsReregistration,
  });

  /// Create from map (from native code)
  factory AppUpdateInfo.fromMap(Map<dynamic, dynamic> map) {
    return AppUpdateInfo(
      previousVersion: map['previousVersion'] as String? ?? 'unknown',
      currentVersion: map['currentVersion'] as String? ?? 'unknown',
      needsReregistration: map['needsReregistration'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'AppUpdateInfo(previous: $previousVersion, current: $currentVersion, needsReregistration: $needsReregistration)';
}
