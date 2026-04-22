import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_push/rivium_push.dart';

void main() {
  group('RiviumPushLogLevel', () {
    test('all log levels are defined', () {
      expect(RiviumPushLogLevel.values.length, 6);
      expect(RiviumPushLogLevel.values, contains(RiviumPushLogLevel.none));
      expect(RiviumPushLogLevel.values, contains(RiviumPushLogLevel.error));
      expect(RiviumPushLogLevel.values, contains(RiviumPushLogLevel.warning));
      expect(RiviumPushLogLevel.values, contains(RiviumPushLogLevel.info));
      expect(RiviumPushLogLevel.values, contains(RiviumPushLogLevel.debug));
      expect(RiviumPushLogLevel.values, contains(RiviumPushLogLevel.verbose));
    });
  });

  group('RiviumPushAnalyticsEvent', () {
    test('all analytics events are defined', () {
      expect(RiviumPushAnalyticsEvent.values, contains(RiviumPushAnalyticsEvent.sdkInitialized));
      expect(RiviumPushAnalyticsEvent.values, contains(RiviumPushAnalyticsEvent.deviceRegistered));
      expect(RiviumPushAnalyticsEvent.values, contains(RiviumPushAnalyticsEvent.deviceUnregistered));
      expect(RiviumPushAnalyticsEvent.values, contains(RiviumPushAnalyticsEvent.messageReceived));
      expect(RiviumPushAnalyticsEvent.values, contains(RiviumPushAnalyticsEvent.messageDisplayed));
      expect(RiviumPushAnalyticsEvent.values, contains(RiviumPushAnalyticsEvent.connected));
      expect(RiviumPushAnalyticsEvent.values, contains(RiviumPushAnalyticsEvent.disconnected));
      expect(RiviumPushAnalyticsEvent.values, contains(RiviumPushAnalyticsEvent.connectionError));
      expect(RiviumPushAnalyticsEvent.values, contains(RiviumPushAnalyticsEvent.topicSubscribed));
      expect(RiviumPushAnalyticsEvent.values, contains(RiviumPushAnalyticsEvent.topicUnsubscribed));
    });
  });

  group('NetworkType', () {
    test('fromString returns correct type for wifi', () {
      expect(NetworkType.fromString('wifi'), NetworkType.wifi);
      expect(NetworkType.fromString('WIFI'), NetworkType.wifi);
    });

    test('fromString returns correct type for cellular', () {
      expect(NetworkType.fromString('cellular'), NetworkType.cellular);
    });

    test('fromString returns correct type for ethernet', () {
      expect(NetworkType.fromString('ethernet'), NetworkType.ethernet);
    });

    test('fromString returns correct type for vpn', () {
      expect(NetworkType.fromString('vpn'), NetworkType.vpn);
    });

    test('fromString returns correct type for none', () {
      expect(NetworkType.fromString('none'), NetworkType.none);
    });

    test('fromString returns unknown for invalid input', () {
      expect(NetworkType.fromString('invalid'), NetworkType.unknown);
      expect(NetworkType.fromString(''), NetworkType.unknown);
    });
  });

  group('NetworkState', () {
    test('creates correctly from map', () {
      final map = {
        'isAvailable': true,
        'networkType': 'wifi',
      };
      final state = NetworkState.fromMap(map);

      expect(state.isAvailable, true);
      expect(state.networkType, NetworkType.wifi);
    });

    test('isWifi returns true for wifi connection', () {
      final state = NetworkState(isAvailable: true, networkType: NetworkType.wifi);
      expect(state.isWifi, true);
      expect(state.isCellular, false);
    });

    test('isCellular returns true for cellular connection', () {
      final state = NetworkState(isAvailable: true, networkType: NetworkType.cellular);
      expect(state.isCellular, true);
      expect(state.isWifi, false);
    });

    test('toString includes all values', () {
      final state = NetworkState(isAvailable: true, networkType: NetworkType.wifi);
      final str = state.toString();
      expect(str, contains('available: true'));
      expect(str, contains('type: wifi'));
    });
  });

  group('AppState', () {
    test('creates correctly from map', () {
      final map = {'isInForeground': true};
      final state = AppState.fromMap(map);

      expect(state.isInForeground, true);
    });

    test('handles missing values with defaults', () {
      final map = <String, dynamic>{};
      final state = AppState.fromMap(map);

      expect(state.isInForeground, false);
    });

    test('toString includes all values', () {
      final state = AppState(isInForeground: true);
      expect(state.toString(), contains('isInForeground: true'));
    });
  });

  group('ReconnectionState', () {
    test('creates correctly from map', () {
      final map = {
        'retryAttempt': 2,
        'nextRetryMs': 5000,
      };
      final state = ReconnectionState.fromMap(map);

      expect(state.retryAttempt, 2);
      expect(state.nextRetryMs, 5000);
    });

    test('nextRetryDuration returns correct Duration', () {
      final state = ReconnectionState(retryAttempt: 1, nextRetryMs: 3000);
      expect(state.nextRetryDuration, Duration(milliseconds: 3000));
    });

    test('handles missing values with defaults', () {
      final map = <String, dynamic>{};
      final state = ReconnectionState.fromMap(map);

      expect(state.retryAttempt, 0);
      expect(state.nextRetryMs, 0);
    });
  });

  group('AppUpdateInfo', () {
    test('creates correctly from map', () {
      final map = {
        'previousVersion': '1.0.0',
        'currentVersion': '1.1.0',
        'needsReregistration': true,
      };
      final info = AppUpdateInfo.fromMap(map);

      expect(info.previousVersion, '1.0.0');
      expect(info.currentVersion, '1.1.0');
      expect(info.needsReregistration, true);
    });

    test('handles missing values with defaults', () {
      final map = <String, dynamic>{};
      final info = AppUpdateInfo.fromMap(map);

      expect(info.previousVersion, 'unknown');
      expect(info.currentVersion, 'unknown');
      expect(info.needsReregistration, false);
    });
  });

  group('RiviumPushError', () {
    test('creates correctly from map', () {
      final map = {
        'code': 1000,
        'details': 'Connection failed',
      };
      final error = RiviumPushError.fromMap(map);

      expect(error.code, 1000);
      expect(error.errorCode, RiviumPushErrorCode.connectionFailed);
      expect(error.message, 'Failed to connect to MQTT broker');
      expect(error.details, 'Connection failed');
    });

    test('handles unknown error code', () {
      final map = {
        'code': 99999,
      };
      final error = RiviumPushError.fromMap(map);

      expect(error.errorCode, RiviumPushErrorCode.unknownError);
    });

    test('toMap returns correct structure', () {
      final error = RiviumPushError(
        errorCode: RiviumPushErrorCode.connectionTimeout,
        details: 'Timed out after 30s',
      );
      final map = error.toMap();

      expect(map['code'], 1001);
      expect(map['message'], 'Connection timed out');
      expect(map['details'], 'Timed out after 30s');
    });
  });

  group('RiviumPush Analytics', () {
    test('isAnalyticsEnabled is false by default', () {
      RiviumPush.disableAnalytics();
      expect(RiviumPush.isAnalyticsEnabled, false);
    });

    test('enableAnalytics enables analytics', () {
      RiviumPush.enableAnalytics();
      expect(RiviumPush.isAnalyticsEnabled, true);
      // Clean up
      RiviumPush.disableAnalytics();
    });

    test('setAnalyticsHandler enables analytics', () {
      RiviumPush.setAnalyticsHandler((event, props) {});
      expect(RiviumPush.isAnalyticsEnabled, true);
      // Clean up
      RiviumPush.disableAnalytics();
    });

    test('disableAnalytics disables analytics', () {
      RiviumPush.setAnalyticsHandler((event, props) {});
      RiviumPush.disableAnalytics();
      expect(RiviumPush.isAnalyticsEnabled, false);
    });
  });
}
