import 'package:m_admin/utils/helpers/ethiopian_time_helper.dart';

/// Represents a settlement account match returned by Verify.ET.
class SettlementAccountMatch {
  final bool matched;
  final String? matchType;
  final String? matchConfidence;
  final String? source;
  final String? bank;
  final String? receiverAccount;
  final String? matchedSettlementAccount;
  final String? reason;
  final bool ambiguous;
  final int candidateCount;

  SettlementAccountMatch({
    required this.matched,
    this.matchType,
    this.matchConfidence,
    this.source,
    this.bank,
    this.receiverAccount,
    this.matchedSettlementAccount,
    this.reason,
    this.ambiguous = false,
    this.candidateCount = 0,
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
      ambiguous: json['ambiguous'] == true,
      candidateCount: (json['candidateCount'] as num?)?.toInt() ?? 0,
    );
  }

  String get reasonLabel {
    switch (reason) {
      case 'receiver_account_exact_match':
        return 'Exact account match';
      case 'receiver_mask_matches_visible_digits':
        return 'Mask matches visible account digits';
      case 'receiver_suffix_matches':
        return 'Account suffix matches';
      case 'no_registered_accounts':
        return 'No registered accounts found';
      case 'candidate_account_mismatch':
        return 'Receiver account did not match expected account';
      case 'ambiguous_registered_accounts':
        return 'Multiple matching candidate accounts found';
      case 'missing_receiver_account':
        return 'Receiver account not provided on receipt';
      default:
        return reason ?? 'Status pending';
    }
  }
}

/// Represents the platform confirmation history for double-spend prevention.
class ConfirmationHistory {
  final bool isFirstConfirmation;
  final bool confirmedBefore;
  final int confirmationCount;
  final DateTime? firstConfirmedAt;
  final DateTime? lastConfirmedAt;

  ConfirmationHistory({
    required this.isFirstConfirmation,
    required this.confirmedBefore,
    required this.confirmationCount,
    this.firstConfirmedAt,
    this.lastConfirmedAt,
  });

  factory ConfirmationHistory.fromJson(Map<String, dynamic> json) {
    return ConfirmationHistory(
      isFirstConfirmation: json['isFirstConfirmation'] == true,
      confirmedBefore: json['confirmedBefore'] == true,
      confirmationCount: (json['confirmationCount'] as num?)?.toInt() ?? 1,
      firstConfirmedAt: EthiopianTimeHelper.parseSupabaseUtc(json['firstConfirmedAt']),
      lastConfirmedAt: EthiopianTimeHelper.parseSupabaseUtc(json['lastConfirmedAt']),
    );
  }
}

/// Information returned when an image was processed via QR / OCR.
class ImageProcessingInfo {
  final String? attemptId;
  final String? method;
  final int chargedCredits;

  ImageProcessingInfo({
    this.attemptId,
    this.method,
    this.chargedCredits = 0,
  });

  factory ImageProcessingInfo.fromJson(Map<String, dynamic> json) {
    return ImageProcessingInfo(
      attemptId: json['attemptId']?.toString(),
      method: json['method']?.toString(),
      chargedCredits: (json['chargedCredits'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Main verified transaction result from Verify.ET.
class VerifyEtResult {
  final String bank;
  final String status;
  final bool verified;
  final double amount;
  final String currency;
  final String? senderName;
  final String? receiverName;
  final String? receiverAccount;
  final String? referenceNumber;
  final String? receiptNumber;
  final DateTime? timestamp;
  final String? requestId;
  final String? processingStatus;
  final ConfirmationHistory? confirmationHistory;
  final SettlementAccountMatch? settlementAccountMatch;
  final ImageProcessingInfo? imageProcessing;
  final Map<String, dynamic> rawJson;

  VerifyEtResult({
    required this.bank,
    required this.status,
    required this.verified,
    required this.amount,
    required this.currency,
    this.senderName,
    this.receiverName,
    this.receiverAccount,
    this.referenceNumber,
    this.receiptNumber,
    this.timestamp,
    this.requestId,
    this.processingStatus,
    this.confirmationHistory,
    this.settlementAccountMatch,
    this.imageProcessing,
    required this.rawJson,
  });

  factory VerifyEtResult.fromJson(Map<String, dynamic> json, {String? requestId, ImageProcessingInfo? imageInfo}) {
    final data = json;

    return VerifyEtResult(
      bank: data['bank']?.toString() ?? 'cbe',
      status: data['status']?.toString() ?? 'pending',
      verified: data['verified'] == true,
      amount: (data['amount'] as num?)?.toDouble() ?? double.tryParse(data['amount']?.toString() ?? '0') ?? 0.0,
      currency: data['currency']?.toString() ?? 'ETB',
      senderName: data['senderName']?.toString(),
      receiverName: data['receiverName']?.toString(),
      receiverAccount: data['receiverAccount']?.toString(),
      referenceNumber: data['referenceNumber']?.toString(),
      receiptNumber: data['receiptNumber']?.toString(),
      timestamp: EthiopianTimeHelper.parseSupabaseUtc(data['timestamp']),
      requestId: requestId ?? data['requestId']?.toString(),
      processingStatus: data['processingStatus']?.toString(),
      confirmationHistory: data['confirmationHistory'] is Map<String, dynamic>
          ? ConfirmationHistory.fromJson(data['confirmationHistory'] as Map<String, dynamic>)
          : null,
      settlementAccountMatch: data['settlementAccountMatch'] is Map<String, dynamic>
          ? SettlementAccountMatch.fromJson(data['settlementAccountMatch'] as Map<String, dynamic>)
          : null,
      imageProcessing: imageInfo,
      rawJson: json,
    );
  }
}

/// Item in the verification history list.
class VerifyEtHistoryItem {
  final String requestId;
  final String bank;
  final String processingStatus;
  final String status;
  final bool verified;
  final int durationMs;
  final DateTime? createdAt;

  VerifyEtHistoryItem({
    required this.requestId,
    required this.bank,
    required this.processingStatus,
    required this.status,
    required this.verified,
    this.durationMs = 0,
    this.createdAt,
  });

  factory VerifyEtHistoryItem.fromJson(Map<String, dynamic> json) {
    return VerifyEtHistoryItem(
      requestId: json['requestId']?.toString() ?? '',
      bank: json['bank']?.toString() ?? 'universal',
      processingStatus: json['processingStatus']?.toString() ?? 'completed',
      status: json['status']?.toString() ?? 'unknown',
      verified: json['verified'] == true,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      createdAt: EthiopianTimeHelper.parseSupabaseUtc(json['createdAt']),
    );
  }
}
