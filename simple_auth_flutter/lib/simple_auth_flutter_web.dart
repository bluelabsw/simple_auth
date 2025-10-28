import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

/// A web implementation of the SimpleAuthFlutter plugin.
class SimpleAuthFlutterWeb {
  static String? _initialUrl;
  static StreamController<Map<Object?, Object?>>? _controller;

  static void registerWith(Registrar registrar) {
    final MethodChannel channel = MethodChannel(
      'simple_auth_flutter/showAuthenticator',
      const StandardMethodCodec(),
      registrar,
    );

    final pluginInstance = SimpleAuthFlutterWeb();
    // channel.setMethodCallHandler(pluginInstance.handleMethodCall);
    channel.setMethodCallHandler(pluginInstance.handleMethodCall);

    final PluginEventChannel<Map<Object?, Object?>> sendingChannel =
        PluginEventChannel<Map<Object?, Object?>>(
            'simple_auth_flutter/urlChanged',
            const StandardMethodCodec(),
            registrar);

    _controller = StreamController<Map<Object?, Object?>>();
    sendingChannel.setController(_controller);
    _initialUrl = web.window.location.href;
  }

  /// Handles method calls over the MethodChannel of this plugin.
  /// Note: Check the "federated" architecture for a new way of doing this:
  /// https://flutter.dev/go/federated-plugins
  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'getPlatformVersion':
        return getPlatformVersion();
      case 'initAuthenticator':
        var redirectUrl = call.arguments['redirectUrl'];
        if (redirectUrl != null &&
            Uri.parse(redirectUrl).path == Uri.parse(_initialUrl!).path) {
          _controller!.add({
            "identifier": call.arguments['identifier'],
            "url": _initialUrl,
            "forceComplete": true,
            "description": ""
          });
        } else {
          web.window.location.replace(
              call.arguments['initialUrl'].toString() + "&prompt=none");
        }
        return true;
      case 'showAuthenticator':
        web.window.location.replace(call.arguments['initialUrl'].toString());
        return "code";
      case 'completed':
        return true;
      case 'cancelled':
        _controller!.add({
          "identifier": call.arguments['identifier'],
          "url": "canceled",
          "forceComplete": false,
          "description": ""
        });
        return true;
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details:
              'simple_auth_flutter for web doesn\'t implement \'${call.method}\'',
        );
    }
  }

  /// Returns a [String] containing the version of the platform.
  Future<String> getPlatformVersion() {
    final version = web.window.navigator.userAgent;
    return Future.value(version);
  }
}
