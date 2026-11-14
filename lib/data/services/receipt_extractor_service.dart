import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:m_admin/data/services/verify_et_service.dart';
import 'package:m_admin/utils/helpers/ethiopian_time_helper.dart';

/// The extracted fields from a CBE, Telebirr, or Ethiopian bank receipt.
class ReceiptExtractionResult {
  const ReceiptExtractionResult({
    this.transactionId,
    this.receiptUrl,
    this.date,
    this.parsedDate,
    this.amount,
    this.currency = 'ETB',
    this.senderName,
    this.senderAccount,
    this.receiverAccount,
    this.receiverName,
    this.bank,
    this.rawText = '',
    this.source = 'ocr',
    this.isUssdReceipt = false,
  });

  /// The primary extracted transaction reference (e.g. "FT26291KVDWY" or "DJL64F9ZOE" or CBE link).
  final String? transactionId;

  /// The official receipt link (e.g. "https://mreciept.cbe.com.et/v2/-hfHCxHMBDDeLLF7MLsuaD").
  final String? receiptUrl;

  /// The date string as extracted from the receipt (e.g. "18/10/2026" or "2026/10/21 07:56:12").
  final String? date;

  /// Parsed DateTime if a valid date format was detected.
  final DateTime? parsedDate;

  /// Extracted payment amount.
  final double? amount;

  /// Currency code (defaults to 'ETB').
  final String currency;

  /// Sender name if detected.
  final String? senderName;

  /// Sender / debited account number if detected (e.g. from BOA USSD "debited from 178635107").
  final String? senderAccount;

  /// Receiver account number or phone if detected.
  final String? receiverAccount;

  /// Receiver beneficiary name if detected (e.g. from SMS "Abrham Teramed Nega").
  final String? receiverName;

  /// Detected or hinted bank key ('cbe', 'telebirr', 'boa', etc.).
  final String? bank;

  /// Full recognized text.
  final String rawText;

  /// Extraction method ('mlkit', 'links_et', or 'regex').
  final String source;

  /// Whether this was extracted from an interactive USSD flash message (*815# or *445# / 4455).
  final bool isUssdReceipt;

  bool get hasTransactionId =>
      (transactionId != null && transactionId!.trim().isNotEmpty) ||
      (receiptUrl != null && receiptUrl!.trim().isNotEmpty);

  /// The extracted token from the receipt link (e.g. "-hfHCxHMBDDeLLF7MLsuaD" or "fHCxyExampleRcpt1").
  String? get receiptToken {
    if (receiptUrl == null) return null;
    final uri = Uri.tryParse(receiptUrl!);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    return null;
  }

  ReceiptExtractionResult copyWith({
    String? transactionId,
    String? receiptUrl,
    String? date,
    DateTime? parsedDate,
    double? amount,
    String? currency,
    String? senderName,
    String? senderAccount,
    String? receiverAccount,
    String? receiverName,
    String? bank,
    String? rawText,
    String? source,
    bool? isUssdReceipt,
  }) {
    return ReceiptExtractionResult(
      transactionId: transactionId ?? this.transactionId,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      date: date ?? this.date,
      parsedDate: parsedDate ?? this.parsedDate,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      senderName: senderName ?? this.senderName,
      senderAccount: senderAccount ?? this.senderAccount,
      receiverAccount: receiverAccount ?? this.receiverAccount,
      receiverName: receiverName ?? this.receiverName,
      bank: bank ?? this.bank,
      rawText: rawText ?? this.rawText,
      source: source ?? this.source,
      isUssdReceipt: isUssdReceipt ?? this.isUssdReceipt,
    );
  }

  @override
  String toString() =>
      'ReceiptExtractionResult(txId: $transactionId, url: $receiptUrl, date: $date, amount: $amount, bank: $bank)';
}

/// Pattern matcher and parser designed specifically for Ethiopian payment receipts:
/// - CBE (Commercial Bank of Ethiopia: Mobile Banking, USSD, CBE Birr)
/// - Telebirr (Ethio Telecom: Afaan Oromo, English, Amharic confirmation slips)
/// - Bank of Abyssinia
class ReceiptTextParser {
  ReceiptTextParser._();

  /// Normalizes and cleans a CBE Funds Transfer (FT) code that may have OCR misrecognitions
  /// (e.g. 'FT26316CIJMB' -> 'FT26316C1JMB', where digit 1 is read as letter I/l/|, or 0 as O).
  static String normalizeCbeFtReference(String raw) {
    var s = raw.trim().toUpperCase().replaceAll(RegExp(r'[\s\-_.:/]'), '');
    if (!s.startsWith('FT') &&
        (s.startsWith('ET') ||
         s.startsWith('TT') ||
         s.startsWith('PT') ||
         s.startsWith('FI') ||
         s.startsWith('FL') ||
         s.startsWith('F1') ||
         s.startsWith('F|') ||
         s.startsWith('F7') ||
         s.startsWith('IT') ||
         s.startsWith('1T') ||
         s.startsWith('LT')) &&
        s.length >= 12) {
      s = 'FT${s.substring(2)}';
    }
    // Remove punctuation like periods or colons
    s = s.replaceAll(RegExp(r'[^A-Z0-9|!]'), '');
    if (!s.startsWith('FT')) return raw.trim();

    // CBE & BOA FT format:
    // Chars 0..1: 'FT'
    // Chars 2..3: 2-digit Year (e.g. '26')
    // Chars 4..6: 3-digit Julian Day (e.g. '316')
    // Chars 7..end: 5-6 alphanumeric characters (e.g. 'C1JMB')
    if (s.length >= 12) {
      final chars = s.substring(2).split('');

      // Positions 0..4 in 'chars' (chars 2..6 of FT code: Year + Julian Day) MUST BE DIGITS:
      for (int i = 0; i < 5 && i < chars.length; i++) {
        final c = chars[i];
        if (c == 'I' || c == 'L' || c == '|' || c == '!' || c == '/') {
          chars[i] = '1';
        } else if (c == 'O' || c == 'Q') {
          chars[i] = '0';
        } else if (c == 'S') {
          chars[i] = '5';
        } else if (c == 'B') {
          chars[i] = '8';
        } else if (c == 'Z') {
          chars[i] = '2';
        }
      }

      // Positions 5..end (the alphanumeric suffix):
      // In banking systems, 'I' (capital i) and 'O' (capital o) are NOT used in reference generation
      // to prevent confusion with digits 1 and 0.
      // Therefore, any OCR 'I', '|', '!' in suffix is digit '1', and 'O' is digit '0'.
      // Note: 'L' is a legitimate letter in T24 suffixes (e.g. FT26315BLDHF) and must NOT be replaced with 1.
      for (int i = 5; i < chars.length; i++) {
        final c = chars[i];
        if (c == 'I' || c == '|' || c == '!' || c == '/') {
          chars[i] = '1';
        } else if (c == 'O') {
          chars[i] = '0';
        }
      }

      return 'FT${chars.join('')}';
    }
    return s;
  }

