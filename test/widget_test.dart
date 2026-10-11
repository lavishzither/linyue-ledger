import 'package:flutter_test/flutter_test.dart';
import 'package:qingshuang_ledger/core/theme/frost_theme.dart';

void main() {
  test('Frost palette is cool-toned', () {
    expect(FrostColors.bgBase.a, greaterThan(0));
    expect(FrostColors.accentIce.blue, greaterThan(FrostColors.accentIce.red));
  });
}
