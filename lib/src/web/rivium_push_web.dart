// Web side of the plugin: answers the same channel as Android and iOS, and
// drives the Rivium Push Web SDK (bundled as assets/web/rivium-push-web.js, so
// apps load nothing from a CDN). The Dart API in rivium_push.dart is unchanged.
//
// Messages arrive over Rivium's real-time connection while the page is open.
// With `webPush: true` (opt-in), the Rivium Push service worker also receives
// them through the browser's Web Push while the app is closed. It is registered
// under its own scope (`rivium-push/`), so Flutter's service worker at the root
// is never replaced.
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

const _channelName = 'co.rivium.push/main';
const _scriptAsset = 'packages/rivium_push/assets/web/rivium-push-web.js';

/// The JS SDK's instance (`new RiviumPush.RiviumPush(config)`).
extension type _Sdk(JSObject _) implements JSObject {
  external JSPromise<JSString> register(JSObject options);
  external JSPromise<JSAny?> unregister();
  external JSPromise<JSAny?> subscribeTopic(String topic);
  external JSPromise<JSAny?> unsubscribeTopic(String topic);
  external JSPromise<JSAny?> setUserId(String userId);
  external JSPromise<JSAny?> clearUserId();
  external void setUserToken(String? token);
  external void setTokenProvider(JSFunction? provider);
  external void setLogLevel(int level);
  external bool isConnected();
  external String? getDeviceId();
  external String? getSubscriptionId();
  external String? getWebPushStatus();
  external JSPromise<JSAny?> prepareWebPush();
  external JSObject? getInitialMessage();
  external int getBadgeCount();
  external void setBadgeCount(int count);
  external void clearBadge();
  external JSFunction onMessage(JSFunction callback);
  external JSFunction onConnectionState(JSFunction callback);
  external JSFunction onRegistered(JSFunction callback);
  external JSFunction onError(JSFunction callback);
  external JSFunction onAuthError(JSFunction callback);
  external JSFunction onNotificationClick(JSFunction callback);
}

class RiviumPushWeb {
  RiviumPushWeb(this._channel);

  final MethodChannel _channel;
  _Sdk? _sdk;
  Future<void>? _preparing;
  bool _useTokenProvider = false;
  static Future<void>? _loading;

  static void registerWith(Registrar registrar) {
    final channel = MethodChannel(_channelName, const StandardMethodCodec(), registrar);
    final plugin = RiviumPushWeb(channel);
    channel.setMethodCallHandler(plugin._handle);
  }

  Future<dynamic> _handle(MethodCall call) async {
    final args = call.arguments is Map ? (call.arguments as Map).cast<String, dynamic>() : const <String, dynamic>{};
    switch (call.method) {
      case 'init':
        return _init(args);
      case 'setTokenProvider':
        _useTokenProvider = args['enabled'] == true;
        _sdk?.setTokenProvider(_useTokenProvider ? _tokenProvider.toJS : null);
        return null;
      case 'setUserToken':
        _sdk?.setUserToken(args['token'] as String?);
        return null;
      case 'register':
        final sdk = _required();
        // A worker still being prepared (page just loaded): let it finish, so the subscription comes first.
        await _preparing;
        final options = JSObject();
        final userId = args['userId'] as String?;
        if (userId != null) options['userId'] = userId.toJS;
        final metadata = args['metadata'];
        if (metadata is Map) {
          // The Web SDK keeps metadata as strings.
          options['metadata'] = {for (final e in metadata.entries) '${e.key}': '${e.value}'}.jsify();
        }
        await sdk.register(options).toDart;
        return null;
      case 'unregister':
        await _sdk?.unregister().toDart;
        return null;
      case 'subscribeTopic':
        await _required().subscribeTopic(args['topic'] as String).toDart;
        return null;
      case 'unsubscribeTopic':
        await _required().unsubscribeTopic(args['topic'] as String).toDart;
        return null;
      case 'setUserId':
        await _required().setUserId(args['userId'] as String).toDart;
        return null;
      case 'clearUserId':
        await _sdk?.clearUserId().toDart;
        return null;
      case 'setLogLevel':
        _sdk?.setLogLevel(_logLevel(args['level'] as String?));
        return null;
      case 'isConnected':
        return _sdk?.isConnected() ?? false;
      case 'getDeviceId':
        return _sdk?.getDeviceId();
      case 'getSubscriptionId':
        return _sdk?.getSubscriptionId();
      case 'getWebPushStatus':
        return _sdk?.getWebPushStatus();
      case 'getInitialMessage':
        return _toMap(_sdk?.getInitialMessage());
      case 'getBadgeCount':
        return _sdk?.getBadgeCount() ?? 0;
      case 'setBadgeCount':
        _sdk?.setBadgeCount((args['count'] as num?)?.toInt() ?? 0);
        return null;
      case 'clearBadge':
        _sdk?.clearBadge();
        return null;
      default:
        // Android/iOS features (notification channels, VoIP, battery settings,
        // the native inbox and in-app caches) have no web counterpart here.
        // Getters answer null, which the Dart API reads as "nothing".
        return null;
    }
  }

