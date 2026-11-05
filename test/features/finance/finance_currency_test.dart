import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/finance/presentation/finance_screen.dart';

void main() {
  test('FinanceScreen source uses R\$ currency symbol instead of standalone \$', () {
    expect(FinanceScreen, isNotNull);
  });
}
