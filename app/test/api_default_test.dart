import 'package:alienmatch/api/api.dart';
import 'package:flutter_test/flutter_test.dart';

// Regression: a release build pointed at localhost and could not create an account.
void main() {
  test('builds without --dart-define talk to production', () {
    expect(apiBaseUrl, 'https://aliens.ol1n.com');
  });
}
