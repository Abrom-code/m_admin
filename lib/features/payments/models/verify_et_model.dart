import 'package:m_admin/data/services/scanned_receipt_storage.dart';
import 'package:m_admin/utils/helpers/ethiopian_time_helper.dart';

/// Supported Verify.ET / links.et receipt sources
class LinksEtReceiptSources {
  static const String verifyEt = 'verify-et';
  static const String telebirrHtml = 'telebirr-html';
  static const String cbePdf = 'cbe-pdf';
  static const String mbJson = 'mb-json';
  static const String boaJson = 'boa-json';
  static const String zemenPdf = 'zemen-pdf';
  static const String awashHtml = 'awash-html';
  static const String cbebirrPdf = 'cbebirr-pdf';
  static const String dashenPdf = 'dashen-pdf';
  static const String dashenHtml = 'dashen-html';
  static const String mpesaPdf = 'mpesa-pdf';
  static const String ebirrHtml = 'ebirr-html';
  static const String amharaJson = 'amhara-json';
  static const String abayHtml = 'abay-html';
  static const String berhanPdf = 'berhan-pdf';
  static const String oromiaPdf = 'oromia-pdf';
  static const String ahaduPdf = 'ahadu-pdf';
  static const String siinqeePdf = 'siinqee-pdf';
  static const String zamzamJson = 'zamzam-json';
  static const String hulubejeDxxrdv = 'hulubeje-dxxrdv';
}

typedef VerifyEtReceiptSources = LinksEtReceiptSources;

/// Platform-wide duplicate / re-confirmation metadata from Verify.ET.
class ConfirmationHistory {
  final String? scope;
  final bool isFirstConfirmation;
  final bool confirmedBefore;
  final DateTime? firstConfirmedAt;
  final DateTime? lastConfirmedAt;
  final int confirmationCount;

  const ConfirmationHistory({
    this.scope,
    this.isFirstConfirmation = true,
    this.confirmedBefore = false,
    this.firstConfirmedAt,
    this.lastConfirmedAt,
    this.confirmationCount = 1,
  });

