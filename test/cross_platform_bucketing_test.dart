// Cross-platform consistency tests driven by:
//   internal-docs/percentage-bucketing-test-vectors.csv
//
// To port to a new SDK: copy the CSV and write equivalent test logic.
// Canonical spec: internal-docs/SDK-PERCENTAGE-BUCKETING.md

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:configbee_flutter/src/utils/percentage_bucketing.dart';

void main() {
  group('cross-platform consistency — 1000 samples (500 VISITOR + 500 ASSIGNMENT)', () {
    final csvPath = '${Directory.current.path}/../internal-docs/percentage-bucketing-test-vectors.csv';
    final lines = File(csvPath).readAsLinesSync().skip(1); // skip header

    for (final line in lines) {
      final parts = line.split(',');
      final mode = parts[0];
      final input = parts[1];
      final salt = parts[2];
      final expectedHash = int.parse(parts[3]);
      final minPct = double.parse(parts[4]);

      test('$mode $input → hash=$expectedHash minPct=$minPct%', () {
        expect(djb2Hash(input + ':' + salt).toUnsigned(32), expectedHash);
        expect(isInPercentageBucket(input, minPct - 0.0001, salt: salt), false);
        expect(isInPercentageBucket(input, minPct, salt: salt), true);
        expect(isInPercentageBucket(input, 100, salt: salt), true);
        expect(isInPercentageBucket(input, 0, salt: salt), false);
      });
    }
  });
}
