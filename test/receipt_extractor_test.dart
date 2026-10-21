import 'package:flutter_test/flutter_test.dart';
import 'package:m_admin/data/services/receipt_extractor_service.dart';

void main() {
  group('ReceiptTextParser Tests', () {
    test('extracts CBE sample receipt correctly (FT26291KVDWY, 18/10/2026, 400.61 ETB)', () {
      // User's exact CBE sample text from screenshot
      const cbeSampleText = '''
Completed ETB400.61 transfer From Abrham Teramed Nega to Negawo Abu Neme-6782. To ads on 18/10/2026 FT26291KVDWY Service Charge ETB0.61 VAT(15%) ETB0.08 1:Back
''';

      final res = ReceiptTextParser.parse(cbeSampleText);

      expect(res.transactionId, equals('FT26291KVDWY'));
      expect(res.date, equals('18/10/2026'));
      expect(res.amount, equals(400.61));
      expect(res.senderName, equals('Abrham Teramed Nega'));
      expect(res.receiverAccount, contains('Negawo Abu Neme-6782'));
      expect(res.bank, equals('cbe'));
      expect(res.hasTransactionId, isTrue);
    });

    test('extracts Telebirr sample receipt correctly (DJL64F9ZOE, 2026/10/21 07:56:12, 203.00 ETB)', () {
      // User's exact Telebirr sample text from screenshot (Afaan Oromo confirmation slip)
      const telebirrSampleText = '''
Milkaa'eera
Mala kaffaltii
-203.00 (ETB)
Lakkoofsa Kaffaltii    DJL64F9ZOE
yeroo daddabarsaa:     2026/10/21 07:56:12
Gosa daddabarsaa:      Baankiitti dabarsuuf
Kan raawwateef:        ABRHAM TERAMED NEGA
Lakkoofsa herrega baankii: 165093089
Maqaa Baanki:          Baanki Absiiniyaa
Payment QR Code
''';

      final res = ReceiptTextParser.parse(telebirrSampleText);

      expect(res.transactionId, equals('DJL64F9ZOE'));
      expect(res.date, equals('2026/10/21 07:56:12'));
      expect(res.amount, equals(203.00));
      expect(res.senderName, equals('ABRHAM TERAMED NEGA'));
      expect(res.receiverAccount, equals('165093089'));
      expect(res.bank, equals('telebirr'));
      expect(res.hasTransactionId, isTrue);
      expect(res.parsedDate, isNotNull);
      expect(res.parsedDate!.year, equals(2026));
      expect(res.parsedDate!.month, equals(10));
      expect(res.parsedDate!.day, equals(21));
    });

    test('extracts English Telebirr receipt correctly', () {
      const englishTelebirr = '''
Successful
Payment Details
-500.00 ETB
Transaction No: DET8FJGUJ4
Date & Time: 2026-10-19 14:22:05
Paid to: MatricMate
Account: 0960586811
''';

      final res = ReceiptTextParser.parse(englishTelebirr, bankHint: 'telebirr');

      expect(res.transactionId, equals('DET8FJGUJ4'));
      expect(res.amount, equals(500.0));
      expect(res.bank, equals('telebirr'));
      expect(res.hasTransactionId, isTrue);
    });

    test('extracts Amharic Telebirr receipt correctly', () {
      const amharicTelebirr = '''
ተሳክቷል
-300.00 ብር
የግብይት ቁጥር: DA71K9XLP2
የተፈጸመበት ጊዜ: 2026/10/18 11:30:15
ለ: አብርሃም ተራመድ
''';

      final res = ReceiptTextParser.parse(amharicTelebirr);

      expect(res.transactionId, equals('DA71K9XLP2'));
      expect(res.amount, equals(300.0));
      expect(res.bank, equals('telebirr'));
      expect(res.hasTransactionId, isTrue);
    });

    test('extracts CBE SMS receipt with multi-line wrapped link, amount, sender and receiver', () {
      const cbeSmsSample = '''
CBE
Unread
Dear Tigist Getnet Sharew
You have successfully
transferred ETB200.00 from
account 1********7871 to
account 1********1237
(Abrham Teramed Nega).
Service charge of ETB 0.50
and VAT(15%) of ETB0.08
and Disaster Recovery(5%)
of 0.03 with total of
ETB200.61 .Your current
balance is ETB88.72. Thanks
for Banking with CBE.
https://mreciept.cbe.com.et
/v2
/-hfHCxHMBDDeLLF7MLsuaD
for feedback:
https://forms.gle
/kGNGQpG3mQCCk3iD6
• ethio telecom
''';

      final res = ReceiptTextParser.parse(cbeSmsSample);

      expect(res.bank, equals('cbe'));
      expect(res.receiptUrl, equals('https://mreciept.cbe.com.et/v2/-hfHCxHMBDDeLLF7MLsuaD'));
      expect(res.transactionId, equals('https://mreciept.cbe.com.et/v2/-hfHCxHMBDDeLLF7MLsuaD'));
      expect(res.hasTransactionId, isTrue);
      expect(res.amount, equals(200.0));
      expect(res.senderName, equals('Tigist Getnet Sharew'));
      expect(res.receiverAccount, equals('1********1237'));
      expect(res.receiverName, equals('Abrham Teramed Nega'));
    });

    test('extracts CBE SMS single-line receipt link and standard spelling (mreceipt)', () {
      const singleLineCbe = '''
Dear Abebe Bikila You have successfully transferred ETB500.00 from account 10001 to account 10002 (Acme Trading).
Thanks for Banking with CBE.
https://mreceipt.cbe.com.et/v2/xyz9876543210
''';

      final res = ReceiptTextParser.parse(singleLineCbe);

      expect(res.bank, equals('cbe'));
      expect(res.receiptUrl, equals('https://mreceipt.cbe.com.et/v2/xyz9876543210'));
      expect(res.transactionId, equals('https://mreceipt.cbe.com.et/v2/xyz9876543210'));
      expect(res.amount, equals(500.0));
      expect(res.senderName, equals('Abebe Bikila'));
      expect(res.receiverAccount, equals('10002'));
      expect(res.receiverName, equals('Acme Trading'));
    });
  });
}
