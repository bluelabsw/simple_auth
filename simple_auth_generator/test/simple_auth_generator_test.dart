import 'dart:async';
import 'dart:io';
import 'dart:mirrors';

import 'package:dart_style/dart_style.dart' as dart_style;
import 'package:path/path.dart' as p;
import 'package:simple_auth_generator/src/generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

import 'analysis_utils.dart';
import 'test_apis/services.dart';
import 'test_file_utils.dart';

final _formatter = dart_style.DartFormatter();

String golden(String name) =>
    File(testFilePath('test', 'goldens', '$name.txt')).readAsStringSync();

String? _packagePathCache;
String? getPackagePath() {
  if (_packagePathCache == null) {
    // Getting the location of this file – via reflection
    var currentFilePath = (reflect(getPackagePath) as ClosureMirror)
        .function
        .location!
        .sourceUri
        .path;

    _packagePathCache = p.normalize(p.join(p.dirname(currentFilePath), '..'));
  }
  return _packagePathCache;
}

late LibraryReader _library;
void main() {
  setUpAll(() async {

  final path = testFilePath('test', 'test_apis');
  _library = await resolveCompilationUnit(path);
  });
  var generator = new SimpleAuthGenerator();

  Future<String> runForElementNamed(String name) async {
    final element = _library.allElements.singleWhere((e) => e.name == name);
    var annotation = generator.typeChecker.firstAnnotationOf(element);
    var generated = await generator.generateForAnnotatedElement(
        element, new ConstantReader(annotation), null);

    var output = _formatter.format(generated);
    printOnFailure(output);
    return output;
  }

  test('run generator for MyService', () async {
    var result = await runForElementNamed('$MyServiceDefinition');
    expect(result, golden('MyServiceDefinition'));
  });

  test('run generator for ApiKeyApi', () async {
    var result = await runForElementNamed('$MyApiKeyDefinition');
    expect(result, golden('MyApiKeyDefinition'));
  });
  test('run generator for BasicAuthApi', () async {
    var result = await runForElementNamed('$MyBasicAuthApiDefinition');
    expect(result, golden('MyBasicAuthApiDefinition'));
  });
  test('run generator for MyOAuthApiDefinition', () async {
    var result = await runForElementNamed('$MyOAuthApiDefinition');
    expect(result, golden('MyOAuthApiDefinition'));
  });
  test('run generator for MyOAuthApiKeyApiDefinition', () async {
    var result = await runForElementNamed('$MyOAuthApiKeyApiDefinition');
    expect(result, golden('MyOAuthApiKeyApiDefinition'));
  });

  test('run generator for GoogleTestDefinition', () async {
    var result = await runForElementNamed('$GoogleTestDefinition');
    expect(result, golden('GoogleTestDefinition'));
  });

  test('run generator for YouTube', () async {
    var result = await runForElementNamed('$YouTubeApiDefinition');
    expect(result, golden('YouTubeApiDefinition'));
  });

  test('run generator for AzureADDefinition', () async {
    var result = await runForElementNamed('$AzureADDefinition');
    expect(result, golden('AzureADDefinition'));
  });

  test('run generator for $AmazonDefinition', () async {
    var result = await runForElementNamed('$AmazonDefinition');
    expect(result, golden('AmazonDefinition'));
  });
  test('run generator for $DropboxDefinition', () async {
    var result = await runForElementNamed('$DropboxDefinition');
    expect(result, golden('DropboxDefinition'));
  });
  test('run generator for $FacebookDefinition', () async {
    var result = await runForElementNamed('$FacebookDefinition');
    expect(result, golden('FacebookDefinition'));
  });
  test('run generator for $GithubDefinition', () async {
    var result = await runForElementNamed('$GithubDefinition');
    expect(result, golden('GithubDefinition'));
  });
  test('run generator for $InstagramDefinition', () async {
    var result = await runForElementNamed('$InstagramDefinition');
    expect(result, golden('InstagramDefinition'));
  });
  test('run generator for $LinkedInDefinition', () async {
    var result = await runForElementNamed('$LinkedInDefinition');
    expect(result, golden('LinkedInDefinition'));
  });
  test('run generator for $MicrosoftLiveDefinition', () async {
    var result = await runForElementNamed('$MicrosoftLiveDefinition');
    expect(result, golden('MicrosoftLiveDefinition'));
  });
}
