import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_push/rivium_push.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('co.rivium.push/main');
  const codec = StandardMethodCodec();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  /// Calls into Dart the way the native side does; returns the decoded reply.
  Future<dynamic> callFromNative(String method, [dynamic arguments]) async {
    final reply = await messenger.handlePlatformMessage(
      channel.name,
      codec.encodeMethodCall(MethodCall(method, arguments)),
      (_) {},
    );
    return codec.decodeEnvelope(reply!);
  }

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() async {
    await RiviumPush.setTokenProvider(null);
    messenger.setMockMethodCallHandler(channel, null);
  });

  // Runs first: RiviumPush.init only acts once per isolate.
  test('init without a tokenProvider makes the same channel calls as before', () async {
    await RiviumPush.init(const RiviumPushConfig(apiKey: 'key'));

    expect(calls.map((c) => c.method), ['init']);
    expect((calls.single.arguments as Map).keys, isNot(contains('tokenProvider')));
    expect(const RiviumPushConfig(apiKey: 'key').toMap().keys.toSet(), {
      'apiKey',
      'notificationIcon',
      'usePushKit',
      'showServiceNotification',
      'showNotificationInForeground',
      'autoConnect',
      'appGroup',
      'autoRefresh',
      'wrapperSdkName',
      'wrapperSdkVersion',
    });
  });

  test('a tokenProvider on the config is accepted and kept out of the init map', () {
    Future<String> chatStyleProvider() async => 'jwt';
    final config = RiviumPushConfig(apiKey: 'key', tokenProvider: chatStyleProvider);

    expect(config.tokenProvider, isNotNull);
    expect(config.toMap().keys, isNot(contains('tokenProvider')));
  });

  test('setting a provider tells native, removing it tells native', () async {
    await RiviumPush.setTokenProvider(() async => 'jwt');
    expect(calls.single.method, 'setTokenProvider');
    expect(calls.single.arguments, {'enabled': true});

    calls.clear();
    await RiviumPush.setTokenProvider(null);
    expect(calls.single.method, 'setTokenProvider');
    expect(calls.single.arguments, {'enabled': false});
  });

  test('getUserToken is answered with the provider value', () async {
    await RiviumPush.setTokenProvider(() async => 'jwt-1');
    expect(await callFromNative('getUserToken'), 'jwt-1');

    // A synchronous provider works too, and replacing takes effect.
    await RiviumPush.setTokenProvider(() => 'jwt-2');
    expect(await callFromNative('getUserToken'), 'jwt-2');
  });

  test('getUserToken is answered with null when signed out', () async {
    await RiviumPush.setTokenProvider(() async => null);
    expect(await callFromNative('getUserToken'), isNull);

    await RiviumPush.setTokenProvider(() => '');
    expect(await callFromNative('getUserToken'), isNull);
  });

  test('a provider that throws becomes an error for native', () async {
    await RiviumPush.setTokenProvider(() async => throw StateError('backend down'));

    expect(
      () => callFromNative('getUserToken'),
      throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'token_provider_failed')),
    );
  });

  test('getUserToken without a provider is an error, not "signed out"', () async {
    expect(
      () => callFromNative('getUserToken'),
      throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'no_token_provider')),
    );
  });

  test('setUserToken forwards the token and null', () async {
    await RiviumPush.setUserToken('jwt');
    await RiviumPush.setUserToken(null);

    expect(calls.map((c) => c.method), ['setUserToken', 'setUserToken']);
    expect(calls[0].arguments, {'token': 'jwt'});
    expect(calls[1].arguments, {'token': null});
  });

  test('auth errors from native reach onAuthError', () async {
    final events = <RiviumPushAuthErrorEvent>[];
    RiviumPush.onAuthError(events.add);
    await RiviumPush.setTokenProvider(() async => 'jwt');

    await callFromNative('onAuthError', {'code': 'token_invalid', 'message': 'Invalid user token'});

    expect(events.single.code, RiviumPushAuthErrorEvent.tokenInvalid);
    expect(events.single.message, 'Invalid user token');
    expect(events.single.error, isNull);
  });

  test('a provider failure is attached to the auth error that follows', () async {
    final events = <RiviumPushAuthErrorEvent>[];
    RiviumPush.onAuthError(events.add);
    final failure = StateError('backend down');
    await RiviumPush.setTokenProvider(() async => throw failure);

    await expectLater(() => callFromNative('getUserToken'), throwsA(isA<PlatformException>()));
    await callFromNative('onAuthError', {'code': 'token_provider_failed', 'message': 'tokenProvider failed'});

    expect(events.single.code, RiviumPushAuthErrorEvent.tokenProviderFailed);
    expect(events.single.error, same(failure));
  });
}
