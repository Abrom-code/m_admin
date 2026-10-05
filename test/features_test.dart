import 'package:flutter_test/flutter_test.dart';
import 'package:m_admin/features/payments/models/payment_review.dart';

void main() {
  group('PaymentMethodInfo normalization & labels', () {
    test('resolves canonical and prefixed payment method keys', () {
      expect(PaymentMethodInfo.labelOf('cbe'), equals('CBE'));
      expect(PaymentMethodInfo.labelOf('payment_cbe_birr'), equals('CBE'));
      expect(PaymentMethodInfo.labelOf('cbe_birr'), equals('CBE'));

      expect(PaymentMethodInfo.labelOf('telebirr'), equals('Telebirr'));
      expect(PaymentMethodInfo.labelOf('payment_telebirr'), equals('Telebirr'));

      expect(PaymentMethodInfo.labelOf('abyssinia'), equals('Abyssinia'));
      expect(PaymentMethodInfo.labelOf('payment_abyssinia'), equals('Abyssinia'));

      expect(PaymentMethodInfo.labelOf('mpesa'), equals('M-Pesa'));
      expect(PaymentMethodInfo.labelOf('payment_mpesa'), equals('M-Pesa'));

      expect(PaymentMethodInfo.labelOf(''), equals('Unknown'));
    });

    test('normalizeKey handles variations correctly', () {
      expect(PaymentMethodInfo.normalizeKey('payment_cbe_birr'), equals('cbe'));
      expect(PaymentMethodInfo.normalizeKey('payment_telebirr'), equals('telebirr'));
      expect(PaymentMethodInfo.normalizeKey('CBE'), equals('cbe'));
    });

    test('filterableMethods contains valid options', () {
      expect(PaymentMethodInfo.filterableMethods.length, equals(4));
      expect(PaymentMethodInfo.filterableMethods.map((m) => m.key), containsAll(['telebirr', 'cbe', 'abyssinia', 'mpesa']));
    });
  });
}
