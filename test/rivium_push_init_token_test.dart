import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_push/rivium_push.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('init with a tokenProvider registers it before init', () async {
    const channel = MethodChannel('co.rivium.push/main');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });

    Future<String> provider() async => 'jwt';
    await RiviumPush.init(RiviumPushConfig(apiKey: 'key', tokenProvider: provider));

    expect(calls.map((c) => c.method), ['setTokenProvider', 'init']);
    expect(calls.first.arguments, {'enabled': true});
  });
}
