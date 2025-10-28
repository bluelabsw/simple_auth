import 'dart:async';
import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as p;
import 'package:simple_auth_generator/src/generator.dart';
import 'package:source_gen/source_gen.dart';

import '../test/analysis_utils.dart';
import '../test/test_file_utils.dart';

Future<void> main() async {
  final targets = <String>[
    'MyServiceDefinition',
    'MyApiKeyDefinition',
    'MyBasicAuthApiDefinition',
    'MyOAuthApiDefinition',
    'MyOAuthApiKeyApiDefinition',
    'GoogleTestDefinition',
    'YouTubeApiDefinition',
    'AzureADDefinition',
    'AmazonDefinition',
    'DropboxDefinition',
    'FacebookDefinition',
    'GithubDefinition',
    'InstagramDefinition',
    'LinkedInDefinition',
    'MicrosoftLiveDefinition',
  ];

  final library = await resolveCompilationUnit(testFilePath('test', 'test_apis'));
  final generator = SimpleAuthGenerator();
  final formatter = DartFormatter();
  final goldensDir = Directory(testFilePath('test', 'goldens'));
  goldensDir.createSync(recursive: true);

  for (final name in targets) {
    final element = library.allElements.singleWhere((e) => e.name == name);
    final annotation = generator.typeChecker.firstAnnotationOf(element);
    final generated = await generator.generateForAnnotatedElement(
      element,
      ConstantReader(annotation),
      null,
    );
    final output = formatter.format(generated);
    final file = File(p.join(goldensDir.path, '$name.txt'));
    file.writeAsStringSync(output);
    print('Wrote ${file.path}');
  }
}
