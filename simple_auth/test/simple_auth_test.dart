import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:simple_auth/simple_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Keycloak password update', () {
    late KeycloakApi api;
    late MemoryAuthStorage storage;
    late OAuthAccount previous;
    late Completer<WebAuthenticator> presented;
    late int exchanges;
    late bool tokenFails;

    setUp(() {
      storage = MemoryAuthStorage();
      exchanges = 0;
      tokenFails = false;
      presented = Completer<WebAuthenticator>();
      api = KeycloakApi('keycloak', 'eden-app', '', 'eden://callback',
          'https://auth.example.com', 'bluelab',
          scopes: ['openid', 'profile', 'offline_access'],
          authStorage: storage, client: MockClient((request) async {
        exchanges++;
        if (tokenFails) {
          return http.Response('{"error":"invalid_grant"}', 400);
        }
        expect(request.url.path,
            '/auth/realms/bluelab/protocol/openid-connect/token');
        final body = Uri.splitQueryString(request.body);
        expect(body['code'], 'new-code');
        expect(body['redirect_uri'], 'eden://callback');
        return http.Response(
            jsonEncode({
              'access_token': 'new-token',
              'refresh_token': 'new-refresh',
              'token_type': 'Bearer',
              'expires_in': 300,
            }),
            200);
      }));
      previous = OAuthAccount('keycloak',
          token: 'old-token',
          refreshToken: 'old-refresh',
          expiresIn: 300,
          created: DateTime.now().toUtc());
      api.currentAccount = previous;
      api.showAuthenticator = (authenticator) {
        presented.complete(authenticator);
      };
    });

    test('opens with a valid session and exchanges duplicate callbacks once',
        () async {
      final pending = api.updatePassword();
      final concurrent = api.updatePassword();
      final action = await presented.future;
      final initial = await action.getInitialUrl();
      expect(initial.queryParameters['kc_action'], 'UPDATE_PASSWORD');
      expect(initial.queryParameters['redirect_uri'], 'eden://callback');
      expect(initial.queryParameters['scope'], 'openid profile offline_access');
      expect(action.useEmbeddedBrowser, isTrue);
      expect(exchanges, 0);
      expect(api.currentAccount, same(previous));
      final callback =
          Uri.parse('eden://callback?code=new-code&kc_action_status=success');
      expect(action.checkUrl(callback), isTrue);
      expect(action.checkUrl(callback), isFalse);
      final account = await pending;
      expect(await concurrent, same(account));
      expect(account?.token, 'new-token');
      expect(api.currentAccount, same(account));
      expect(jsonDecode(storage.values['keycloak']!)['refreshToken'],
          'new-refresh');
      expect(exchanges, 1);
      expect(
          (api.getAuthenticator() as WebAuthenticator)
              .getInitialUrlQueryParameters(),
          completion(isNot(contains('kc_action'))));
    });

    test('browser cancellation preserves session and allows another attempt',
        () async {
      final pending = api.updatePassword();
      final action = await presented.future;
      action.cancel();
      action.cancel();
      expect(await pending, isNull);
      expect(api.currentAccount, same(previous));
      expect(storage.values, isEmpty);
      expect(exchanges, 0);
      presented = Completer<WebAuthenticator>();
      final retry = api.updatePassword();
      (await presented.future).cancel();
      expect(await retry, isNull);
    });

    test('Keycloak cancellation does not exchange a returned code', () async {
      final pending = api.updatePassword();
      final action = await presented.future;
      expect(
          action.checkUrl(Uri.parse(
              'eden://callback?code=new-code&kc_action_status=cancelled')),
          isTrue);
      expect(await pending, isNull);
      expect(api.currentAccount, same(previous));
      expect(exchanges, 0);
    });

    test('OAuth error completes without clearing the account', () async {
      final pending = api.updatePassword();
      final failure = expectLater(pending, throwsException);
      final action = await presented.future;
      expect(action.checkUrl(Uri.parse('eden://callback?error=server_error')),
          isTrue);
      await failure;
      expect(api.currentAccount, same(previous));
      expect(exchanges, 0);
    });

    test('rejects callbacks with a different scheme or path', () async {
      final pending = api.updatePassword();
      final action = await presented.future;
      expect(action.checkUrl(Uri.parse('https://callback?code=new-code')),
          isFalse);
      expect(action.checkUrl(Uri.parse('eden://callback/other?code=new-code')),
          isFalse);
      action.cancel();
      expect(await pending, isNull);
      expect(exchanges, 0);
    });

    test('token failure preserves the current and cached account', () async {
      tokenFails = true;
      await api.saveAccountToCache(previous);
      final cached = storage.values['keycloak'];
      final pending = api.updatePassword();
      final failure = expectLater(pending, throwsA(isA<StateError>()));
      (await presented.future)
          .checkUrl(Uri.parse('eden://callback?code=new-code'));
      await failure;
      expect(api.currentAccount, same(previous));
      expect(storage.values['keycloak'], cached);
    });
  });

  test('serializes object lists to json and deserializes to json ', () async {
    var convert = new ModelConverter();
    final respStart = new Resource("id2", "foo from resource 2");
    final respStart2 = new Resource("id2", "foo from resource 1");
    var json = await convert.encode(new Request("get", "foo",
        body: new List.from([respStart, respStart2])));
    var decoded = await convert.decode(
        new Response(new http.Response(json.body, 200), null), Resource, true);
    var newJson =
        await convert.encode(new Request("get", "foo", body: decoded.body));
    expect(json.body, newJson.body);
  });
}

class MemoryAuthStorage implements AuthStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read({String? key}) async => values[key];

  @override
  Future<void> write({String? key, required String value}) async {
    values[key!] = value;
  }
}

class Resource2 implements JsonSerializable {
  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };
  final String? id;
  final String? name;
  Resource2(this.id, this.name);

  @override
  factory Resource2.fromJson(Map<String, dynamic> json) =>
      new Resource2(json['id'], json['name']);
}

class Resource {
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };
  final String? id;
  final String? name;
  Resource(this.id, this.name);

  factory Resource.fromJson(Map<String, dynamic> json) =>
      new Resource(json['id'], json['name']);
}

class ModelConverter extends JsonConverter {
  @override
  Future<Response> decode(
      Response response, Type responseType, bool responseIsList) async {
    final d = await super.decode(response, responseType, responseIsList);
    var body = d.body;

    if (responseType == Resource) {
      body = responseIsList && body is List
          ? new List.from(
              body.map((f) => new Resource.fromJson(f as Map<String, dynamic>)))
          : new Resource.fromJson(d.body as Map<String, dynamic>);
    } else if (responseType == Resource2) {
      body = new Resource2.fromJson(body as Map<String, dynamic>);
    }
    return new Response(response.base, body);
  }
}