  /// Parses raw OCR or SMS text to extract Transaction ID, Date, Amount, Sender, and Receiver.
  static ReceiptExtractionResult parse(String rawText, {String? bankHint}) {
    // Pre-process: stitch wrapped URL lines commonly split across newlines in mobile SMS receipts
    final clean = _stitchWrappedUrls(rawText.trim());
    if (clean.isEmpty) {
      return const ReceiptExtractionResult();
    }

    final normalizedHint = bankHint?.toLowerCase().trim() ?? '';

    // 1. Detect Bank: prioritize strong text indicators from image over an inaccurate hint
    final hasCoopIndicators = clean.contains('receipt.ebirr.com') ||
        clean.contains('coopay') ||
        clean.contains('Cooperative Bank of Oromia') ||
        clean.contains('Baankii Hojii Gamtaa Oromiyaa') ||
        clean.contains('Oromia Bank') ||
        clean.contains('Baankii Oromiyaa') ||
        clean.contains('CBO');

    final hasTelebirrIndicators = !hasCoopIndicators &&
        (clean.toLowerCase().contains('telebirr') ||
         clean.toLowerCase().contains('transactioninfo') ||
         clean.contains("Milkaa'eera") ||
         clean.contains('Mala kaffaltii') ||
         clean.contains('Lakkoofsa Kaffaltii') ||
         clean.contains('የግብይት ቁጥር'));

    final hasBoaIndicators = clean.toLowerCase().contains('self done via mobile') ||
        clean.toLowerCase().contains('bankofabyssinia') ||
        clean.contains('Abyssinia') ||
        clean.contains('Absiiniyaa') ||
        clean.contains('አቢሲኒያ') ||
        (!hasTelebirrIndicators && (clean.contains('165093089') || clean.contains('93089')));

    final hasCbeIndicators = clean.contains('4455') ||
        clean.contains('-1237') ||
        clean.contains('1000435011237') ||
        clean.contains('35011237') ||
        clean.contains('cbe.com.et') ||
        clean.contains('mreciept') ||
        clean.contains('mbreciept') ||
        clean.contains('Commercial Bank') ||
        clean.contains('CBE') ||
        RegExp(r'Completed\s+ETB', caseSensitive: false).hasMatch(clean);

    final isUssd = clean.toLowerCase().contains('self done via mobile') ||
        (clean.contains('4455') && clean.contains('Completed'));

    String detectedBank = normalizedHint;
    if (hasCoopIndicators) {
      detectedBank = 'coopayebirr';
    } else if (hasTelebirrIndicators && !hasCbeIndicators) {
      detectedBank = 'telebirr';
    } else if (hasBoaIndicators && !hasCbeIndicators && !hasTelebirrIndicators) {
      detectedBank = 'boa';
    } else if (hasCbeIndicators && !hasBoaIndicators) {
      detectedBank = 'cbe';
    } else if (hasBoaIndicators && hasCbeIndicators) {
      if (clean.contains('165093089')) {
        detectedBank = 'boa';
      } else if (clean.contains('1237') || clean.contains('4455')) {
        detectedBank = 'cbe';
      }
    } else if (detectedBank.isEmpty) {
      if (clean.contains('awashpay') ||
          clean.contains('Awash Bank') ||
          clean.contains('awashbank') ||
          clean.contains('Awash') ||
          clean.contains('Awaash') ||
          clean.contains('አዋሽ')) {
        detectedBank = 'awash';
      } else if (clean.toLowerCase().contains('dashen') ||
          clean.contains('ዳሽን') ||
          clean.contains('DASHEN')) {
        detectedBank = 'dashen';
      } else if (clean.contains('FT') ||
          RegExp(r'(?:FT|\bFT)[\s\-_]*[0-9A-Za-z|]{10,14}', caseSensitive: false).hasMatch(clean)) {
        detectedBank = 'cbe';
      }
    }

    final isTelebirrHint = detectedBank == 'telebirr';
    final isCbeHint = detectedBank == 'cbe';
    final isBoaHint = detectedBank == 'boa';
    final isAwashHint = detectedBank == 'awash';
    final isOromiaHint = detectedBank == 'coopayebirr';

    String? txId;
    String? receiptUrl;
    String? dateStr;
    DateTime? parsedDate;
    double? amount;
    String? sender;
    String? senderAccount;
    String? receiverAcc;
    String? receiverName;

    if (detectedBank == 'telebirr' || isTelebirrHint) {
      // ── TELEBIRR EXTRACTION ──
      // 1. Transaction ID:
      // Pattern 0: Full Telebirr portal URL (e.g. from QR code or receipt link)
      final teleUrlRegex = RegExp(
        r'(?:https?:\/\/)?transactioninfo\.ethiotelecom\.et\/receipt\/([A-Za-z0-9]{10})',
        caseSensitive: false,
      );
      final teleUrlMatch = teleUrlRegex.firstMatch(clean);
      if (teleUrlMatch != null) {
        txId = teleUrlMatch.group(1)!.toUpperCase();
        receiptUrl = 'https://transactioninfo.ethiotelecom.et/receipt/$txId';
      }

      // Pattern A: Labeled with Afaan Oromo, English, or Amharic
      if (txId == null) {
      final teleLabeledRegex = RegExp(
        r'(?:Lakkoofsa\s+Kaffaltii|Lakkoofsa\s+daddabarsaa|Transaction\s*(?:No|Number|ID|Code)|Payment\s*Code|የግብይት\s*ቁጥር|የሂሳብ\s*ቁጥር|የማረጋገጫ\s*ቁጥር)[\s:]*([A-Za-z0-9]{10})\b',
        caseSensitive: false,
      );
      final teleLabeledMatch = teleLabeledRegex.firstMatch(clean);
      if (teleLabeledMatch != null) {
        txId = teleLabeledMatch.group(1)?.toUpperCase();
      }
      }

      // Pattern B: Fallback to standard 10-char Telebirr code (e.g. DJL64F9ZOE, DET8FJGUJ4)
      if (txId == null) {
        final teleCodeRegex = RegExp(r'\b([D|C][A-Z0-9]{9})\b');
        final match = teleCodeRegex.firstMatch(clean);
        if (match != null) {
          txId = match.group(1);
        }
      }

      // Pattern C: Any isolated 10-char uppercase alphanumeric code
      if (txId == null) {
        final generic10Regex = RegExp(r'\b([A-Z0-9]{10})\b');
        for (final m in generic10Regex.allMatches(clean)) {
          final candidate = m.group(1)!;
          // Exclude phone numbers or all numeric strings
          if (RegExp(r'[A-Za-z]').hasMatch(candidate) &&
              RegExp(r'[0-9]').hasMatch(candidate)) {
            txId = candidate;
            break;
          }
        }
      }

      // Ensure txId is always the clean reference number, never a URL
      if (txId != null && txId.contains('http')) {
        final cleanTok = VerifyEtService.sanitizeTelebirrReference(txId);
        if (cleanTok.isNotEmpty && !cleanTok.startsWith('http')) {
          receiptUrl ??= txId;
          txId = cleanTok;
        }
      }

      // 2. Date:
      final teleDateRegex = RegExp(
        r'(?:yeroo\s+daddabarsaa|Date\s*(?:&|and)?\s*Time|Transaction\s*Time|Payment\s*Time|የተፈጸመበት\s*ጊዜ|ቀን)[\s:]*(\d{4}[/-]\d{1,2}[/-]\d{1,2}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?)',
        caseSensitive: false,
      );
      final teleDateMatch = teleDateRegex.firstMatch(clean);
      if (teleDateMatch != null) {
        dateStr = teleDateMatch.group(1)?.trim();
      } else {
        // Fallback: search for YYYY/MM/DD HH:mm:ss format
        final isoLikeMatch = RegExp(
          r'\b(\d{4}[/-]\d{1,2}[/-]\d{1,2}\s+\d{1,2}:\d{2}(?::\d{2})?)\b',
        ).firstMatch(clean);
        if (isoLikeMatch != null) {
          dateStr = isoLikeMatch.group(1)?.trim();
        }
      }

      // 3. Amount:
      final teleAmountMatch = RegExp(
        r'-?\s*([0-9,]+(?:\.[0-9]{1,2})?)\s*\(?(?:ETB|Birr|ብር)\)?',
        caseSensitive: false,
      ).firstMatch(clean);
      if (teleAmountMatch != null) {
        final rawNum = teleAmountMatch.group(1)!.replaceAll(',', '');
        amount = double.tryParse(rawNum);
      }

      // 4. Sender / Receiver:
      final teleReceiverMatch = RegExp(
        r'(?:Kan\s+raawwateef|Paid\s+to|Receiver)[\s:]*([A-Za-z\s]+?)(?:\n|\r|Lakkoofsa|$)',
        caseSensitive: false,
      ).firstMatch(clean);
      if (teleReceiverMatch != null) {
        sender = teleReceiverMatch.group(1)?.trim();
      }

      final teleAccMatch = RegExp(
        r'(?:Lakkoofsa\s+herrega\s+baankii|Account\s*No|Acc)[\s:]*([0-9]+)',
        caseSensitive: false,
      ).firstMatch(clean);
      if (teleAccMatch != null) {
        receiverAcc = teleAccMatch.group(1)?.trim();
      }
    } else if (detectedBank == 'awash' || isAwashHint) {
      // ── AWASH BANK EXTRACTION ──
      // 1. AwashPay Receipt URL
      final awashUrlRegex = RegExp(
        r'(https?:\/\/awashpay\.awashbank\.com(?::\d+)?\/[^\s]+)',
        caseSensitive: false,
      );
      final awashUrlMatch = awashUrlRegex.firstMatch(clean);
      if (awashUrlMatch != null) {
        receiptUrl = awashUrlMatch.group(1);
        txId = receiptUrl;
      }

      // 2. Transaction ID / Reference
      if (txId == null) {
        final awashRefRegex = RegExp(
          r'(?:Txn\s*ID|Transaction\s*(?:ID|No|Reference)|Ref(?:\s*No)?|Receipt\s*No)[\s:]*([A-Za-z0-9_-]+)',
          caseSensitive: false,
        );
        final m = awashRefRegex.firstMatch(clean);
        if (m != null) {
          txId = m.group(1)?.trim();
        }
      }
      if (txId == null) {
        final codeMatch = RegExp(
          r'\b(AW[0-9A-Za-z]{8,14})\b',
          caseSensitive: false,
        ).firstMatch(clean);
        if (codeMatch != null) {
          txId = codeMatch.group(1)?.toUpperCase();
        }
      }

      // 3. Amount
      final amountMatch =
          RegExp(
            r'(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
            caseSensitive: false,
          ).firstMatch(clean) ??
          RegExp(
            r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:ETB|Birr)',
            caseSensitive: false,
          ).firstMatch(clean);
      if (amountMatch != null) {
        amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
      }

      // 4. Date
      final dateMatch =
          RegExp(
            r'\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?)\b',
          ).firstMatch(clean) ??
          RegExp(
            r'\b(\d{4}[/-]\d{1,2}[/-]\d{1,2}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?)\b',
          ).firstMatch(clean);
      if (dateMatch != null) {
        dateStr = dateMatch.group(1)?.trim();
      }

      // 5. Receiver & Sender
      final receiverMatch = RegExp(
        r'(?:to|paid to|beneficiary)[\s:]*([A-Za-z0-9\s-]+?)(?:\.|\n|\r|$)',
        caseSensitive: false,
      ).firstMatch(clean);
      if (receiverMatch != null) {
        receiverAcc = receiverMatch.group(1)?.trim();
      }
      final senderMatch = RegExp(
        r'(?:from|sender)[\s:]*([A-Za-z\s]+?)(?:\.|\n|\r|$)',
        caseSensitive: false,
      ).firstMatch(clean);
      if (senderMatch != null) {
        sender = senderMatch.group(1)?.trim();
      }
    } else if (detectedBank == 'coopayebirr' || isOromiaHint) {
      // ── OROMIA / COOPAY EBIRR EXTRACTION ──
      // 1. Coopay / eBirr Receipt URL
      final coopUrlRegex = RegExp(
        r'(https?:\/\/receipt\.ebirr\.com(?::\d+)?\/[^\s]+)',
        caseSensitive: false,
      );
      final coopUrlMatch = coopUrlRegex.firstMatch(clean);
      if (coopUrlMatch != null) {
        receiptUrl = coopUrlMatch.group(1);
        txId = receiptUrl;
      }

      // 2. Transaction ID
      if (txId == null) {
        final coopRefRegex = RegExp(
          r'(?:Lakkoofsa\s+Kaffaltii|Transaction\s*(?:No|Number|ID)|Ref(?:\s*No)?|Receipt\s*No)[\s:]*([A-Za-z0-9_-]+)',
          caseSensitive: false,
        );
        final m = coopRefRegex.firstMatch(clean);
        if (m != null) {
          txId = m.group(1)?.trim();
        }
      }
      if (txId == null) {
        final codeMatch = RegExp(
          r'\b(CP[0-9A-Za-z]{8,14})\b',
          caseSensitive: false,
        ).firstMatch(clean);
        if (codeMatch != null) {
          txId = codeMatch.group(1)?.toUpperCase();
        }
      }

      // 3. Amount
      final amountMatch =
          RegExp(
            r'(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
            caseSensitive: false,
          ).firstMatch(clean) ??
          RegExp(
            r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:ETB|Birr)',
            caseSensitive: false,
          ).firstMatch(clean);
      if (amountMatch != null) {
        amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
      }