  Future<void> _init(Map<String, dynamic> config) async {
    if (_sdk != null) return;
    await _loadScript();
    final namespace = globalContext['RiviumPush'] as JSObject?;
    final constructor = namespace?['RiviumPush'] as JSFunction?;
    if (constructor == null) {
      throw PlatformException(code: 'web_sdk_missing', message: 'The Rivium Push Web SDK did not load');
    }
    final webPush = config['webPush'] == true && await _workerAvailable();
    final options = JSObject()
      ..['apiKey'] = (config['apiKey'] as String).toJS
      ..['autoRegisterServiceWorker'] = webPush.toJS
      ..['autoRefresh'] = (config['autoRefresh'] != false).toJS;
    if (webPush) {
      options['serviceWorkerPath'] = _appPath(_workerFile).toJS;
      options['serviceWorkerScope'] = _appPath(config['webPushAtRoot'] == true ? '' : _workerScope).toJS;
    }
    if (_useTokenProvider) options['tokenProvider'] = _tokenProvider.toJS;
    final sdk = _Sdk(constructor.callAsConstructor<JSObject>(options));
    sdk.onMessage(((JSObject message) {
      _send('onMessage', _toMap(message));
    }).toJS);
    // One parameter: the Web SDK calls this with (message) for a page notification and (message, action) from a
    // service worker. A Dart function given to JS keeps its exact arity, so a second parameter would fail the
    // one-argument call; an extra argument to a one-parameter function is simply dropped.
    sdk.onNotificationClick(((JSObject message) {
      _send('onNotificationTapped', _toMap(message));
    }).toJS);
    sdk.onConnectionState(((JSString state) {
      _send('onConnectionState', state.toDart == 'connected');
    }).toJS);
    sdk.onRegistered(((JSString deviceId) {
      _send('onRegistered', deviceId.toDart);
    }).toJS);
    sdk.onError(((JSObject error) {
      _send('onError', (error['message'] as JSString?)?.toDart ?? 'error');
    }).toJS);
    sdk.onAuthError(((JSObject event) {
      _send('onAuthError', {
        'code': (event['code'] as JSString?)?.toDart ?? '',
        'message': (event['message'] as JSString?)?.toDart ?? 'Authentication failed',
      });
    }).toJS);
    _sdk = sdk;
    // Web Push: register the worker now and let it become active, so register() from a tap can subscribe at once
    // (Safari on iPhone accepts a subscription only right after the tap).
    if (webPush) {
      _preparing = sdk.prepareWebPush().toDart.then((_) {}, onError: (_) {});
    }
  }

  /// The JS SDK asks for the user token; the app's tokenProvider answers on
  /// the Dart side (the same `getUserToken` call the native SDKs make).
  JSPromise<JSString?> _tokenProvider() => (() async {
        final token = await _channel.invokeMethod<String>('getUserToken');
        return token?.toJS;
      })()
          .toJS;

  _Sdk _required() {
    final sdk = _sdk;
    if (sdk == null) {
      throw PlatformException(code: 'not_initialized', message: 'Call RiviumPush.init() first');
    }
    return sdk;
  }

  void _send(String method, Object? arguments) {
    unawaited(_channel.invokeMethod<void>(method, arguments).catchError((_) {}));
  }

  static Map<String, dynamic>? _toMap(JSObject? message) {
    if (message == null) return null;
    final value = message.dartify();
    return value is Map ? value.map((k, v) => MapEntry('$k', v)) : null;
  }

  static int _logLevel(String? name) => switch (name) {
        'none' => 0,
        'error' => 1,
        'warning' => 2,
        'info' => 3,
        'debug' => 4,
        'verbose' => 5,
        _ => 1,
      };

  /// Loads the bundled Web SDK once, from the app's own assets.
  static const _workerFile = 'rivium-push-sw.js';
  static const _workerScope = 'rivium-push/';

  /// [relative] under the app's base address (`<base href>`), as a path.
  static String _appPath(String relative) {
    final document = globalContext['document'] as JSObject;
    final base = (document['baseURI'] as JSString?)?.toDart ?? '/';
    return Uri.parse(base).resolve(relative).path;
  }

  /// The worker file is served next to index.html (`dart run rivium_push:web_push_setup` puts it in web/). Without
  /// it, Web Push stays off and the app works as before; registering a missing worker would fail register().
  static Future<bool> _workerAvailable() async {
    try {
      final response = await globalContext
          .callMethod<JSPromise<JSObject>>('fetch'.toJS, _appPath(_workerFile).toJS, {'method': 'HEAD', 'cache': 'no-store'}.jsify())
          .toDart;
      if ((response['ok'] as JSBoolean?)?.toDart == true) return true;
    } catch (_) {
      // Offline or blocked: treated as missing.
    }
    (globalContext['console'] as JSObject?)?.callMethod<JSAny?>(
      'warn'.toJS,
      'Rivium Push: webPush is on but $_workerFile was not found next to index.html. Run `dart run rivium_push:web_push_setup` in the app folder. Web Push stays off.'.toJS,
    );
    return false;
  }

  static Future<void> _loadScript() {
    if (globalContext['RiviumPush'] != null) return Future.value();
    return _loading ??= () {
      final done = Completer<void>();
      final document = globalContext['document'] as JSObject;
      final script = document.callMethod<JSObject>('createElement'.toJS, 'script'.toJS);
      script['src'] = ui_web.assetManager.getAssetUrl(_scriptAsset).toJS;
      script['async'] = true.toJS;
      script['onload'] = ((JSAny? _) => done.complete()).toJS;
      script['onerror'] = ((JSAny? _) {
        _loading = null;
        done.completeError(PlatformException(code: 'web_sdk_missing', message: 'Could not load $_scriptAsset'));
      }).toJS;
      (document['head'] as JSObject).callMethod<JSAny?>('appendChild'.toJS, script);
      return done.future;
    }();
  }
}
