import 'dart:math';

import 'package:alienmatch/features/onboarding/profile_steps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated nicknames are short and valid', () {
    final r = Random(1);
    final valid = RegExp(r'^[A-Za-z]{2}-\d{1,2}$');
    for (var i = 0; i < 200; i++) {
      final n = alienNickname(r);
      expect(n.length, lessThanOrEqualTo(12));
      expect(valid.hasMatch(n), isTrue, reason: n);
    }
  });
}
