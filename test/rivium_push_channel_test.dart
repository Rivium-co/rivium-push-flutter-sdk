import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_push/rivium_push.dart';

/// Notification channels: the native SDKs pass `channelId` and the Console
/// channel's definition through to Dart.
void main() {
  test('channelId and channel come through from the native map and back', () {
    final m = RiviumPushMessage.fromMap({
      'title': 't',
      'body': 'b',
      'channelId': 'offers',
      'channel': {'id': 'offers', 'v': 2, 'importance': 'low', 'vibrate': false, 'sound': 'none', 'ios': 'passive'},
    });
    expect(m.channelId, 'offers');
    expect(m.channel?['vibrate'], false);
    final back = RiviumPushMessage.fromMap(m.toMap());
    expect(back.channelId, 'offers');
    expect(back.channel?['v'], 2);
  });

  test('messages without a channel are unchanged', () {
    final m = RiviumPushMessage.fromMap({'title': 't', 'body': 'b'});
    expect(m.channelId, isNull);
    expect(m.channel, isNull);
    expect(m.toMap().containsKey('channelId'), isFalse);
  });
}
