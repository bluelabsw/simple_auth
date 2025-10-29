import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

/// A web implementation of the SimpleAuthFlutter plugin.
class SimpleAuthFlutterWeb {
  static String? _initialUrl;
  static StreamController<Map<Object?, Object?>>? _controller;
  static final Map<String, String> _inMemoryStore = <String, String>{};

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
      case 'saveKey':
        return _handleSaveKey(call.arguments);
      case 'getValue':
        return _handleGetValue(call.arguments);
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details:
              'simple_auth_flutter for web doesn\'t implement \'${call.method}\'',
        );
    }
  }

  dynamic _handleSaveKey(Map<Object?, Object?>? arguments) {
    final key = arguments?['key'] as String?;
    final value = arguments?['value'] as String?;
    if (key == null || key.isEmpty) {
      throw PlatformException(
        code: 'invalid_arguments',
        message: 'Key cannot be null or empty.',
      );
    }

    try {
      final storage = web.window.localStorage;
      if (value == null || value.isEmpty) {
        storage.removeItem(key);
      } else {
        storage.setItem(key, value);
      }
    } catch (_) {
      // Ignore storage errors (e.g., privacy modes); fall back to in-memory cache.
    }

    if (value == null || value.isEmpty) {
      _inMemoryStore.remove(key);
    } else {
      _inMemoryStore[key] = value;
    }

    return 'success';
  }

  dynamic _handleGetValue(Map<Object?, Object?>? arguments) {
    final key = arguments?['key'] as String?;
    if (key == null || key.isEmpty) {
      return null;
    }

    try {
      final storage = web.window.localStorage;
      final storedValue = storage.getItem(key);
      if (storedValue != null) {
        _inMemoryStore[key] = storedValue;
        return storedValue;
      }
    } catch (_) {
      // Ignore storage errors; defer to in-memory fallback.
    }

    return _inMemoryStore[key];
  }

  /// Returns a [String] containing the version of the platform.
  Future<String> getPlatformVersion() {
    final version = web.window.navigator.userAgent;
    return Future.value(version);
  }
}
