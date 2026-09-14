import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_push/rivium_push.dart';

void main() {
  test('riviumPushSdkVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull);
    expect(riviumPushSdkVersion, match!.group(1));
  });

  test('RiviumPushConfig forwards wrapper identity and autoRefresh', () {
    final map = const RiviumPushConfig(apiKey: 'key').toMap();
    expect(map['autoRefresh'], isTrue);
    expect(map['wrapperSdkName'], 'flutter');
    expect(map['wrapperSdkVersion'], riviumPushSdkVersion);

    final disabled = const RiviumPushConfig(apiKey: 'key', autoRefresh: false).toMap();
    expect(disabled['autoRefresh'], isFalse);
  });
}
