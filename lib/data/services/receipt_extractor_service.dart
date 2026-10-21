import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:m_admin/data/services/verify_et_service.dart';

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
    this.receiverAccount,
    this.receiverName,
    this.bank,
    this.rawText = '',
    this.source = 'ocr',
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

  /// Receiver account number or phone if detected.
  final String? receiverAccount;

  /// Receiver beneficiary name if detected (e.g. from SMS "Abrham Teramed Nega").
  final String? receiverName;

  /// Detected or hinted bank key ('cbe', 'telebirr', 'boa', etc.).
  final String? bank;

  /// Full recognized text.
  final String rawText;

  /// Extraction method ('mlkit', 'verify_et', or 'regex').
  final String source;

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
    String? receiverAccount,
    String? receiverName,
    String? bank,
    String? rawText,
    String? source,
  }) {
    return ReceiptExtractionResult(
      transactionId: transactionId ?? this.transactionId,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      date: date ?? this.date,
      parsedDate: parsedDate ?? this.parsedDate,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      senderName: senderName ?? this.senderName,
      receiverAccount: receiverAccount ?? this.receiverAccount,
      receiverName: receiverName ?? this.receiverName,
      bank: bank ?? this.bank,
      rawText: rawText ?? this.rawText,
      source: source ?? this.source,
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

  /// Parses raw OCR or SMS text to extract Transaction ID, Date, Amount, Sender, and Receiver.
  static ReceiptExtractionResult parse(String rawText, {String? bankHint}) {
    // Pre-process: stitch wrapped URL lines commonly split across newlines in mobile SMS receipts
    final clean = _stitchWrappedUrls(rawText.trim());
    if (clean.isEmpty) {
      return const ReceiptExtractionResult();
    }

    final normalizedHint = bankHint?.toLowerCase().trim() ?? '';
    final isTelebirrHint = normalizedHint.contains('telebirr');
    final isCbeHint = normalizedHint.contains('cbe') || normalizedHint.contains('commercial');
    final isBoaHint = normalizedHint.contains('abyssinia') || normalizedHint.contains('boa');

    // 1. Detect Bank
    String detectedBank = normalizedHint;
    if (detectedBank.isEmpty) {
      if (clean.contains('telebirr') ||
          clean.contains('Lakkoofsa Kaffaltii') ||
          clean.contains('yeroo daddabarsaa') ||
          clean.contains("Milkaa'eera") ||
          clean.contains('የግብይት ቁጥር')) {
        detectedBank = 'telebirr';
      } else if (clean.contains('FT') ||
          clean.contains('CBE') ||
          clean.contains('Commercial Bank') ||
          clean.contains('Commercial Bank of Ethiopia') ||
          clean.contains('CBEBirr') ||
          clean.contains('mreciept.cbe.com.et') ||
          clean.contains('mreceipt.cbe.com.et') ||
          clean.contains('cbe.com.et')) {
        detectedBank = 'cbe';
      } else if (clean.contains('Abyssinia') || clean.contains('Absiiniyaa')) {
        detectedBank = 'boa';
      }
    }

    String? txId;
    String? receiptUrl;
    String? dateStr;
    DateTime? parsedDate;
    double? amount;
    String? sender;
    String? receiverAcc;
    String? receiverName;

    if (detectedBank == 'telebirr' || isTelebirrHint) {
      // ── TELEBIRR EXTRACTION ──
      // 1. Transaction ID:
      // Pattern A: Labeled with Afaan Oromo, English, or Amharic
      final teleLabeledRegex = RegExp(
        r'(?:Lakkoofsa\s+Kaffaltii|Lakkoofsa\s+daddabarsaa|Transaction\s*(?:No|Number|ID|Code)|Payment\s*Code|የግብይት\s*ቁጥር|የሂሳብ\s*ቁጥር|የማረጋገጫ\s*ቁጥር)[\s:]*([A-Za-z0-9]{10})\b',
        caseSensitive: false,
      );
      final teleLabeledMatch = teleLabeledRegex.firstMatch(clean);
      if (teleLabeledMatch != null) {
        txId = teleLabeledMatch.group(1)?.toUpperCase();
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
          if (RegExp(r'[A-Za-z]').hasMatch(candidate) && RegExp(r'[0-9]').hasMatch(candidate)) {
            txId = candidate;
            break;
          }
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
        final isoLikeMatch = RegExp(r'\b(\d{4}[/-]\d{1,2}[/-]\d{1,2}\s+\d{1,2}:\d{2}(?::\d{2})?)\b').firstMatch(clean);
        if (isoLikeMatch != null) {
          dateStr = isoLikeMatch.group(1)?.trim();
        }
      }

      // 3. Amount:
      final teleAmountMatch = RegExp(r'-?\s*([0-9,]+(?:\.[0-9]{1,2})?)\s*\(?(?:ETB|Birr|ብር)\)?', caseSensitive: false).firstMatch(clean);
      if (teleAmountMatch != null) {
        final rawNum = teleAmountMatch.group(1)!.replaceAll(',', '');
        amount = double.tryParse(rawNum);
      }

      // 4. Sender / Receiver:
      final teleReceiverMatch = RegExp(r'(?:Kan\s+raawwateef|Paid\s+to|Receiver)[\s:]*([A-Za-z\s]+?)(?:\n|\r|Lakkoofsa|$)', caseSensitive: false).firstMatch(clean);
      if (teleReceiverMatch != null) {
        sender = teleReceiverMatch.group(1)?.trim();
      }

      final teleAccMatch = RegExp(r'(?:Lakkoofsa\s+herrega\s+baankii|Account\s*No|Acc)[\s:]*([0-9]+)', caseSensitive: false).firstMatch(clean);
      if (teleAccMatch != null) {
        receiverAcc = teleAccMatch.group(1)?.trim();
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

      // Layer D: Any standalone URL in the text containing cbe or reciept/receipt
      if (receiptUrl == null) {
        final genericCbeUrl = RegExp(
          r'(https?:\/\/[^\s]+(?:cbe|mreciept|mreceipt)[^\s]*)',
          caseSensitive: false,
        );
        final m = genericCbeUrl.firstMatch(clean);
        if (m != null) {
          receiptUrl = m.group(1);
          txId = receiptUrl;
        }
      }

      // Pattern A: CBE Funds Transfer format: FT + 10-14 alphanumeric (e.g. FT26291KVDWY)
      final cbeFtRegex = RegExp(r'\b(FT[0-9A-Za-z]{10,14})\b', caseSensitive: false);
      final cbeFtMatch = cbeFtRegex.firstMatch(clean);
      if (cbeFtMatch != null) {
        txId = cbeFtMatch.group(1)?.toUpperCase();
      }

      // Pattern B: Labeled Txn ID / Reference (e.g. "Txn ID: FT26...", "Ref: fHCxy...")
      if (txId == null || txId == receiptUrl) {
        final cbeLabeledRegex = RegExp(
          r'(?:Txn\s*ID|Transaction\s*(?:ID|No|Reference)|Ref(?:\s*No)?|Receipt\s*No)[\s:]*([A-Za-z0-9_-]+)',
          caseSensitive: false,
        );
        final m = cbeLabeledRegex.firstMatch(clean);
        if (m != null) {
          txId = m.group(1)?.trim();
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

      // 2. Date:
      final cbeDateMatch = RegExp(
        r'(?:on|date|dated)[\s:]*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',
        caseSensitive: false,
      ).firstMatch(clean);
      if (cbeDateMatch != null) {
        dateStr = cbeDateMatch.group(1)?.trim();
      } else {
        final dateFallback = RegExp(r'\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b').firstMatch(clean);
        if (dateFallback != null) {
          dateStr = dateFallback.group(1)?.trim();
        }
      }

      // 3. Amount:
      // Pattern A: CBE SMS / notification ("transferred ETB200.00 from" or "Completed ETB400.61 transfer")
      final cbeTransferredMatch = RegExp(
        r'(?:transferred|transfer(?:red)?|Completed)\s*(?:ETB|Birr)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
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
          final altAmount = RegExp(r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:ETB|Birr)', caseSensitive: false).firstMatch(clean);
          if (altAmount != null) {
            final rawNum = altAmount.group(1)!.replaceAll(',', '');
            amount = double.tryParse(rawNum);
          }
        }
      }

      // 4. Sender:
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
        final senderMatch = RegExp(r'From\s+([A-Za-z\s]+?)\s+to\b', caseSensitive: false).firstMatch(clean);
        if (senderMatch != null) {
          sender = senderMatch.group(1)?.trim();
        }
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

      // Receiver Pattern B: Standard CBE receipt "to Negawo Abu Neme-6782"
      if (receiverAcc == null) {
        final receiverMatch = RegExp(r'to\s+([A-Za-z0-9\s-]+?)(?:\.|\s+To\b|\s+on\b|\s+FT)', caseSensitive: false).firstMatch(clean);
        if (receiverMatch != null) {
          receiverAcc = receiverMatch.group(1)?.trim();
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
      receiverAccount: receiverAcc,
      receiverName: receiverName,
      bank: detectedBank.isNotEmpty ? detectedBank : (isCbeHint ? 'cbe' : (isTelebirrHint ? 'telebirr' : (isBoaHint ? 'boa' : null))),
      rawText: clean,
      source: 'regex',
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

      final isUrlStart = line.toLowerCase().contains('http://') ||
          line.toLowerCase().contains('https://') ||
          line.toLowerCase().contains('mreciept') ||
          line.toLowerCase().contains('mreceipt') ||
          line.toLowerCase().contains('cbe.com.et') ||
          line.toLowerCase().contains('forms.gle');

      if (isUrlStart) {
        final urlParts = [line];
        while (i + 1 < lines.length) {
          final nxt = lines[i + 1];
          // Check if next line is a continuation (starts with /, or is v2, or is a link token)
          final isContinuation = nxt.startsWith('/') ||
              RegExp(r'^(?:v\d+|[-A-Za-z0-9_]{10,40})$', caseSensitive: false).hasMatch(nxt);
          final isStopKeyword = nxt.toLowerCase().startsWith('for feedback') ||
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

  TextRecognizer get _textRecognizer {
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _recognizer!;
  }

  /// Extracts transaction ID and receipt details from an image URL.
  Future<ReceiptExtractionResult?> extractFromUrl(
    String imageUrl, {
    String? bankHint,
  }) async {
    if (imageUrl.trim().isEmpty) return null;
    try {
      final res = await http.get(Uri.parse(imageUrl));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        return await extractFromBytes(res.bodyBytes, bankHint: bankHint);
      }
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

    // 2. Fallback to Verify.ET Image OCR & Verification if API key is present
    final verifyService = VerifyEtService.instance;
    if (verifyService.hasApiKey) {
      try {
        final vRes = await verifyService.verifyReceiptImage(
          imageBytes: bytes,
          fileName: fileName,
          bank: bankHint,
        );

        final txId = vRes.referenceNumber ?? vRes.receiptNumber;
        final dateStr = vRes.timestamp != null
            ? DateFormat('d MMM yyyy, HH:mm').format(vRes.timestamp!)
            : null;
        final isHttpReceipt = vRes.receiptNumber != null && vRes.receiptNumber!.startsWith('http');
        final receiptUrl = isHttpReceipt ? vRes.receiptNumber : null;

        return ReceiptExtractionResult(
          transactionId: txId,
          receiptUrl: receiptUrl,
          date: dateStr,
          parsedDate: vRes.timestamp,
          amount: vRes.amount > 0 ? vRes.amount : null,
          currency: vRes.currency,
          senderName: vRes.senderName,
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

  Future<ReceiptExtractionResult?> _extractViaMlKit(
    Uint8List bytes, {
    String? bankHint,
  }) async {
    Directory? tempDir;
    try {
      tempDir = Directory.systemTemp.createTempSync('ocr_receipt_');
      final tempFile = File('${tempDir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes, flush: true);

      final inputImage = InputImage.fromFilePath(tempFile.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final parsed = ReceiptTextParser.parse(recognizedText.text, bankHint: bankHint);
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