      // 4. Date
      final dateMatch =
          RegExp(
            r'\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?)\b',
          ).firstMatch(clean) ??
          RegExp(
            r'\b(\d{4}[/-]\d{1,2}[/-]\d{1,2}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?)\b',
          ).firstMatch(clean);
      if (dateMatch != null) {
        dateStr = dateMatch.group(1)?.trim();
      }

      // 5. Receiver & Sender
      final receiverMatch = RegExp(
        r'(?:Kan\s+raawwateef|to|paid to)[\s:]*([A-Za-z0-9\s-]+?)(?:\.|\n|\r|$)',
        caseSensitive: false,
      ).firstMatch(clean);
      if (receiverMatch != null) {
        receiverAcc = receiverMatch.group(1)?.trim();
      }
      final senderMatch = RegExp(
        r'(?:Kan\s+raawwate|from|sender)[\s:]*([A-Za-z\s]+?)(?:\.|\n|\r|$)',
        caseSensitive: false,
      ).firstMatch(clean);
      if (senderMatch != null) {
        sender = senderMatch.group(1)?.trim();
      }
    } else {
      // ── CBE & BOA EXTRACTION ──
      // 1. CBE Receipt URL / Token (from SMS notifications or web receipts)
      // Example: https://mreciept.cbe.com.et/v2/-hfHCxHMBDDeLLF7MLsuaD
      // In mobile SMS screenshots, the URL frequently wraps across lines.
      // Layer A: Standard CBE receipt URL format
      final cbeUrlRegex = RegExp(
        r'(?:https?:\/\/)?((?:[a-zA-Z0-9_\-]+\.)?cbe\.com\.et)[\s\r\n/]*(?:(v\d+)[\s\r\n/]+)?([-A-Za-z0-9_]{10,40})',
        caseSensitive: false,
      );
      final cbeUrlMatch = cbeUrlRegex.firstMatch(clean);
      if (cbeUrlMatch != null) {
        final domain = cbeUrlMatch.group(1)!.toLowerCase();
        final version = cbeUrlMatch.group(2) ?? 'v2';
        final token = cbeUrlMatch.group(3)!;
        receiptUrl = 'https://$domain/$version/$token';
        txId = receiptUrl;
      }

      // Layer B: Relaxed domain (OCR spacing, OCR misreading i as 1/l, or red pen covering .et)
      if (receiptUrl == null) {
        final relaxedDomainRegex = RegExp(
          r'(?:https?:\/\/)?\s*m\s*rec[ie1l]{2,4}pt\s*[\.\s_]*cbe\s*[\.\s_]*com(?:\s*[\.\s_]*et)?[\s\r\n/]*(?:v\s*(\d+)[\s\r\n/]+)?([-A-Za-z0-9_]{10,40})',
          caseSensitive: false,
        );
        final m = relaxedDomainRegex.firstMatch(clean);
        if (m != null) {
          final v = m.group(1) != null ? 'v${m.group(1)}' : 'v2';
          final token = m.group(2)!;
          receiptUrl = 'https://mreciept.cbe.com.et/$v/$token';
          txId = receiptUrl;
        }
      }

      // Layer C: /v2/<token> anywhere in CBE context (even if domain was completely cut off by red pen)
      if (receiptUrl == null) {
        final v2TokenRegex = RegExp(
          r'(?:\/|\b)v(\d+)[\s\r\n/]+([-A-Za-z0-9_]{10,40})\b',
          caseSensitive: false,
        );
        final m = v2TokenRegex.firstMatch(clean);
        if (m != null) {
          final v = 'v${m.group(1)}';
          final token = m.group(2)!;
          receiptUrl = 'https://mreciept.cbe.com.et/$v/$token';
          txId = receiptUrl;
        }
      }

      // Layer D: Bank of Abyssinia slip URL (https://cs.bankofabyssinia.com/slip/?trx=...)
      if (receiptUrl == null) {
        final boaUrlMatch = RegExp(
          r'(https?:\/\/cs\.bankofabyssinia\.com\/slip\/[^\s]+)',
          caseSensitive: false,
        ).firstMatch(clean);
        if (boaUrlMatch != null) {
          receiptUrl = boaUrlMatch.group(1);
          final trm = RegExp(r'[?&]trx=([A-Za-z0-9]+)').firstMatch(receiptUrl!);
          txId = trm?.group(1) ?? receiptUrl;
        }
      }

      // Layer E: Any standalone URL in the text containing cbe, reciept/receipt, or dashen
      if (receiptUrl == null) {
        final genericCbeUrl = RegExp(
          r'(https?:\/\/[^\s]+(?:cbe|mreciept|mreceipt|dashen)[^\s]*)',
          caseSensitive: false,
        );
        final m = genericCbeUrl.firstMatch(clean);
        if (m != null) {
          receiptUrl = m.group(1);
          txId = receiptUrl;
        }
      }

      // Pattern A0: BOA USSD transaction ID: "with transaction ID: FT26315BLDHF" or "transaction ID: FT..."
      final boaUssdMatch = RegExp(
        r'(?:transaction\s*ID|Txn\s*ID)[\s:]*([A-Za-z0-9|!_-]{10,18})',
        caseSensitive: false,
      ).firstMatch(clean);
      if (boaUssdMatch != null) {
        txId = normalizeCbeFtReference(boaUssdMatch.group(1)!);
      }

      // Pattern A0.5: CBE USSD dialog: "To 4455 on 12/11/2026 FT26316C1JMB" or "on <date> FT..."
      if (txId == null || txId == receiptUrl) {
        final cbeUssdMatch = RegExp(
          r'(?:To\s+4455\s+on|on)\s+\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\s+((?:FT|ET|TT|PT|FI|FL|F1|F\||F7|IT|1T|LT)?[\s\-_.:/]*[0-9IILOQSBZ|!]{5}[\s\-_.:/]*[0-9A-Za-z|!]{4,8})',
          caseSensitive: false,
        ).firstMatch(clean);
        if (cbeUssdMatch != null) {
          txId = normalizeCbeFtReference(cbeUssdMatch.group(1)!);
        }
      }

      // Pattern A: CBE & BOA Funds Transfer format: FT + 2-digit Year + 3-digit Julian Day + 4-8 char suffix
      // e.g. FT26316C1JMB, FT26315BLDHF, FT26291KVDWY, FT26299DNGRD
      // Handles loose word boundaries, spaces, dashes, or OCR misrecognitions
      if (txId == null || txId == receiptUrl) {
        final cbeFtRegex = RegExp(
          r'(?:^|[^A-Za-z0-9])((?:FT|ET|TT|PT|FI|FL|F1|F\||F7|IT|1T|LT)[\s\-_.:/]*[0-9IILOQSBZ|!]{5}[\s\-_.:/]*[0-9A-Za-z|!]{4,8})(?:$|[^A-Za-z0-9])',
          caseSensitive: false,
        );
        final cbeFtMatch = cbeFtRegex.firstMatch(clean);
        if (cbeFtMatch != null) {
          txId = normalizeCbeFtReference(cbeFtMatch.group(1)!);
        }
      }

      // Pattern A2: Date followed by transaction code (e.g. "12/11/2026 FT26316CIJMB" or "on 12/11/2026 FT...")
      if (txId == null || txId == receiptUrl) {
        final dateFtMatch = RegExp(
          r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\s+((?:FT|ET|TT|PT|FI|FL|F1|F\||F7|IT|1T|LT)?[\s\-_.:/]*[0-9IILOQSBZ|!]{5}[\s\-_.:/]*[0-9A-Za-z|!]{4,8})',
          caseSensitive: false,
        ).firstMatch(clean);
        if (dateFtMatch != null) {
          final cand = dateFtMatch.group(1)!.trim();
          txId = normalizeCbeFtReference(cand);
        }
      }

      // Pattern B: Labeled Txn ID / Reference (e.g. "Txn ID: FT26...", "Ref: fHCxy...")
      if (txId == null || txId == receiptUrl) {
        final cbeLabeledRegex = RegExp(
          r'(?:Txn\s*ID|Transaction\s*(?:ID|No|Reference)|Ref(?:\s*No)?|Receipt\s*No)[\s:]*([A-Za-z0-9_-]+)',
          caseSensitive: false,
        );
        final m = cbeLabeledRegex.firstMatch(clean);
        if (m != null) {
          final candidate = m.group(1)?.trim();
          if (candidate != null && candidate.toUpperCase().startsWith('FT')) {
            txId = normalizeCbeFtReference(candidate);
          } else {
            txId = candidate;
          }
        }
      }

      // Pattern C: If no explicit FT code or labeled reference was found, keep receiptUrl
      if (txId == null && receiptUrl != null) {
        txId = receiptUrl;
      }

      // Fallback: Generic receipt URL
      if (receiptUrl == null) {
        final genericUrlRegex = RegExp(
          r'(https?:\/\/[^\s]+(?:\/v\d+\/|\/receipt\/)[-A-Za-z0-9_]+)',
          caseSensitive: false,
        );
        final gMatch = genericUrlRegex.firstMatch(clean);
        if (gMatch != null) {
          receiptUrl = gMatch.group(1);
          txId ??= receiptUrl;
        }
      }

      // Ensure txId has a clean reference number if it is a Telebirr URL
      if (txId != null && (txId.startsWith('http://') || txId.startsWith('https://'))) {
        receiptUrl ??= txId;
        final cleanTok = VerifyEtService.sanitizeTelebirrReference(txId);
        if (cleanTok.isNotEmpty && !cleanTok.startsWith('http')) {
          txId = cleanTok;
        }
      }

      // 2. Date:
      final cbeDateMatch = RegExp(
        r'(?:on|date|dated)[\s:]*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',
        caseSensitive: false,
      ).firstMatch(clean);
      if (cbeDateMatch != null) {
        dateStr = cbeDateMatch.group(1)?.trim();
      } else {
        final dateFallback = RegExp(
          r'\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b',
        ).firstMatch(clean);
        if (dateFallback != null) {
          dateStr = dateFallback.group(1)?.trim();
        }
      }

      // 3. Amount:
      // Pattern A: CBE & BOA SMS / notification ("transferred ETB200.00 from", "Completed ETB400.61 transfer", "Complete ETB 200.00 debited")
      final cbeTransferredMatch = RegExp(
        r'(?:transferred|transfer(?:red)?|Completed|Complete|debited)\s*(?:ETB|Birr)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ).firstMatch(clean);
      if (cbeTransferredMatch != null) {
        final rawNum = cbeTransferredMatch.group(1)!.replaceAll(',', '');
        amount = double.tryParse(rawNum);
      } else {
        final cbeAmountMatch = RegExp(
          r'(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
          caseSensitive: false,
        ).firstMatch(clean);
        if (cbeAmountMatch != null) {
          final rawNum = cbeAmountMatch.group(1)!.replaceAll(',', '');
          amount = double.tryParse(rawNum);
        } else {
          final altAmount = RegExp(
            r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:ETB|Birr)',
            caseSensitive: false,
          ).firstMatch(clean);
          if (altAmount != null) {
            final rawNum = altAmount.group(1)!.replaceAll(',', '');
            amount = double.tryParse(rawNum);
          }
        }
      }

      // 4. Sender & Sender Account:
      // Sender Account Pattern A: BOA USSD "debited from 178635107 for 165093089"
      final boaDebitedMatch = RegExp(
        r'debited\s+from\s+([0-9]{7,16})',
        caseSensitive: false,
      ).firstMatch(clean);
      if (boaDebitedMatch != null) {
        senderAccount = boaDebitedMatch.group(1)?.trim();
      }

      // Sender Account Pattern B: "from account 178635107" or "sender account: 178635107"
      if (senderAccount == null) {
        final senderAccMatch = RegExp(
          r'(?:sender\s*(?:account)?|from\s*account|source\s*account|payer\s*account)[\s:(me)]*([0-9]{7,16})',
          caseSensitive: false,
        ).firstMatch(clean);
        if (senderAccMatch != null) {
          senderAccount = senderAccMatch.group(1)?.trim();
        }
      }

      // Sender Pattern A: CBE SMS "Dear Tigist Getnet Sharew You have successfully transferred"
      final cbeSmsSenderMatch = RegExp(
        r'Dear\s+([A-Za-z\s]+?)\s+(?:You\s+have\s+successfully|has\s+transferred|transferred|\n)',
        caseSensitive: false,
      ).firstMatch(clean);
      if (cbeSmsSenderMatch != null) {
        sender = cbeSmsSenderMatch.group(1)?.trim();
      }

      // Sender Pattern B: Standard receipt "From Abrham Teramed Nega to"
      if (sender == null) {
        final senderMatch = RegExp(
          r'From\s+([A-Za-z\s]+?)\s+to\b',
          caseSensitive: false,
        ).firstMatch(clean);
        if (senderMatch != null) {
          sender = senderMatch.group(1)?.trim();
        }
      }

      // Sender Pattern C: BOA USSD fallback if no sender name was parsed
      if (sender == null && senderAccount != null) {
        sender = senderAccount;
      }

      // 5. Receiver Account & Name:
      // Receiver Pattern A: CBE SMS "to account 1********1237 (Abrham Teramed Nega)."
      final cbeSmsReceiverMatch = RegExp(
        r'to\s+account\s+([0-9*]+)(?:\s*\(([A-Za-z\s]+?)\))?',
        caseSensitive: false,
      ).firstMatch(clean);
      if (cbeSmsReceiverMatch != null) {
        receiverAcc = cbeSmsReceiverMatch.group(1)?.trim();
        if (cbeSmsReceiverMatch.group(2) != null) {
          receiverName = cbeSmsReceiverMatch.group(2)?.trim();
        }
      }

      // Receiver Pattern B: Standard CBE receipt or USSD dialog "to Abrham Teramed Nega-1237."
      if (receiverAcc == null) {
        final receiverMatch = RegExp(
          r'to\s+([A-Za-z\s]+?)(?:-(\d{4,8}))?(?:\.|\s+To\b|\s+on\b|\s+FT|$)',
          caseSensitive: false,
        ).firstMatch(clean);
        if (receiverMatch != null) {
          final matchedName = receiverMatch.group(1)?.trim();
          final matchedSuffix = receiverMatch.group(2)?.trim();
          receiverName ??= matchedName;
          receiverAcc = matchedSuffix ?? matchedName;
        }
      }

      // Receiver Pattern C: BOA USSD "for 165093089 (self done via Mobile)"
      if (receiverAcc == null) {
        final boaReceiverMatch = RegExp(
          r'for\s+([0-9]{7,16})',
          caseSensitive: false,
        ).firstMatch(clean);
        if (boaReceiverMatch != null) {
          receiverAcc = boaReceiverMatch.group(1)?.trim();
        }
      }
    }

    // Try parsing date string into DateTime
    if (dateStr != null && dateStr.isNotEmpty) {
      parsedDate = _tryParseDateString(dateStr);
    }

    return ReceiptExtractionResult(
      transactionId: txId,
      receiptUrl: receiptUrl,
      date: dateStr,
      parsedDate: parsedDate,
      amount: amount,
      senderName: sender,
      senderAccount: senderAccount,
      receiverAccount: receiverAcc,
      receiverName: receiverName,
      bank: detectedBank.isNotEmpty
          ? detectedBank
          : (isCbeHint
                ? 'cbe'
                : (isTelebirrHint
                      ? 'telebirr'
                      : (isBoaHint
                            ? 'boa'
                            : (isAwashHint
                                  ? 'awash'
                                  : (isOromiaHint ? 'coopayebirr' : null))))),
      rawText: clean,
      source: 'regex',
      isUssdReceipt: isUssd,
    );
  }

  static DateTime? _tryParseDateString(String s) {
    final clean = s.replaceAll('-', '/').trim();
    // 1. Try ISO: 2026/10/21 07:56:12 or 2026/10/21
    try {
      if (clean.contains(' ')) {
        return DateFormat('yyyy/MM/dd HH:mm:ss').parseLoose(clean);
      } else if (clean.length == 10 && clean.startsWith('20')) {
        return DateFormat('yyyy/MM/dd').parseLoose(clean);
      }
    } catch (_) {}

    // 2. Try DD/MM/YYYY
    try {
      return DateFormat('dd/MM/yyyy').parseLoose(clean);
    } catch (_) {}

    // 3. Try standard Dart DateTime.tryParse
    return DateTime.tryParse(s.replaceAll('/', '-'));
  }

  /// Stitches together URL lines that have been wrapped across newlines by mobile SMS clients.
  static String _stitchWrappedUrls(String text) {
    final lines = text.split(RegExp(r'\r?\n')).map((l) => l.trim()).toList();
    final reconstructed = <String>[];
    int i = 0;
    while (i < lines.length) {
      final line = lines[i];
      if (line.isEmpty) {
        reconstructed.add(line);
        i++;
        continue;
      }

      final isUrlStart =
          line.toLowerCase().contains('http://') ||
          line.toLowerCase().contains('https://') ||
          line.toLowerCase().contains('mreciept') ||
          line.toLowerCase().contains('mreceipt') ||
          line.toLowerCase().contains('cbe.com.et') ||
          line.toLowerCase().contains('awashpay') ||
          line.toLowerCase().contains('ebirr.com') ||
          line.toLowerCase().contains('forms.gle');

      if (isUrlStart) {
        final urlParts = [line];
        while (i + 1 < lines.length) {
          final nxt = lines[i + 1];
          // Check if next line is a continuation (starts with /, or is v2, or is a link token)
          final isContinuation =
              nxt.startsWith('/') ||
              RegExp(
                r'^(?:v\d+|[-A-Za-z0-9_]{10,40})$',
                caseSensitive: false,
              ).hasMatch(nxt);
          final isStopKeyword =
              nxt.toLowerCase().startsWith('for feedback') ||
              nxt.toLowerCase().startsWith('dear ') ||
              nxt.toLowerCase().startsWith('thanks ') ||
              nxt.toLowerCase().startsWith('sender ');

          if (isContinuation && !isStopKeyword) {
            urlParts.add(nxt);
            i++;
          } else {
            break;
          }
        }

        // Cleanly join parts ensuring proper single slash delimiters
        final joined = urlParts.map((p) => p.trim()).join('');
        reconstructed.add(joined);
      } else {
        reconstructed.add(line);
      }
      i++;
    }
    return reconstructed.join('\n');
  }
}

