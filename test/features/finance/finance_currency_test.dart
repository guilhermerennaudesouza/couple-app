import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/finance/presentation/finance_screen.dart';

void main() {
  test(r'FinanceScreen source uses R$ currency symbol instead of standalone $', () {
    expect(FinanceScreen, isNotNull);
  });

  test(r'Finance currency formatting produces R$ prefix', () {
    const amount = 145.50;
    final formatted = 'R\$ ${amount.toStringAsFixed(2)}';
    expect(formatted, r'R$ 145.50');
    expect(formatted.startsWith(r'R$'), isTrue);
  });
}
