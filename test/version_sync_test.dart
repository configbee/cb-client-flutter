import 'dart:io';

import 'package:configbee_flutter/src/sdk_version.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated sdkVersion matches pubspec.yaml version', () {
    final pubspecPath = '${Directory.current.path}/pubspec.yaml';
    final pubspec = File(pubspecPath).readAsStringSync();
    final versionMatch = RegExp(r'^version: (.+)$', multiLine: true).firstMatch(pubspec);
    final pubspecVersion = versionMatch!.group(1)!;

    expect(sdkVersion, pubspecVersion,
        reason: 'lib/src/sdk_version.g.dart is out of sync with pubspec.yaml. '
            'Run `tool/generate_version.sh` to regenerate it.');
  });
}