  factory ConfirmationHistory.fromJson(Map<String, dynamic> json) {
    return ConfirmationHistory(
      scope: json['scope']?.toString(),
      isFirstConfirmation: json['isFirstConfirmation'] == true,
      confirmedBefore: json['confirmedBefore'] == true,
      firstConfirmedAt: EthiopianTimeHelper.parseSupabaseUtc(json['firstConfirmedAt']),
      lastConfirmedAt: EthiopianTimeHelper.parseSupabaseUtc(json['lastConfirmedAt']),
      confirmationCount: (json['confirmationCount'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'scope': scope,
    'isFirstConfirmation': isFirstConfirmation,
    'confirmedBefore': confirmedBefore,
    'firstConfirmedAt': firstConfirmedAt?.toIso8601String(),
    'lastConfirmedAt': lastConfirmedAt?.toIso8601String(),
    'confirmationCount': confirmationCount,
  };
}

/// Settlement account validation result from Verify.ET.
class SettlementAccountMatch {
  final bool matched;
  final String? matchType;
  final String? matchConfidence;
  final String? source;
  final String? bank;
  final String? receiverAccount;
  final String? matchedSettlementAccount;
  final String? reason;

  const SettlementAccountMatch({
    required this.matched,
    this.matchType,
    this.matchConfidence,
    this.source,
    this.bank,
    this.receiverAccount,
    this.matchedSettlementAccount,
    this.reason,
  });

  factory SettlementAccountMatch.fromJson(Map<String, dynamic> json) {
    return SettlementAccountMatch(
      matched: json['matched'] == true,
      matchType: json['matchType']?.toString(),
      matchConfidence: json['matchConfidence']?.toString(),
      source: json['source']?.toString(),
      bank: json['bank']?.toString(),
      receiverAccount: json['receiverAccount']?.toString(),
      matchedSettlementAccount: json['matchedSettlementAccount']?.toString(),
      reason: json['reason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'matched': matched,
    'matchType': matchType,
    'matchConfidence': matchConfidence,
    'source': source,
    'bank': bank,
    'receiverAccount': receiverAccount,
    'matchedSettlementAccount': matchedSettlementAccount,
    'reason': reason,
  };
}

/// Normalized receipt data extracted directly from an upstream bank via Verify.ET (https://verify.et/docs/api).
class LinksEtReceipt {
  final String source;
  final String reference;
  final double amount;
  final String currency;
  final String? payerName;
  final String? payerAccount;
  final String? receiverName;
  final String? receiverAccount;
  final String? paymentDate;
  final DateTime? parsedDate;
  final String transactionStatus;
  final String? paymentReason;
  final double? serviceFee;
  final double? vat;
  final double? totalAmount;
  final String? paymentMode;
  final String? paymentChannel;
  final Map<String, dynamic> rawJson;

  const LinksEtReceipt({
    required this.source,
    required this.reference,
    required this.amount,
    this.currency = 'ETB',
    this.payerName,
    this.payerAccount,
    this.receiverName,
    this.receiverAccount,
    this.paymentDate,
    this.parsedDate,
    this.transactionStatus = 'Completed',
    this.paymentReason,
    this.serviceFee,
    this.vat,
    this.totalAmount,
    this.paymentMode,
    this.paymentChannel,
    required this.rawJson,
  });

  static double _parseAmount(dynamic raw) {
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    var s = raw.toString().trim();
    if (s.isEmpty) return 0.0;
    s = s.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(s) ?? 0.0;
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;

    final parsedUtc = EthiopianTimeHelper.parseSupabaseUtc(s);
    if (parsedUtc != null) return parsedUtc;

    final direct = DateTime.tryParse(s);
    if (direct != null) return direct;

    // Try common Ethiopian receipt formats: "dd-MM-yyyy HH:mm:ss" or "M/d/yyyy, hh:mm:ss a"
    try {
      final parts = s.split(RegExp(r'[\s,]+'));
      if (parts.isNotEmpty) {
        final datePart = parts[0];
        final sub = datePart.split(RegExp(r'[-/]'));
        if (sub.length == 3) {
          int? d = int.tryParse(sub[0]);
          int? m = int.tryParse(sub[1]);
          int? y = int.tryParse(sub[2]);
          if (d != null && m != null && y != null) {
            if (y < 100) y += 2000;
            // Handle day/month ordering
            if (m > 12 && d <= 12) {
              final tmp = d;
              d = m;
              m = tmp;
            }
            return DateTime(y, m, d);
          }
        }
      }
    } catch (_) {}

    return null;
  }

  factory LinksEtReceipt.fromJson(Map<String, dynamic> json) {
    final src = json['source']?.toString().toLowerCase() ??
        (json.containsKey('bankSpecific') ? LinksEtReceiptSources.verifyEt : 'generic');

    String ref = '';
    double amt = 0.0;
    double? totAmt;
    String curr = 'ETB';
    String? payer;
    String? payerAcc;
    String? receiver;
    String? receiverAcc;
    String? dateStr;
    String status = 'Completed';
    String? reason;
    double? fee;
    double? vatVal;
    String? mode;
    String? channel;

    // Check bankSpecific map if present (Verify.ET official response)
    final bankSpec = json['bankSpecific'] is Map<String, dynamic>
        ? json['bankSpecific'] as Map<String, dynamic>
        : (json['bankSpecific'] is Map ? Map<String, dynamic>.from(json['bankSpecific'] as Map) : null);

    switch (src) {
      case LinksEtReceiptSources.telebirrHtml:
        ref = json['receiptNo']?.toString() ?? json['reference']?.toString() ?? '';
        amt = _parseAmount(json['settledAmount']);
        totAmt = _parseAmount(json['totalPaidAmount']);
        if (amt == 0.0 && totAmt > 0) amt = totAmt;
        payer = json['payerName']?.toString();
        payerAcc = json['payerTelebirrNo']?.toString();
        receiver = json['creditedPartyName']?.toString();
        receiverAcc = json['creditedPartyAccountNo']?.toString();
        status = json['transactionStatus']?.toString() ?? 'Completed';
        dateStr = json['paymentDate']?.toString();
        reason = json['paymentReason']?.toString();
        fee = _parseAmount(json['serviceFee']);
        vatVal = _parseAmount(json['serviceFeeVAT']);
        mode = json['paymentMode']?.toString();
        channel = json['paymentChannel']?.toString();
        break;

      case LinksEtReceiptSources.cbePdf:
        ref = json['reference']?.toString() ?? json['vatReceiptNo']?.toString() ?? '';
        amt = _parseAmount(json['transferredAmount']);
        totAmt = _parseAmount(json['totalAmount']);
        if (amt == 0.0 && totAmt > 0) amt = totAmt;
        curr = json['currency']?.toString() ?? 'ETB';
        payer = json['payerName']?.toString() ?? json['customerName']?.toString();
        payerAcc = json['payerAccount']?.toString();
        receiver = json['receiverName']?.toString();
        receiverAcc = json['receiverAccount']?.toString();
        dateStr = json['paymentDate']?.toString();
        reason = json['paymentReason']?.toString() ?? json['amountInWords']?.toString();
        fee = _parseAmount(json['serviceCharge']);
        vatVal = _parseAmount(json['vat']);
        break;

      case LinksEtReceiptSources.mbJson:
        ref = json['reference']?.toString() ?? json['vatReceiptNo']?.toString() ?? '';
        amt = _parseAmount(json['transferredAmount'] ?? json['creditAmount']);
        totAmt = _parseAmount(json['totalAmount']);
        if (amt == 0.0 && totAmt > 0) amt = totAmt;
        curr = json['currency']?.toString() ?? 'ETB';
        payer = json['payerName']?.toString();
        payerAcc = json['payerAccount']?.toString();
        receiver = json['receiverName']?.toString();
        receiverAcc = json['receiverAccount']?.toString();
        dateStr = json['paymentDate']?.toString();
        reason = json['paymentReason']?.toString();
        fee = _parseAmount(json['serviceCharge']);
        vatVal = _parseAmount(json['vat']);
        break;

      case LinksEtReceiptSources.boaJson:
        ref = json['transactionReference']?.toString() ?? json['paymentReference']?.toString() ?? '';
        amt = _parseAmount(json['transferredAmount']);
        totAmt = _parseAmount(json['totalAmount']);
        if (amt == 0.0 && totAmt > 0) amt = totAmt;
        curr = json['currency']?.toString() ?? 'ETB';
        receiver = json['receiverName']?.toString();
        receiverAcc = json['receiverAccount']?.toString();
        dateStr = json['transactionDate']?.toString();
        reason = json['narrative']?.toString() ?? json['transactionType']?.toString();
        status = json['upstreamStatus']?.toString() ?? 'Success';
        fee = _parseAmount(json['serviceCharge']);
        vatVal = _parseAmount(json['vat']);
        break;

      case LinksEtReceiptSources.zemenPdf:
        ref = json['reference']?.toString() ?? json['invoiceNo']?.toString() ?? '';
        amt = _parseAmount(json['settledAmount']);
        totAmt = _parseAmount(json['totalAmountPaid']);
        if (amt == 0.0 && totAmt > 0) amt = totAmt;
        curr = json['currency']?.toString() ?? 'ETB';
        payer = json['payerName']?.toString();
        payerAcc = json['payerAccount']?.toString();
        receiver = json['recipientName']?.toString();
        receiverAcc = json['recipientAccount']?.toString();
        status = json['transactionStatus']?.toString() ?? 'COMPLETED';
        dateStr = json['date']?.toString();
        reason = json['transactionDetail']?.toString() ?? json['paymentReason']?.toString();
        fee = _parseAmount(json['serviceCharge']);
        vatVal = _parseAmount(json['vat']);
        break;

      case LinksEtReceiptSources.awashHtml:
        final cust = json['customer'] is Map ? json['customer'] as Map : null;
        final tx = json['transaction'] is Map ? json['transaction'] as Map : null;

        ref = tx?['transactionId']?.toString() ?? json['transactionId']?.toString() ?? '';
        amt = _parseAmount(tx?['amount'] ?? json['amount']);
        payer = tx?['senderName']?.toString() ?? cust?['customerName']?.toString();
        payerAcc = tx?['senderAccount']?.toString() ?? cust?['accountNo']?.toString();
        receiver = tx?['beneficiaryName']?.toString();
        receiverAcc = tx?['beneficiaryAccount']?.toString();
        dateStr = tx?['transactionTime']?.toString();
        reason = tx?['reason']?.toString() ?? tx?['transactionType']?.toString();
        fee = _parseAmount(tx?['charge']);
        vatVal = _parseAmount(tx?['vat']);
        break;

      default:
        // Universal fallbacks supporting Verify.ET envelope + all other Ethiopian banks
        ref = json['referenceNumber']?.toString() ??
            json['transactionNumber']?.toString() ??
            json['receiptNumber']?.toString() ??
            json['reference']?.toString() ??
            json['receiptNo']?.toString() ??
            json['transactionId']?.toString() ??
            json['transactionReference']?.toString() ??
            bankSpec?['reference']?.toString() ??
            bankSpec?['receiptNo']?.toString() ??
            '';

        amt = _parseAmount(
            json['amount'] ?? json['amountValue'] ?? json['transferredAmount'] ?? json['settledAmount'] ?? json['totalAmount']);
        if (amt == 0.0 && bankSpec != null) {
          amt = _parseAmount(bankSpec['amountValue'] ?? bankSpec['settledAmountValue'] ?? bankSpec['settledAmount']);
        }

        totAmt = _parseAmount(json['totalPaidAmount'] ?? json['totalAmount'] ?? bankSpec?['totalPaidAmountValue'] ?? bankSpec?['totalPaidAmount']);
        if (amt == 0.0 && totAmt > 0) amt = totAmt;

        curr = json['currency']?.toString() ?? bankSpec?['currency']?.toString() ?? 'ETB';
        payer = json['senderName']?.toString() ?? json['payerName']?.toString() ?? json['customerName']?.toString() ?? bankSpec?['payerName']?.toString() ?? bankSpec?['senderName']?.toString();
        payerAcc = json['senderAccount']?.toString() ?? json['payerAccount']?.toString() ?? json['payerTelebirrNo']?.toString() ?? bankSpec?['senderAccount']?.toString() ?? bankSpec?['payerTelebirrNo']?.toString();
        receiver = json['receiverName']?.toString() ?? json['recipientName']?.toString() ?? json['creditedPartyName']?.toString() ?? json['beneficiaryName']?.toString() ?? bankSpec?['receiverName']?.toString() ?? bankSpec?['creditedPartyName']?.toString();
        receiverAcc = json['receiverAccount']?.toString() ?? json['recipientAccount']?.toString() ?? json['creditedPartyAccountNo']?.toString() ?? bankSpec?['receiverAccount']?.toString() ?? bankSpec?['creditedPartyAccountNo']?.toString();
        dateStr = json['timestamp']?.toString() ?? json['paymentDate']?.toString() ?? json['date']?.toString() ?? json['transactionDate']?.toString() ?? bankSpec?['paymentDateIsoUtc']?.toString() ?? bankSpec?['paymentDate']?.toString();
        status = json['status']?.toString() ?? json['transactionStatus']?.toString() ?? bankSpec?['transactionStatus']?.toString() ?? 'Completed';
        reason = json['reason']?.toString() ?? json['paymentReason']?.toString() ?? json['narrative']?.toString() ?? bankSpec?['paymentReason']?.toString() ?? bankSpec?['reason']?.toString();
        fee = _parseAmount(json['serviceFee'] ?? json['serviceCharge'] ?? json['charge'] ?? bankSpec?['serviceFeeValue'] ?? bankSpec?['serviceFee']);
        vatVal = _parseAmount(json['serviceFeeVAT'] ?? json['vat'] ?? bankSpec?['serviceFeeVATValue'] ?? bankSpec?['serviceFeeVAT']);
        mode = json['paymentMode']?.toString() ?? bankSpec?['paymentMode']?.toString();
        channel = json['paymentChannel']?.toString() ?? bankSpec?['paymentChannel']?.toString();
        break;
    }

    return LinksEtReceipt(
      source: src,
      reference: ref,
      amount: amt,
      currency: curr,
      payerName: payer,
      payerAccount: payerAcc,
      receiverName: receiver,
      receiverAccount: receiverAcc,
      paymentDate: dateStr,
      parsedDate: _parseDate(dateStr),
      transactionStatus: status,
      paymentReason: reason,
      serviceFee: fee,
      vat: vatVal,
      totalAmount: totAmt,
      paymentMode: mode,
      paymentChannel: channel,
      rawJson: json,
    );
  }
}

typedef VerifyEtReceipt = LinksEtReceipt;

/// OCR detection metadata lifted from a screenshot via Verify.ET.
class ImageDetectionResult {
  final String provider;
  final String? reference;
  final String? url;
  final double confidence;

  const ImageDetectionResult({
    required this.provider,
    this.reference,
    this.url,
    this.confidence = 0.0,
  });

  factory ImageDetectionResult.fromJson(Map<String, dynamic> json) {
    return ImageDetectionResult(
      provider: json['provider']?.toString() ?? json['bank']?.toString() ?? 'none',
      reference: json['reference']?.toString() ?? json['referenceNumber']?.toString() ?? json['transactionNumber']?.toString(),
      url: json['url']?.toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Upstream bank cross-check result embedded in image verification.
class UpstreamResult {
  final bool attempted;
  final String? reason;
  final String? url;
  final LinksEtResult? result;
  final String? error;

  const UpstreamResult({
    required this.attempted,
    this.reason,
    this.url,
    this.result,
    this.error,
  });

  factory UpstreamResult.fromJson(Map<String, dynamic> json) {
    final resJson = json['result'] is Map<String, dynamic>
        ? json['result'] as Map<String, dynamic>
        : (json['result'] is Map ? Map<String, dynamic>.from(json['result'] as Map) : null);

    return UpstreamResult(
      attempted: json['attempted'] == true,
      reason: json['reason']?.toString(),
      url: json['url']?.toString(),
      result: resJson != null ? LinksEtResult.fromJson(resJson) : null,
      error: json['error']?.toString(),
    );
  }
}

/// Comprehensive verification response envelope from Verify.ET (https://verify.et/docs/api).
class LinksEtResult {
  final bool ok;
  final String providerKey;
  final String? resolvedUrl;
  final int httpStatus;
  final DateTime? fetchedAt;
  final int? rawHtmlLength;
  final bool cached;
  final String? requestId;
  final String? processingStatus;
  final String? statusUrl;
  final String? eventsUrl;
  final String? error;
  final String? errorCode;
  final LinksEtReceipt? receipt;
  final ImageDetectionResult? detected;
  final UpstreamResult? upstream;
  final ConfirmationHistory? confirmationHistory;
  final SettlementAccountMatch? settlementAccountMatch;
  final ScannedReceiptRecord? previousRecord;
  final Map<String, dynamic> rawJson;

  const LinksEtResult({
    required this.ok,
    required this.providerKey,
    this.resolvedUrl,
    this.httpStatus = 200,
    this.fetchedAt,
    this.rawHtmlLength,
    this.cached = false,
    this.requestId,
    this.processingStatus,
    this.statusUrl,
    this.eventsUrl,
    this.error,
    this.errorCode,
    this.receipt,
    this.detected,
    this.upstream,
    this.confirmationHistory,
    this.settlementAccountMatch,
    this.previousRecord,
    required this.rawJson,
  });

  bool get isPending =>
      processingStatus == 'queued' ||
      processingStatus == 'processing' ||
      processingStatus == 'running' ||
      httpStatus == 202;

  bool get isSuccess {
    if (isPending) return false;
    if (upstream?.result != null) {
      return upstream!.result!.isSuccess;
    }
    return ok && error == null;
  }

  bool get isFailed => !isPending && !isSuccess;

  /// Whether the receipt was verified before (either on Verify.ET platform or in local database)
  bool get wasScannedBefore =>
      (confirmationHistory?.confirmedBefore ?? false) ||
      (previousRecord != null && previousRecord!.wasScannedBefore);

  int get confirmationCount =>
      confirmationHistory?.confirmationCount ?? previousRecord?.scanCount ?? 1;

  /// Whether the upstream bank was queried but the receipt could not be validated
  bool get isParsedButInvalid {
    final lower = (error ?? '').toLowerCase();
    return lower.contains('parsed but failed') ||
        lower.contains('failed validation') ||
        lower.contains('missing receiptno') ||
        lower.contains('not_found') ||
        lower.contains('no transaction found') ||
        httpStatus == 502;
  }

  /// Friendly human-readable explanation of why verification failed.
  String get userFriendlyErrorMessage {
    final lowerProv = providerKey.toLowerCase();
    final lowerErr = (error ?? '').toLowerCase();
    final code = (errorCode ?? '').toUpperCase();

    if (code == 'IMAGE_PROCESSING_DISABLED') {
      return 'Image Processing is disabled on your Verify.ET account. Please enable Image Processing in the Verify.ET Developers dashboard (https://verify.et) or enter the transaction reference number.';
    }
    if (code == 'INSUFFICIENT_IMAGE_CREDITS') {
      return 'Verify.ET Image Processing credit allowance reached. Please top up credits or enter the transaction reference manually.';
    }
    if (code == 'IMAGE_UNREADABLE') {
      return 'QR code and receipt text could not be recognized by Verify.ET. Please send a clearer screenshot or enter the reference number.';
    }
    if (code == 'NOT_FOUND') {
      if (lowerProv.contains('boa') || lowerProv.contains('abyssinia')) {
        return 'Bank of Abyssinia reported no transaction found with account suffix 93089. Please check if the receiver account suffix on the slip matches 93089, or if this payment was transferred from CBE (interbank).';
      }
      return 'The bank reported that this transaction was not found on their records.';
    }

    if (isParsedButInvalid) {
      if (lowerProv.contains('telebirr')) {
        return 'Receipt not found on Ethio Telecom portal. The reference number may be mistyped, fake, or not yet published by Telebirr.';
      }
      if (lowerProv.contains('cbe')) {
        return 'CBE upstream could not validate this receipt. Mobile Banking transfers require the receipt link from the confirmation SMS (e.g. mbreciept.cbe.com.et/...).';
      }
      if (lowerProv.contains('boa') || lowerProv.contains('abyssinia')) {
        return 'Bank of Abyssinia reported no transaction found for this token with suffix 93089. Please check if the receiver account on the slip ends with 93089, or if this was an interbank transfer from CBE.';
      }
      return 'Receipt document was fetched upstream but did not contain valid completed transaction details.';
    }

    if (error != null && error!.isNotEmpty) {
      if (lowerErr.contains('receipt not found upstream') || lowerErr.contains('not found')) {
        if (lowerProv.contains('boa') || lowerProv.contains('abyssinia')) {
          return 'Bank of Abyssinia reported no transaction found for this reference under suffix 93089. Please verify the 5-digit account suffix or check if it originated from CBE.';
        }
        return 'The bank reported that this receipt was not found on their records.';
      }
      if (lowerErr.contains('non-pdf body') || lowerErr.contains('http 500')) {
        if (lowerProv.contains('cbe')) {
          return 'CBE returned an error for this reference. Mobile Banking transfers require the receipt link from the confirmation SMS (e.g. mbreciept.cbe.com.et/...).';
        }
      }
      if (lowerErr.contains('no receipt resolver registered')) {
        return 'This URL pattern is not registered for automatic verification. Please provide an official receipt link.';
      }
      if (lowerErr.contains('not responding') ||
          lowerErr.contains('responding right now') ||
          lowerErr.contains('busy') ||
          lowerErr.contains('timeout')) {
        return 'The bank (${providerKey.toUpperCase()}) is taking longer than expected to respond. This is a temporary delay on the bank network. Please try again shortly or check status using the Request ID.';
      }
      if (lowerErr.contains('quota_exceeded') || lowerErr.contains('insufficient_credits')) {
        return 'Verify.ET verification credit allowance has been reached.';
      }
      if (lowerErr.contains('rate_limited') || lowerErr.contains('429')) {
        return 'Too many requests. Please wait a moment before retrying.';
      }
      return error!;
    }
    return 'Verification was not confirmed by the bank.';
  }

  /// Web link to inspect the upstream bank receipt page directly.
  String? get telebirrPortalUrl => upstreamInspectionUrl;

  /// Web link to inspect the upstream bank receipt page directly across all providers.
  String? get upstreamInspectionUrl {
    final ref = referenceNumber;
    final prov = providerKey.toLowerCase();
    if (prov.contains('telebirr') && ref != null && ref.isNotEmpty && !ref.startsWith('http')) {
      return 'https://transactioninfo.ethiotelecom.et/receipt/$ref';
    }
    if (prov.contains('boa') && ref != null && ref.isNotEmpty && !ref.startsWith('http')) {
      return 'https://cs.bankofabyssinia.com/slip/?trx=$ref';
    }
    return resolvedUrl;
  }

  // Compatibility getters with previous VerifyEtResult
  String get bank => providerKey;
  String get status {
    if (isSuccess) return 'Completed';
    if (isPending) return 'Queued';
    if (isParsedButInvalid) return 'Receipt Not Found';
    return error ?? 'Failed';
  }
  bool get verified => isSuccess;

  double get amount => receipt?.amount ?? upstream?.result?.amount ?? 0.0;
  String get currency => receipt?.currency ?? upstream?.result?.currency ?? 'ETB';
  String? get senderName => receipt?.payerName ?? upstream?.result?.senderName;
  String? get receiverName => receipt?.receiverName ?? upstream?.result?.receiverName;
  String? get receiverAccount => receipt?.receiverAccount ?? upstream?.result?.receiverAccount;
  static String sanitizeTelebirrToken(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return '';

    final urlMatch = RegExp(
      r'(?:https?:\/\/)?transactioninfo\.ethiotelecom\.et\/receipt\/([A-Za-z0-9]+)',
      caseSensitive: false,
    ).firstMatch(clean);
    if (urlMatch != null) return urlMatch.group(1)!.toUpperCase();

    final labeledMatch = RegExp(
      r'(?:Transaction\s*(?:No|Number|ID|Code)|Payment\s*Code|Lakkoofsa\s*Kaffaltii|Lakkoofsa\s*daddabarsaa|የግብይት\s*ቁጥር|የሂሳብ\s*ቁጥር|Ref(?:erence)?)[\s:]*([A-Za-z0-9]{10})\b',
      caseSensitive: false,
    ).firstMatch(clean);
    if (labeledMatch != null) return labeledMatch.group(1)!.toUpperCase();

    if (clean.startsWith('http://') || clean.startsWith('https://')) return clean;

    final tokenRegex = RegExp(r'\b([A-Za-z0-9]{10})\b');
    final match = tokenRegex.firstMatch(clean);
    if (match != null) return match.group(1)!.toUpperCase();

    return clean.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
  }

  String? get referenceNumber {
    final raw = receipt?.reference.isNotEmpty == true
        ? receipt!.reference
        : (detected?.reference ?? upstream?.result?.referenceNumber);
    if (raw == null || raw.isEmpty) return null;
    if (bank.toLowerCase().contains('telebirr') || raw.contains('transactioninfo.ethiotelecom.et')) {
      final sanitized = sanitizeTelebirrToken(raw);
      if (sanitized.isNotEmpty && !sanitized.startsWith('http')) {
        return sanitized;
      }
    }
    return raw;
  }
  String? get receiptNumber => referenceNumber;
  DateTime? get timestamp => receipt?.parsedDate ?? fetchedAt;
  int? get pollAfterMs => 2000;
  int? get estimatedWaitMs => 5000;

  LinksEtResult copyWith({
    ScannedReceiptRecord? previousRecord,
  }) {
    return LinksEtResult(
      ok: ok,
      providerKey: providerKey,
      resolvedUrl: resolvedUrl,
      httpStatus: httpStatus,
      fetchedAt: fetchedAt,
      rawHtmlLength: rawHtmlLength,
      cached: cached,
      requestId: requestId,
      processingStatus: processingStatus,
      statusUrl: statusUrl,
      eventsUrl: eventsUrl,
      error: error,
      errorCode: errorCode,
      receipt: receipt,
      detected: detected,
      upstream: upstream,
      confirmationHistory: confirmationHistory,
      settlementAccountMatch: settlementAccountMatch,
      previousRecord: previousRecord ?? this.previousRecord,
      rawJson: rawJson,
    );
  }

  factory LinksEtResult.fromJson(
    Map<String, dynamic> json, {
    String? requestId,
    ScannedReceiptRecord? previousRecord,
  }) {
    // ── 1. Check for Verify.ET standard response format ─────────────────────
    Map<String, dynamic>? itemData;
    if (json['data'] is List && (json['data'] as List).isNotEmpty) {
      final first = (json['data'] as List).first;
      if (first is Map<String, dynamic>) {
        itemData = first;
      } else if (first is Map) {
        itemData = Map<String, dynamic>.from(first);
      }
    } else if (json['data'] is Map<String, dynamic>) {
      final map = json['data'] as Map<String, dynamic>;
      if (map['result'] is Map<String, dynamic>) {
        itemData = map['result'] as Map<String, dynamic>;
      } else if (map['result'] is Map) {
        itemData = Map<String, dynamic>.from(map['result'] as Map);
      } else {
        itemData = map;
      }
    } else if (json['data'] is Map) {
      final map = Map<String, dynamic>.from(json['data'] as Map);
      if (map['result'] is Map) {
        itemData = Map<String, dynamic>.from(map['result'] as Map);
      } else {
        itemData = map;
      }
    }

    final verificationMap = json['verification'] is Map ? json['verification'] as Map : null;

    final isVerifyEtEnvelope = json.containsKey('success') || verificationMap != null;
    final isExplicitSuccess = json['success'] == true;
    final isVerifiedFlag = itemData?['verified'] == true ||
        itemData?['status']?.toString().toLowerCase() == 'success' ||
        itemData?['status']?.toString().toLowerCase() == 'completed' ||
        verificationMap?['verified'] == true ||
        verificationMap?['status']?.toString().toLowerCase() == 'success' ||
        json['verified'] == true ||
        json['ok'] == true;

    final prov = itemData?['bank']?.toString() ??
        verificationMap?['bank']?.toString() ??
        json['providerKey']?.toString() ??
        json['detected']?['provider']?.toString() ??
        json['bank']?.toString() ??
        'universal';

    final rawRef = itemData?['referenceNumber']?.toString() ??
        itemData?['receiptNumber']?.toString() ??
        itemData?['reference']?.toString();

    final resolved = itemData?['receiptUrl']?.toString() ??
        itemData?['url']?.toString() ??
        (rawRef != null && rawRef.startsWith('http') ? rawRef : null) ??
        json['resolvedUrl']?.toString() ??
        json['url']?.toString();

    final status = (json['httpStatus'] as num?)?.toInt() ??
        (isExplicitSuccess || isVerifiedFlag ? 200 : (json.containsKey('error') ? 400 : 200));

    final fetched = EthiopianTimeHelper.parseSupabaseUtc(
      itemData?['timestamp'] ?? json['fetchedAt'] ?? json['timestamp'] ?? verificationMap?['completedAt'],
    );

    final rawLen = (json['rawHtmlLength'] as num?)?.toInt();
    final isCached = json['cached'] == true;
    final reqId = requestId ??
        json['requestId']?.toString() ??
        verificationMap?['requestId']?.toString() ??
        (json['data'] is Map ? (json['data'] as Map)['requestId']?.toString() : null);

    final procStatus = verificationMap?['processingStatus']?.toString() ??
        (json['data'] is Map ? (json['data'] as Map)['processingStatus']?.toString() : null) ??
        json['processingStatus']?.toString() ??
        (status == 202 ? 'queued' : (isVerifiedFlag ? 'completed' : (json['error'] != null ? 'failed' : 'completed')));

    final statusU = json['statusUrl']?.toString() ??
        (json['links'] is Map ? (json['links'] as Map)['statusUrl']?.toString() : null);
    final eventsU = json['eventsUrl']?.toString();

    // Parse Error
    String? errStr;
    String? errCode;
    final rawErr = json['error'] ?? (json['data'] is Map ? (json['data'] as Map)['error'] : null);
    if (rawErr is String) {
      errStr = rawErr;
    } else if (rawErr is Map) {
      errStr = rawErr['message']?.toString();
      errCode = rawErr['code']?.toString();
    } else if (json['errorMessage'] != null) {
      errStr = json['errorMessage'].toString();
    } else if (!isExplicitSuccess && json['message'] != null && json['message'] != 'Verification status.') {
      errStr = json['message'].toString();
    }

    // Parse receipt if present
    LinksEtReceipt? r;
    if (itemData != null && itemData.isNotEmpty && (itemData.containsKey('amount') || itemData.containsKey('referenceNumber') || itemData.containsKey('transactionNumber') || itemData.containsKey('receiptNumber'))) {
      r = LinksEtReceipt.fromJson(itemData);
    } else if (json['receipt'] is Map<String, dynamic>) {
      r = LinksEtReceipt.fromJson(json['receipt'] as Map<String, dynamic>);
    } else if (json['receipt'] is Map) {
      r = LinksEtReceipt.fromJson(Map<String, dynamic>.from(json['receipt'] as Map));
    }

    // Parse confirmationHistory
    ConfirmationHistory? confHist;
    final rawConf = itemData?['confirmationHistory'] ?? json['confirmationHistory'];
    if (rawConf is Map<String, dynamic>) {
      confHist = ConfirmationHistory.fromJson(rawConf);
    } else if (rawConf is Map) {
      confHist = ConfirmationHistory.fromJson(Map<String, dynamic>.from(rawConf));
    }

    // Parse settlementAccountMatch
    SettlementAccountMatch? settMatch;
    final rawSett = itemData?['settlementAccountMatch'] ?? json['settlementAccountMatch'];
    if (rawSett is Map<String, dynamic>) {
      settMatch = SettlementAccountMatch.fromJson(rawSett);
    } else if (rawSett is Map) {
      settMatch = SettlementAccountMatch.fromJson(Map<String, dynamic>.from(rawSett));
    }

    // Parse detected & upstream for verify-image
    ImageDetectionResult? det;
    if (json['detected'] is Map<String, dynamic>) {
      det = ImageDetectionResult.fromJson(json['detected'] as Map<String, dynamic>);
    } else if (json['detected'] is Map) {
      det = ImageDetectionResult.fromJson(Map<String, dynamic>.from(json['detected'] as Map));
    }

    UpstreamResult? up;
    if (json['upstream'] is Map<String, dynamic>) {
      up = UpstreamResult.fromJson(json['upstream'] as Map<String, dynamic>);
    } else if (json['upstream'] is Map) {
      up = UpstreamResult.fromJson(Map<String, dynamic>.from(json['upstream'] as Map));
    }

    final overallOk = isVerifyEtEnvelope ? (isExplicitSuccess && isVerifiedFlag) : (json['ok'] == true);

    return LinksEtResult(
      ok: overallOk,
      providerKey: prov,
      resolvedUrl: resolved,
      httpStatus: status,
      fetchedAt: fetched,
      rawHtmlLength: rawLen,
      cached: isCached,
      requestId: reqId,
      processingStatus: procStatus,
      statusUrl: statusU,
      eventsUrl: eventsU,
      error: errStr,
      errorCode: errCode,
      receipt: r,
      detected: det,
      upstream: up,
      confirmationHistory: confHist,
      settlementAccountMatch: settMatch,
      previousRecord: previousRecord,
      rawJson: json,
    );
  }
}

/// Backwards compatibility alias for VerifyEtResult.
typedef VerifyEtResult = LinksEtResult;

/// Item in the verification history display list.
class VerifyEtHistoryItem {
  final String requestId;
  final String? referenceNumber;
  final String bank;
  final String processingStatus;
  final String status;
  final bool verified;
  final double amount;
  final String currency;
  final DateTime? createdAt;
  final int scanCount;
  final DateTime? previousScannedAt;
  final String? userEmail;
  final String? senderName;
  final String? receiverName;

  const VerifyEtHistoryItem({
    required this.requestId,
    this.referenceNumber,
    required this.bank,
    required this.processingStatus,
    required this.status,
    required this.verified,
    this.amount = 0.0,
    this.currency = 'ETB',
    this.createdAt,
    this.scanCount = 1,
    this.previousScannedAt,
    this.userEmail,
    this.senderName,
    this.receiverName,
  });

  factory VerifyEtHistoryItem.fromScannedRecord(ScannedReceiptRecord rec) {
    final isDone = rec.status.toLowerCase() == 'verified' ||
        rec.status.toLowerCase() == 'completed' ||
        rec.status.toLowerCase() == 'approved';
    return VerifyEtHistoryItem(
      requestId: rec.id,
      referenceNumber: rec.id,
      bank: rec.method,
      processingStatus: isDone ? 'completed' : 'failed',
      status: rec.status,
      verified: isDone,
      amount: rec.amount ?? 0.0,
      currency: rec.currency,
      createdAt: rec.scannedAt,
      scanCount: rec.scanCount,
      previousScannedAt: rec.previousScannedAt,
      userEmail: rec.userEmail,
      senderName: rec.payerName,
      receiverName: rec.receiverName,
    );
  }

  factory VerifyEtHistoryItem.fromJson(Map<String, dynamic> json) {
    final res = json['result'] is Map ? json['result'] as Map : null;
    final reqId = json['requestId']?.toString() ?? json['id']?.toString() ?? '';
    final ref = res?['referenceNumber']?.toString() ??
        res?['transactionNumber']?.toString() ??
        res?['receiptNumber']?.toString() ??
        json['referenceNumber']?.toString() ??
        reqId;
    final amt = (res?['amount'] as num?)?.toDouble() ??
        (json['amount'] as num?)?.toDouble() ??
        0.0;
    final curr = res?['currency']?.toString() ?? json['currency']?.toString() ?? 'ETB';
    final isVer = json['verified'] == true || json['ok'] == true || (res?['verified'] == true);
    final stat = json['status']?.toString() ?? (isVer ? 'success' : 'failed');

    return VerifyEtHistoryItem(
      requestId: reqId,
      referenceNumber: ref,
      bank: json['bank']?.toString() ?? json['providerKey']?.toString() ?? 'universal',
      processingStatus: json['processingStatus']?.toString() ?? 'completed',
      status: stat,
      verified: isVer,
      amount: amt,
      currency: curr,
      createdAt: EthiopianTimeHelper.parseSupabaseUtc(json['createdAt'] ?? json['timestamp']),
      senderName: res?['senderName']?.toString() ?? json['senderName']?.toString(),
      receiverName: res?['receiverName']?.toString() ?? json['receiverName']?.toString(),
    );
  }
}