/// Service that coordinates on-device OCR (via Google ML Kit on mobile) and
/// remote OCR (via Verify.ET) to extract the transaction ID and receipt details.
class ReceiptExtractorService {
  ReceiptExtractorService._();
  static final ReceiptExtractorService instance = ReceiptExtractorService._();

  TextRecognizer? _recognizer;
  final Map<String, ReceiptExtractionResult> _cache = {};

  ReceiptExtractionResult? getCached(String? key) {
    if (key == null || key.trim().isEmpty) return null;
    return _cache[key.trim()];
  }

  void setCache(String? key, ReceiptExtractionResult res) {
    if (key == null || key.trim().isEmpty) return;
    _cache[key.trim()] = res;
  }

  TextRecognizer get _textRecognizer {
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _recognizer!;
  }

  /// Extracts transaction ID and receipt details from an image URL or local file path.
  Future<ReceiptExtractionResult?> extractFromUrl(
    String imageUrl, {
    String? bankHint,
    String? cacheKey,
    bool force = false,
  }) async {
    final cleanUrl = imageUrl.trim();
    if (cleanUrl.isEmpty) return null;
    final baseKey = cacheKey ?? cleanUrl.split('?').first;
    if (!force) {
      final cached = _cache[baseKey] ?? _cache[cleanUrl];
      if (cached != null && cached.hasTransactionId) {
        return cached;
      }
    }
    try {
      Uint8List bytes;
      if (cleanUrl.startsWith('file://') || (!cleanUrl.startsWith('http') && File(cleanUrl).existsSync())) {
        final filePath = cleanUrl.replaceFirst('file://', '');
        bytes = await File(filePath).readAsBytes();
      } else {
        final res = await http.get(Uri.parse(cleanUrl));
        if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
          debugPrint('[ReceiptExtractorService] HTTP error: status ${res.statusCode}');
          return null;
        }
        bytes = res.bodyBytes;
      }

      final extracted = await extractFromBytes(
        bytes,
        bankHint: bankHint,
      );
      if (extracted != null) {
        _cache[baseKey] = extracted;
        _cache[cleanUrl] = extracted;
      }
      return extracted;
    } catch (e) {
      debugPrint('[ReceiptExtractorService] Failed to fetch image: $e');
    }
    return null;
  }

  /// Extracts transaction ID and receipt details from raw image bytes.
  Future<ReceiptExtractionResult?> extractFromBytes(
    Uint8List bytes, {
    String? bankHint,
    String fileName = 'receipt.jpg',
  }) async {
    if (bytes.isEmpty) return null;

    // 1. Try Google ML Kit On-Device OCR (Supported on Android and iOS)
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final result = await _extractViaMlKit(bytes, bankHint: bankHint);
        if (result != null && result.hasTransactionId) {
          return result;
        }
      } catch (e) {
        debugPrint('[ReceiptExtractorService] ML Kit OCR error: $e');
      }
    }

    // 2. Try Windows On-Device Media OCR (Supported on Windows 10 & 11)
    if (!kIsWeb && Platform.isWindows) {
      try {
        final result = await _extractViaWindowsOcr(bytes, bankHint: bankHint);
        if (result != null && result.hasTransactionId) {
          return result;
        }
      } catch (e) {
        debugPrint('[ReceiptExtractorService] Windows OCR error: $e');
      }
    }

    // 3. Fallback to Verify.ET Image Processing & upstream bank verification if API key is present
    final verifyService = VerifyEtService.instance;
    if (verifyService.hasApiKey) {
      try {
        final vRes = await verifyService.verifyScreenshot(
          imageBytes: bytes,
          fileName: fileName,
          bankHint: bankHint,
          autoPoll: true,
          waitMs: 12000,
        );

        final rawTxId = vRes.referenceNumber ?? vRes.receiptNumber;
        final txId = (rawTxId != null && rawTxId.toUpperCase().startsWith('FT'))
            ? ReceiptTextParser.normalizeCbeFtReference(rawTxId)
            : rawTxId;
        final dateStr = vRes.timestamp != null
            ? '${DateFormat('d MMM yyyy, h:mm a').format(EthiopianTimeHelper.toEastAfricaTime(vRes.timestamp!))} EAT'
            : null;
        final resolvedUrl = vRes.resolvedUrl ?? vRes.detected?.url;
        final isHttpReceipt = txId != null && txId.startsWith('http');
        final receiptUrl = resolvedUrl ?? (isHttpReceipt ? txId : null);

        return ReceiptExtractionResult(
          transactionId: txId,
          receiptUrl: receiptUrl,
          date: dateStr,
          parsedDate: vRes.timestamp,
          amount: vRes.amount > 0 ? vRes.amount : null,
          currency: vRes.currency,
          senderName: vRes.senderName,
          senderAccount: vRes.receipt?.payerAccount,
          receiverAccount: vRes.receiverAccount,
          receiverName: vRes.receiverName,
          bank: vRes.bank,
          source: 'verify_et',
        );
      } catch (e) {
        debugPrint('[ReceiptExtractorService] Verify.ET image OCR error: $e');
      }
    }

    return null;
  }

  Future<ReceiptExtractionResult?> _extractViaWindowsOcr(
    Uint8List bytes, {
    String? bankHint,
  }) async {
    Directory? tempDir;
    try {
      tempDir = Directory.systemTemp.createTempSync('win_ocr_');
      final tempFile = File(
        '${tempDir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(bytes, flush: true);

      final scriptFile = File('${tempDir.path}/ocr.ps1');
      await scriptFile.writeAsString('''
param([string]\$ImagePath)
Add-Type -AssemblyName System.Runtime.WindowsRuntime
\$asTaskGeneric = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    \$_.Name -eq 'AsTask' -and \$_.IsGenericMethod -and \$_.GetParameters().Length -eq 1
} | Select-Object -First 1

function AwaitTask(\$asyncOp, \$resultType) {
    \$genericMethod = \$asTaskGeneric.MakeGenericMethod(\$resultType)
    \$task = \$genericMethod.Invoke(\$null, @(\$asyncOp))
    \$task.Wait(-1) | Out-Null
    return \$task.Result
}

[Windows.Globalization.Language, Windows.Globalization, ContentType = WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapDecoder, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.StorageFile, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null

\$resolvedPath = (Resolve-Path \$ImagePath).Path
\$fileOp = [Windows.Storage.StorageFile]::GetFileFromPathAsync(\$resolvedPath)
\$file = AwaitTask \$fileOp ([Windows.Storage.StorageFile])

\$streamOp = \$file.OpenAsync([Windows.Storage.FileAccessMode]::Read)
\$stream = AwaitTask \$streamOp ([Windows.Storage.Streams.IRandomAccessStream])

\$decoderOp = [Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync(\$stream)
\$decoder = AwaitTask \$decoderOp ([Windows.Graphics.Imaging.BitmapDecoder])

\$bitmapOp = \$decoder.GetSoftwareBitmapAsync()
\$bitmap = AwaitTask \$bitmapOp ([Windows.Graphics.Imaging.SoftwareBitmap])

\$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
if (\$null -eq \$engine) {
    \$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage([Windows.Globalization.Language]::new('en-US'))
}
\$ocrOp = \$engine.RecognizeAsync(\$bitmap)
\$result = AwaitTask \$ocrOp ([Windows.Media.Ocr.OcrResult])

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::Out.Write(\$result.Text)
''');

      final res = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          scriptFile.path,
          '-ImagePath',
          tempFile.path,
        ],
      );

      if (res.exitCode == 0) {
        final recognizedText = res.stdout.toString().trim();
        if (recognizedText.isNotEmpty) {
          final parsed = ReceiptTextParser.parse(
            recognizedText,
            bankHint: bankHint,
          );
          return parsed.copyWith(source: 'windows_ocr');
        }
      } else {
        debugPrint('[ReceiptExtractorService] Windows OCR process error: ${res.stderr}');
      }
    } catch (e) {
      debugPrint('[ReceiptExtractorService] Windows OCR error: $e');
    } finally {
      try {
        tempDir?.deleteSync(recursive: true);
      } catch (_) {}
    }
    return null;
  }

  Future<ReceiptExtractionResult?> _extractViaMlKit(
    Uint8List bytes, {
    String? bankHint,
  }) async {
    Directory? tempDir;
    try {
      tempDir = Directory.systemTemp.createTempSync('ocr_receipt_');
      final tempFile = File(
        '${tempDir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(bytes, flush: true);

      final inputImage = InputImage.fromFilePath(tempFile.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final parsed = ReceiptTextParser.parse(
        recognizedText.text,
        bankHint: bankHint,
      );
      return parsed.copyWith(source: 'mlkit');
    } finally {
      try {
        tempDir?.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  void dispose() {
    _recognizer?.close();
    _recognizer = null;
  }
}
