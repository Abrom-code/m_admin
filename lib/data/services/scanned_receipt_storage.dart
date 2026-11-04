import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/utils/helpers/ethiopian_time_helper.dart';

/// Represents a transaction/receipt record stored in the local app database (GetStorage).
/// Used to track verified receipts, detect double-scans, and display previous verification
/// status and date.
class ScannedReceiptRecord {
  final String id;
  final String method;
  final String status;
  final DateTime scannedAt;
  final double? amount;
  final String currency;
  final String? payerName;
  final String? payerAccount;
  final String? receiverName;
  final String? receiverAccount;
  final String? receiptUrl;
  final int scanCount;
  final DateTime? previousScannedAt;
  final String? previousStatus;
  final String? userEmail;
  final DateTime? approvedAt;
  final String? receiptId;

  const ScannedReceiptRecord({
    required this.id,
    required this.method,
    required this.status,
    required this.scannedAt,
    this.amount,
    this.currency = 'ETB',
    this.payerName,
    this.payerAccount,
    this.receiverName,
    this.receiverAccount,
    this.receiptUrl,
    this.scanCount = 1,
    this.previousScannedAt,
    this.previousStatus,
    this.userEmail,
    this.approvedAt,
    this.receiptId,
  });

  bool get wasScannedBefore => scanCount > 1 || previousScannedAt != null;

  bool get isApproved => status.toLowerCase() == 'approved' || approvedAt != null;

  String get formattedScannedDate {
    final eat = EthiopianTimeHelper.toEastAfricaTime(scannedAt);
    return '${DateFormat('d MMM yyyy, h:mm a').format(eat)} EAT';
  }

  String? get formattedApprovedDate {
    if (approvedAt == null) return null;
    final eat = EthiopianTimeHelper.toEastAfricaTime(approvedAt!);
    return '${DateFormat('d MMM yyyy, h:mm a').format(eat)} EAT';
  }

  String? get formattedPreviousDate {
    if (previousScannedAt == null) return null;
    final eat = EthiopianTimeHelper.toEastAfricaTime(previousScannedAt!);
    return '${DateFormat('d MMM yyyy, h:mm a').format(eat)} EAT';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'method': method,
    'status': status,
    'scannedAt': scannedAt.toIso8601String(),
    'amount': amount,
    'currency': currency,
    'payerName': payerName,
    'payerAccount': payerAccount,
    'receiverName': receiverName,
    'receiverAccount': receiverAccount,
    'receiptUrl': receiptUrl,
    'scanCount': scanCount,
    if (previousScannedAt != null) 'previousScannedAt': previousScannedAt!.toIso8601String(),
    if (previousStatus != null) 'previousStatus': previousStatus,
    if (userEmail != null) 'userEmail': userEmail,
    if (approvedAt != null) 'approvedAt': approvedAt!.toIso8601String(),
    if (receiptId != null) 'receiptId': receiptId,
  };

  factory ScannedReceiptRecord.fromJson(Map<String, dynamic> json) {
    return ScannedReceiptRecord(
      id: json['id']?.toString() ?? '',
      method: json['method']?.toString() ?? 'unknown',
      status: json['status']?.toString() ?? 'verified',
      scannedAt: DateTime.tryParse(json['scannedAt']?.toString() ?? '') ?? DateTime.now(),
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency']?.toString() ?? 'ETB',
      payerName: json['payerName']?.toString(),
      payerAccount: json['payerAccount']?.toString(),
      receiverName: json['receiverName']?.toString(),
      receiverAccount: json['receiverAccount']?.toString(),
      receiptUrl: json['receiptUrl']?.toString(),
      scanCount: (json['scanCount'] as num?)?.toInt() ?? 1,
      previousScannedAt: json['previousScannedAt'] != null
          ? DateTime.tryParse(json['previousScannedAt'].toString())
          : null,
      previousStatus: json['previousStatus']?.toString(),
      userEmail: json['userEmail']?.toString() ?? json['personEmail']?.toString(),
      approvedAt: json['approvedAt'] != null
          ? DateTime.tryParse(json['approvedAt'].toString())
          : null,
      receiptId: json['receiptId']?.toString(),
    );
  }
}

/// Local application database managing verified and scanned payment receipts via [GetStorage].
class ScannedReceiptStorage {
  static const String _kStorageKey = 'links_et_scanned_receipts_v1';
  final GetStorage _storage;

  ScannedReceiptStorage({GetStorage? storage}) : _storage = storage ?? GetStorage();

  static final ScannedReceiptStorage instance = ScannedReceiptStorage();

  /// Normalizes a transaction ID, reference number, or receipt URL into a uniform lookup key.
  static String normalizeId(String? raw) {
    if (raw == null) return '';
    var clean = raw.trim();
    if (clean.isEmpty) return '';

    // If it is a URL, strip query parameters and extract the key receipt token/identifier
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      final uri = Uri.tryParse(clean);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        final lastSegment = uri.pathSegments.last.trim();
        if (lastSegment.isNotEmpty) {
          clean = lastSegment;
        }
      }
    }

    // Strip leading/trailing punctuation and uppercase
    return clean.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '').toUpperCase();
  }

  /// Finds an existing record in the local app database by transaction ID, reference, or URL.
  ScannedReceiptRecord? findRecord(String? idOrUrl) {
    if (idOrUrl == null || idOrUrl.trim().isEmpty) return null;
    final normalized = normalizeId(idOrUrl);
    if (normalized.isEmpty) return null;

    final map = _loadRawMap();
    final json = map[normalized];
    if (json is Map<String, dynamic>) {
      return ScannedReceiptRecord.fromJson(json);
    } else if (json is Map) {
      return ScannedReceiptRecord.fromJson(Map<String, dynamic>.from(json));
    }

    // Also attempt secondary match on full URL if input had URL
    final fullTrim = idOrUrl.trim().toLowerCase();
    for (final entry in map.values) {
      if (entry is Map) {
        final storedUrl = entry['receiptUrl']?.toString().toLowerCase();
        if (storedUrl != null && storedUrl.isNotEmpty && storedUrl == fullTrim) {
          return ScannedReceiptRecord.fromJson(Map<String, dynamic>.from(entry));
        }
      }
    }

    return null;
  }

  /// Stores or updates a verified receipt in the local database.
  /// If the receipt was previously scanned, records the previous status and previous date.
  ScannedReceiptRecord saveRecord({
    required String id,
    required String method,
    required String status,
    double? amount,
    String currency = 'ETB',
    String? payerName,
    String? payerAccount,
    String? receiverName,
    String? receiverAccount,
    String? receiptUrl,
  }) {
    final normalized = normalizeId(id);
    final lookupKey = normalized.isNotEmpty ? normalized : normalizeId(receiptUrl);
    if (lookupKey.isEmpty) {
      throw ArgumentError('Cannot store scanned receipt without a valid id or receiptUrl.');
    }

    final map = _loadRawMap();
    final existingRaw = map[lookupKey];
    ScannedReceiptRecord? existing;
    if (existingRaw is Map<String, dynamic>) {
      existing = ScannedReceiptRecord.fromJson(existingRaw);
    } else if (existingRaw is Map) {
      existing = ScannedReceiptRecord.fromJson(Map<String, dynamic>.from(existingRaw));
    }

    final now = DateTime.now();
    final record = ScannedReceiptRecord(
      id: lookupKey,
      method: method.isNotEmpty ? method : (existing?.method ?? 'unknown'),
      status: status,
      scannedAt: now,
      amount: amount ?? existing?.amount,
      currency: currency,
      payerName: payerName ?? existing?.payerName,
      payerAccount: payerAccount ?? existing?.payerAccount,
      receiverName: receiverName ?? existing?.receiverName,
      receiverAccount: receiverAccount ?? existing?.receiverAccount,
      receiptUrl: receiptUrl ?? existing?.receiptUrl,
      scanCount: (existing?.scanCount ?? 0) + 1,
      previousScannedAt: existing?.scannedAt,
      previousStatus: existing?.status,
    );

    map[lookupKey] = record.toJson();
    _saveRawMap(map);

    debugPrint('[ScannedReceiptStorage] Stored record $lookupKey (method: ${record.method}, status: ${record.status}, scanCount: ${record.scanCount})');
    return record;
  }

  /// Records an approved payment receipt in the local database with the person's email,
  /// payment method, and extracted transaction ID.
  ///
  /// Stored ONLY in local app database (GetStorage), NOT in remote database (Supabase).
  ScannedReceiptRecord recordApprovedPayment({
    required String transactionId,
    required String paymentMethod,
    required String userEmail,
    String? receiptId,
    double? amount,
    String currency = 'ETB',
    String? receiptUrl,
    String? payerName,
    String? payerAccount,
  }) {
    final normalized = normalizeId(transactionId);
    final lookupKey = normalized.isNotEmpty ? normalized : normalizeId(receiptUrl);
    if (lookupKey.isEmpty) {
      throw ArgumentError('Cannot store approved receipt without a valid transactionId or receiptUrl.');
    }

    final map = _loadRawMap();
    final existingRaw = map[lookupKey];
    ScannedReceiptRecord? existing;
    if (existingRaw is Map<String, dynamic>) {
      existing = ScannedReceiptRecord.fromJson(existingRaw);
    } else if (existingRaw is Map) {
      existing = ScannedReceiptRecord.fromJson(Map<String, dynamic>.from(existingRaw));
    }

    final now = DateTime.now();
    final record = ScannedReceiptRecord(
      id: lookupKey,
      method: paymentMethod.isNotEmpty ? paymentMethod : (existing?.method ?? 'unknown'),
      status: 'approved',
      scannedAt: existing?.scannedAt ?? now,
      amount: amount ?? existing?.amount,
      currency: currency,
      payerName: payerName ?? existing?.payerName,
      payerAccount: payerAccount ?? existing?.payerAccount,
      receiverName: existing?.receiverName,
      receiverAccount: existing?.receiverAccount,
      receiptUrl: receiptUrl ?? existing?.receiptUrl,
      scanCount: (existing?.scanCount ?? 0) + 1,
      previousScannedAt: existing?.scannedAt,
      previousStatus: existing?.status,
      userEmail: userEmail.trim().isNotEmpty ? userEmail.trim() : existing?.userEmail,
      approvedAt: now,
      receiptId: receiptId ?? existing?.receiptId,
    );

    map[lookupKey] = record.toJson();
    _saveRawMap(map);

    debugPrint('[ScannedReceiptStorage] Locally stored approved receipt: $lookupKey (email: ${record.userEmail}, method: ${record.method})');
    return record;
  }

  /// Finds all records matching a person's email address.
  List<ScannedReceiptRecord> findRecordsByEmail(String email) {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return [];

    final map = _loadRawMap();
    final matches = <ScannedReceiptRecord>[];
    for (final val in map.values) {
      if (val is Map) {
        final record = ScannedReceiptRecord.fromJson(Map<String, dynamic>.from(val));
        if (record.userEmail?.toLowerCase() == cleanEmail) {
          matches.add(record);
        }
      }
    }
    return matches;
  }

  /// Retrieves all approved records in local storage.
  List<ScannedReceiptRecord> getApprovedRecords() {
    final all = getAllRecords();
    return all.where((r) => r.isApproved).toList();
  }

  /// Retrieves all scanned receipt records sorted by date descending (most recent first).
  List<ScannedReceiptRecord> getAllRecords() {
    final map = _loadRawMap();
    final list = <ScannedReceiptRecord>[];
    for (final val in map.values) {
      if (val is Map<String, dynamic>) {
        list.add(ScannedReceiptRecord.fromJson(val));
      } else if (val is Map) {
        list.add(ScannedReceiptRecord.fromJson(Map<String, dynamic>.from(val)));
      }
    }
    list.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return list;
  }

  /// Removes a single record by ID.
  void removeRecord(String idOrUrl) {
    final normalized = normalizeId(idOrUrl);
    if (normalized.isEmpty) return;
    final map = _loadRawMap();
    if (map.remove(normalized) != null) {
      _saveRawMap(map);
    }
  }

  /// Clears all stored records from the local app database.
  void clearAll() {
    try {
      _storage.remove(_kStorageKey);
    } catch (_) {}
  }

  Map<String, dynamic> _loadRawMap() {
    try {
      final raw = _storage.read<Map<String, dynamic>>(_kStorageKey);
      if (raw != null) return Map<String, dynamic>.from(raw);
      final genericRaw = _storage.read(_kStorageKey);
      if (genericRaw is Map) {
        return Map<String, dynamic>.from(genericRaw);
      }
    } catch (e) {
      debugPrint('[ScannedReceiptStorage] Read error: $e');
    }
    return <String, dynamic>{};
  }

  void _saveRawMap(Map<String, dynamic> map) {
    try {
      _storage.write(_kStorageKey, map);
    } catch (e) {
      debugPrint('[ScannedReceiptStorage] Write error: $e');
    }
  }
}

